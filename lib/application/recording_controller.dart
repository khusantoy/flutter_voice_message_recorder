import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/recorder_config.dart';
import '../domain/recorder_failure.dart';
import '../domain/voice_message.dart';
import '../domain/waveform.dart';
import '../infrastructure/voice_paths.dart';
import 'ports.dart';
import 'preview_playback_controller.dart';

enum RecorderState { idle, recording, paused, previewing }

class RecordingController extends ChangeNotifier with WidgetsBindingObserver {
  RecordingController({
    required this.recorder,
    required this.concat,
    required this.permission,
    required this.waveformExtractor,
    required this.waveformCache,
    required this.paths,
    required this.config,
  }) : _preview = PreviewPlaybackController(
          concat: concat,
          waveformExtractor: waveformExtractor,
          paths: paths,
          config: config,
        ) {
    WidgetsBinding.instance.addObserver(this);
    _preview.addListener(notifyListeners);
  }

  final AudioRecorderPort recorder;
  final AudioConcatPort concat;
  final MicPermissionPort permission;
  final WaveformExtractorPort waveformExtractor;
  final WaveformCachePort waveformCache;
  final VoicePathsPort paths;
  final VoiceRecorderConfig config;

  final PreviewPlaybackController _preview;
  PreviewPlaybackController get preview => _preview;

  RecorderState _state = RecorderState.idle;
  RecorderState get state => _state;

  final List<String> _segments = [];

  Duration _accumulated = Duration.zero;
  final Stopwatch _segmentWatch = Stopwatch();
  Timer? _ticker;

  StreamSubscription<AmplitudeReading>? _ampSub;

  double _amplitude = 0.0;
  double get amplitude => _amplitude;

  RecorderFailure? _failure;
  RecorderFailure? get failure => _failure;

  bool _busy = false;
  bool get busy => _busy;

  Duration get elapsed => _accumulated + _segmentWatch.elapsed;

  Future<void> startRecording() async {
    if (_state != RecorderState.idle || _busy) return;
    _setBusy(true);
    try {
      final res = await permission.ensureMicPermission();
      if (res != MicPermissionResult.granted) {
        _failure = res == MicPermissionResult.permanentlyDenied
            ? const PermissionBlocked()
            : const PermissionDenied();
        return;
      }
      _failure = null;

      final path = await recorder.startNewSegment();
      _segments.add(path);
      _segmentWatch
        ..reset()
        ..start();
      _startTicker();
      _subscribeAmplitude();
      _state = RecorderState.recording;
    } catch (e) {
      _failure = UnknownRecorderFailure('Yozib olish boshlanmadi: $e');
    } finally {
      _setBusy(false);
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

      final finalized = await recorder.stopCurrentSegment();
      if (finalized == null && _segments.isNotEmpty) {
        _segments.removeLast();
      }
      _state = RecorderState.paused;
    } catch (e) {
      _failure = UnknownRecorderFailure('Pauza qilishda xatolik: $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> resumeRecording() async {
    if (_state != RecorderState.paused && _state != RecorderState.previewing) {
      return;
    }
    if (_busy) return;
    _setBusy(true);
    try {
      await _preview.tearDown();
      final path = await recorder.startNewSegment();
      _segments.add(path);
      _segmentWatch
        ..reset()
        ..start();
      _startTicker();
      _subscribeAmplitude();
      _state = RecorderState.recording;
    } catch (e) {
      _failure = UnknownRecorderFailure('Davom ettirishda xatolik: $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> playPreview() async {
    if (_busy) return;
    if (_state != RecorderState.paused && _state != RecorderState.previewing) {
      return;
    }
    if (_segments.isEmpty) return;

    if (_state == RecorderState.previewing && _preview.hasPreview) {
      await _preview.prepareAndPlay(_segments);
      return;
    }

    _setBusy(true);
    try {
      await _preview.prepareAndPlay(_segments);
      _state = RecorderState.previewing;
    } catch (e) {
      _failure = UnknownRecorderFailure('Eshitish yuklanmadi: $e');
    } finally {
      _setBusy(false);
    }
  }

  void seekPreview(double progress) => _preview.seek(progress);

  Future<void> deleteAll() async {
    if (_busy) return;
    _setBusy(true);
    try {
      if (await recorder.isRecording()) {
        await recorder.stopCurrentSegment();
      }
      _segmentWatch
        ..stop()
        ..reset();
      _accumulated = Duration.zero;
      _stopTicker();
      await _ampSub?.cancel();
      _ampSub = null;
      _amplitude = 0.0;

      final preview = _preview.mergedPathForCleanup;
      await _preview.tearDown();

      for (final p in _segments) {
        await safeDeleteFile(p);
      }
      _segments.clear();
      if (preview != null) {
        await safeDeleteFile(preview);
      }
      _state = RecorderState.idle;
    } catch (e) {
      _failure = UnknownRecorderFailure('O\'chirishda xatolik: $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<VoiceMessage?> finalizeAndSend({required String chatId}) async {
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
        await recorder.stopCurrentSegment();
      }
      final previewWaveform = _preview.waveform;
      final previewPath = _preview.mergedPathForCleanup;
      await _preview.tearDown();

      if (_segments.isEmpty) {
        _state = RecorderState.idle;
        return null;
      }

      final finalPath = await paths.newFinalPath();
      await concat.concat(
        segmentPaths: List.of(_segments),
        outputPath: finalPath,
      );

      var waveform = previewWaveform;
      if (waveform.isEmpty) {
        try {
          waveform = await waveformExtractor.extract(
            finalPath,
            sampleCount: config.previewWaveformSampleCount,
          );
        } catch (_) {
          waveform = Waveform.empty();
        }
      }
      await waveformCache.set(
        chatId: chatId,
        key: finalPath,
        waveform: waveform,
      );

      final message = VoiceMessage.local(
        chatId: chatId,
        path: finalPath,
        duration: _accumulated,
        waveform: waveform,
      );

      for (final p in _segments) {
        await safeDeleteFile(p);
      }
      _segments.clear();
      if (previewPath != null) {
        await safeDeleteFile(previewPath);
      }
      _accumulated = Duration.zero;
      _state = RecorderState.idle;
      return message;
    } catch (e) {
      _failure = UnknownRecorderFailure('Yuborishda xatolik: $e');
      return null;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> openAppSettings() => permission.openSettings();

  void clearFailure() {
    if (_failure == null) return;
    _failure = null;
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(
      Duration(milliseconds: config.tickerIntervalMs),
      (_) => notifyListeners(),
    );
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _subscribeAmplitude() {
    _ampSub?.cancel();
    _ampSub = recorder.amplitudeStream().listen((a) {
      _amplitude = config.normalizeAmplitudeDb(a.currentDb);
      notifyListeners();
    });
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
      } else if (_state == RecorderState.previewing && _preview.isPlaying) {
        // pause through preview controller's player
        _preview.prepareAndPlay(_segments);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _ampSub?.cancel();
    final orphans = List<String>.of(_segments);
    final preview = _preview.mergedPathForCleanup;
    _segments.clear();
    _preview.removeListener(notifyListeners);
    _preview.dispose();
    recorder.dispose();
    // Discard any unsent segments + leftover preview file. Closing the
    // recorder without "Send" is treated as cancel — keeping them would
    // leak orphan files in app docs every time the user backs out
    // mid-recording.
    for (final p in orphans) {
      safeDeleteFile(p);
    }
    if (preview != null) safeDeleteFile(preview);
    super.dispose();
  }
}
