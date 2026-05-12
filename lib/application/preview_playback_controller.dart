import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../domain/recorder_config.dart';
import '../domain/waveform.dart';
import 'ports.dart';

class PreviewPlaybackController extends ChangeNotifier {
  PreviewPlaybackController({
    required this.concat,
    required this.waveformExtractor,
    required this.paths,
    required this.config,
  });

  final AudioConcatPort concat;
  final WaveformExtractorPort waveformExtractor;
  final VoicePathsPort paths;
  final VoiceRecorderConfig config;

  AudioPlayer? _player;
  String? _mergedPath;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool _completed = false;

  double _progress = 0.0;
  double get progress => _progress;

  Duration _duration = Duration.zero;

  Waveform _waveform = Waveform.empty();
  Waveform get waveform => _waveform;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;

  bool get hasPreview => _mergedPath != null;

  Future<void> prepareAndPlay(List<String> segments) async {
    if (segments.isEmpty) return;

    if (_player != null) {
      // Toggle existing player
      if (_isPlaying) {
        await _player!.pause();
      } else if (_completed) {
        _completed = false;
        await _player!.seek(Duration.zero);
        await _player!.resume();
      } else {
        await _player!.resume();
      }
      return;
    }

    final mergedPath = await paths.previewPath();
    await concat.concat(segmentPaths: List.of(segments), outputPath: mergedPath);
    _mergedPath = mergedPath;

    _waveform = await waveformExtractor.extract(
      mergedPath,
      sampleCount: config.previewWaveformSampleCount,
    );
    _progress = 0.0;
    _duration = Duration.zero;
    _completed = false;

    final player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.stop);
    _player = player;
    _subscribe(player);

    await player.play(DeviceFileSource(mergedPath));
    notifyListeners();
  }

  void seek(double progress) {
    if (_player == null || _duration == Duration.zero) return;
    final pos = Duration(
      milliseconds: (progress * _duration.inMilliseconds).round(),
    );
    _player!.seek(pos);
  }

  Future<void> tearDown() async {
    await _stateSub?.cancel();
    await _posSub?.cancel();
    await _durSub?.cancel();
    _stateSub = null;
    _posSub = null;
    _durSub = null;

    final p = _player;
    _player = null;
    _isPlaying = false;
    _completed = false;
    _progress = 0.0;
    _duration = Duration.zero;
    _waveform = Waveform.empty();
    _mergedPath = null;

    if (p != null) {
      try {
        await p.stop();
      } catch (_) {}
      try {
        await p.dispose();
      } catch (_) {}
    }
  }

  String? get mergedPathForCleanup => _mergedPath;

  void _subscribe(AudioPlayer player) {
    _stateSub = player.onPlayerStateChanged.listen((ps) {
      _isPlaying = ps == PlayerState.playing;
      if (ps == PlayerState.completed) {
        _completed = true;
        _progress = 1.0;
      }
      notifyListeners();
    });
    _durSub = player.onDurationChanged.listen((d) {
      _duration = d;
    });
    _posSub = player.onPositionChanged.listen((pos) {
      if (_duration.inMilliseconds > 0) {
        _progress =
            (pos.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _player?.dispose();
    super.dispose();
  }
}
