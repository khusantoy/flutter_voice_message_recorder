import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../domain/audio_source.dart';
import '../domain/recorder_config.dart';
import '../domain/voice_message.dart';
import '../domain/waveform.dart';
import 'playback_coordinator.dart';
import 'ports.dart';

sealed class BubbleState {
  const BubbleState();
}

class BubbleIdle extends BubbleState {
  const BubbleIdle();
}

class BubbleDownloading extends BubbleState {
  const BubbleDownloading(this.progress);
  final DownloadProgress progress;
}

class BubbleReady extends BubbleState {
  const BubbleReady();
}

class BubbleError extends BubbleState {
  const BubbleError(this.message);
  final String message;
}

class VoiceMessagePlaybackController extends ChangeNotifier
    implements PausableSpeaker {
  VoiceMessagePlaybackController({
    required this.message,
    required this.cache,
    required this.downloader,
    required this.waveformExtractor,
    required this.waveformCache,
    required this.coordinator,
    required this.config,
  }) {
    _waveform = message.waveform;
    _duration = message.duration;
    _init();
  }

  final VoiceMessage message;
  final VoiceMessageCachePort cache;
  final VoiceMessageDownloaderPort downloader;
  final WaveformExtractorPort waveformExtractor;
  final WaveformCachePort waveformCache;
  final PlaybackCoordinator coordinator;
  final VoiceRecorderConfig config;

  BubbleState _state = const BubbleIdle();
  BubbleState get state => _state;

  String? _localPath;
  String? get localPath => _localPath;

  Waveform _waveform = Waveform.empty();
  Waveform get waveform => _waveform;

  AudioPlayer? _player;
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;
  bool _completed = false;
  double _progress = 0.0;
  double get progress => _progress;
  Duration _position = Duration.zero;
  Duration get position => _position;
  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;

  VoiceMessageDownloadHandle? _downloadHandle;
  StreamSubscription<DownloadEvent>? _downloadSub;

  Future<void> _init() async {
    switch (message.source) {
      case LocalAudioSource(:final path):
        _localPath = path;
        await _ensureWaveform(path);
        _state = const BubbleReady();
        notifyListeners();
      case RemoteAudioSource(:final url):
        final cached = await cache.getIfCached(url);
        if (cached != null) {
          _localPath = cached;
          await _ensureWaveform(cached);
          _state = const BubbleReady();
        } else {
          _state = const BubbleIdle();
        }
        notifyListeners();
    }
  }

  Future<void> _ensureWaveform(String key) async {
    if (!_waveform.isEmpty) return;
    final cached = await waveformCache.get(key);
    if (cached != null) {
      _waveform = cached;
      return;
    }
    try {
      final extracted = await waveformExtractor.extract(
        key,
        sampleCount: config.bubbleWaveformSampleCount,
      );
      _waveform = extracted;
      await waveformCache.set(key, extracted);
    } catch (_) {}
  }

  Future<void> startDownload() async {
    if (_state is! BubbleIdle && _state is! BubbleError) return;
    final source = message.source;
    if (source is! RemoteAudioSource) return;

    _state = const BubbleDownloading(DownloadProgress(received: 0, total: 0));
    notifyListeners();

    final dest = await cache.cachedPathFor(source.url);
    final handle = downloader.download(url: source.url, destinationPath: dest);
    _downloadHandle = handle;

    _downloadSub = handle.events.listen((event) async {
      switch (event) {
        case DownloadProgressEvent(:final progress):
          _state = BubbleDownloading(progress);
          notifyListeners();
        case DownloadCompleted(:final localPath):
          _localPath = localPath;
          await _ensureWaveform(localPath);
          _state = const BubbleReady();
          _downloadHandle = null;
          notifyListeners();
        case DownloadFailed(:final error):
          _state = BubbleError('Yuklab olishda xatolik: $error');
          _downloadHandle = null;
          notifyListeners();
        case DownloadCancelledEvent():
          _state = const BubbleIdle();
          _downloadHandle = null;
          notifyListeners();
      }
    });
  }

  void cancelDownload() {
    _downloadHandle?.cancel();
  }

  Future<void> togglePlay() async {
    if (_state is! BubbleReady || _localPath == null) return;

    if (_player == null) {
      final p = AudioPlayer();
      await p.setReleaseMode(ReleaseMode.stop);
      _player = p;
      _subscribePlayer(p);
      coordinator.requestPlay(this);
      await p.play(DeviceFileSource(_localPath!));
      return;
    }

    if (_completed) {
      _completed = false;
      _progress = 0.0;
      _position = Duration.zero;
      await _player!.seek(Duration.zero);
      coordinator.requestPlay(this);
      await _player!.resume();
      return;
    }

    if (_isPlaying) {
      await _player!.pause();
      coordinator.release(this);
    } else {
      coordinator.requestPlay(this);
      await _player!.resume();
    }
  }

  void seek(double newProgress) {
    if (_player == null) return;
    final ms = (newProgress * _duration.inMilliseconds).round();
    _player!.seek(Duration(milliseconds: ms));
    if (!_isPlaying) {
      _progress = newProgress;
      _position = Duration(milliseconds: ms);
      notifyListeners();
    }
  }

  @override
  void pauseFromCoordinator() {
    if (_isPlaying) _player?.pause();
  }

  void _subscribePlayer(AudioPlayer player) {
    _stateSub = player.onPlayerStateChanged.listen((s) {
      _isPlaying = s == PlayerState.playing;
      if (s == PlayerState.completed) {
        _completed = true;
        _isPlaying = false;
        _progress = 0.0;
        _position = Duration.zero;
        coordinator.release(this);
      }
      notifyListeners();
    });
    _durSub = player.onDurationChanged.listen((d) {
      _duration = d;
      notifyListeners();
    });
    _posSub = player.onPositionChanged.listen((pos) {
      final total = _duration.inMilliseconds;
      _position = pos;
      _progress = total > 0 ? (pos.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    _downloadHandle?.cancel();
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    coordinator.release(this);
    _player?.dispose();
    super.dispose();
  }
}
