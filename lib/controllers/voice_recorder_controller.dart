import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/voice_recording_result.dart';
import '../services/audio_concat_service.dart';
import '../services/recorder_permission.dart';
import '../services/voice_recorder_service.dart';

enum RecorderState { idle, recording, paused, previewing }

class VoiceRecorderController extends ChangeNotifier
    with WidgetsBindingObserver {
  VoiceRecorderController({
    VoiceRecorderService? recorderService,
    AudioConcatService? concatService,
    RecorderPermission? permission,
  })  : _recorder = recorderService ?? VoiceRecorderService(),
        _concat = concatService ?? AudioConcatService(),
        _permission = permission ?? RecorderPermission() {
    WidgetsBinding.instance.addObserver(this);
  }

  final VoiceRecorderService _recorder;
  final AudioConcatService _concat;
  final RecorderPermission _permission;

  RecorderState _state = RecorderState.idle;
  RecorderState get state => _state;

  final List<String> _segments = [];
  String? _mergedPreviewPath;

  PlayerController? _previewPlayer;
  PlayerController? get previewPlayer => _previewPlayer;

  bool _isPreviewPlaying = false;
  bool get isPreviewPlaying => _isPreviewPlaying;

  Duration _accumulated = Duration.zero;
  final Stopwatch _segmentWatch = Stopwatch();
  Timer? _ticker;

  StreamSubscription<Amplitude>? _ampSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  double _amplitude = 0.0;
  double get amplitude => _amplitude;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  MicPermissionResult? _lastPermissionResult;
  MicPermissionResult? get lastPermissionResult => _lastPermissionResult;

  bool _busy = false;
  bool get busy => _busy;

  Duration get elapsed => _accumulated + _segmentWatch.elapsed;

  Future<void> startRecording() async {
    if (_state != RecorderState.idle || _busy) return;
    _setBusy(true);
    try {
      final res = await _permission.ensureMicPermission();
      _lastPermissionResult = res;
      if (res != MicPermissionResult.granted) {
        _errorMessage = res == MicPermissionResult.permanentlyDenied
            ? 'Mikrofon ruxsati bloklangan. Sozlamalardan ruxsat bering.'
            : 'Mikrofon ruxsati kerak.';
        _setBusy(false);
        notifyListeners();
        return;
      }
      _errorMessage = null;

      final path = await _recorder.startNewSegment();
      _segments.add(path);
      _segmentWatch
        ..reset()
        ..start();
      _startTicker();
      _subscribeAmplitude();
      _state = RecorderState.recording;
    } catch (e) {
      _errorMessage = 'Yozib olish boshlanmadi: $e';
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> pauseRecording() async {
    if (_state != RecorderState.recording || _busy) return;
    _setBusy(true);
    try {
      _segmentWatch.stop();
      _accumulated += _segmentWatch.elapsed;
      _segmentWatch.reset();
      _stopTicker();
      await _ampSub?.cancel();
      _ampSub = null;
      _amplitude = 0.0;

      final finalizedPath = await _recorder.stopCurrentSegment();
      if (finalizedPath == null && _segments.isNotEmpty) {
        _segments.removeLast();
      }
      _state = RecorderState.paused;
    } catch (e) {
      _errorMessage = 'Pauza qilishda xatolik: $e';
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> resumeRecording() async {
    if (_state != RecorderState.paused && _state != RecorderState.previewing) {
      return;
    }
    if (_busy) return;
    _setBusy(true);
    try {
      await _tearDownPreview();
      final path = await _recorder.startNewSegment();
      _segments.add(path);
      _segmentWatch
        ..reset()
        ..start();
      _startTicker();
      _subscribeAmplitude();
      _state = RecorderState.recording;
    } catch (e) {
      _errorMessage = 'Davom ettirishda xatolik: $e';
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> playPreview() async {
    if (_busy) return;
    if (_state != RecorderState.paused && _state != RecorderState.previewing) {
      return;
    }
    if (_segments.isEmpty) return;

    if (_state == RecorderState.previewing && _previewPlayer != null) {
      if (_isPreviewPlaying) {
        await _previewPlayer!.pausePlayer();
      } else {
        await _previewPlayer!.startPlayer();
      }
      return;
    }

    _setBusy(true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final mergedPath = '${dir.path}/voice_preview.m4a';
      await _concat.concat(
        segmentPaths: List<String>.from(_segments),
        outputPath: mergedPath,
      );
      _mergedPreviewPath = mergedPath;

      final player = PlayerController();
      await player.preparePlayer(
        path: mergedPath,
        shouldExtractWaveform: true,
        noOfSamples: 100,
        volume: 1.0,
      );
      _previewPlayer = player;

      _playerStateSub?.cancel();
      _playerStateSub = player.onPlayerStateChanged.listen((ps) {
        _isPreviewPlaying = ps.isPlaying;
        notifyListeners();
      });

      await player.startPlayer();
      _state = RecorderState.previewing;
    } catch (e) {
      _errorMessage = 'Eshitish yuklanmadi: $e';
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> deleteAll() async {
    if (_busy) return;
    _setBusy(true);
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stopCurrentSegment();
      }
      _segmentWatch
        ..stop()
        ..reset();
      _accumulated = Duration.zero;
      _stopTicker();
      await _ampSub?.cancel();
      _ampSub = null;
      _amplitude = 0.0;

      await _tearDownPreview();

      for (final p in _segments) {
        await _safeDelete(p);
      }
      _segments.clear();
      if (_mergedPreviewPath != null) {
        await _safeDelete(_mergedPreviewPath!);
        _mergedPreviewPath = null;
      }
      _state = RecorderState.idle;
    } catch (e) {
      _errorMessage = 'O\'chirishda xatolik: $e';
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<VoiceRecordingResult?> finalizeAndSend() async {
    if (_busy) return null;
    _setBusy(true);
    try {
      if (_state == RecorderState.recording) {
        _segmentWatch.stop();
        _accumulated += _segmentWatch.elapsed;
        _segmentWatch.reset();
        _stopTicker();
        await _ampSub?.cancel();
        _ampSub = null;
        await _recorder.stopCurrentSegment();
      }
      await _tearDownPreview();

      if (_segments.isEmpty) {
        _state = RecorderState.idle;
        return null;
      }

      final dir = await getApplicationDocumentsDirectory();
      final finalPath =
          '${dir.path}/voice_final_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _concat.concat(
        segmentPaths: List<String>.from(_segments),
        outputPath: finalPath,
      );

      final result =
          VoiceRecordingResult(filePath: finalPath, duration: _accumulated);

      for (final p in _segments) {
        await _safeDelete(p);
      }
      _segments.clear();
      if (_mergedPreviewPath != null) {
        await _safeDelete(_mergedPreviewPath!);
        _mergedPreviewPath = null;
      }
      _accumulated = Duration.zero;
      _state = RecorderState.idle;
      return result;
    } catch (e) {
      _errorMessage = 'Yuborishda xatolik: $e';
      return null;
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> openAppSettings() => _permission.openSettings();

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      notifyListeners();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _subscribeAmplitude() {
    _ampSub?.cancel();
    _ampSub = _recorder.amplitudeStream().listen((a) {
      final normalized = ((a.current + 45.0).clamp(0.0, 45.0)) / 45.0;
      _amplitude = normalized;
      notifyListeners();
    });
  }

  Future<void> _tearDownPreview() async {
    await _playerStateSub?.cancel();
    _playerStateSub = null;
    final p = _previewPlayer;
    _previewPlayer = null;
    _isPreviewPlaying = false;
    if (p != null) {
      try {
        await p.stopPlayer();
      } catch (_) {}
      try {
        p.dispose();
      } catch (_) {}
    }
  }

  Future<void> _safeDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  void _setBusy(bool v) {
    _busy = v;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_state == RecorderState.recording) {
        pauseRecording();
      } else if (_state == RecorderState.previewing && _isPreviewPlaying) {
        _previewPlayer?.pausePlayer();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _ampSub?.cancel();
    _playerStateSub?.cancel();
    _previewPlayer?.dispose();
    _recorder.dispose();
    super.dispose();
  }
}
