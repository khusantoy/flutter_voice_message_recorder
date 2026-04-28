import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/voice_recording_result.dart';
import '../services/waveform_cache_service.dart';
import '../services/waveform_extractor_service.dart';
import '_preview_waveform_player.dart';

class VoiceMessageBubble extends StatefulWidget {
  const VoiceMessageBubble({
    super.key,
    required this.recording,
    required this.playingNotifier,
  });

  final VoiceRecordingResult recording;

  /// Shared across all bubbles. Holds the filePath of the currently playing
  /// message. Each bubble pauses itself when this changes to a different path.
  final ValueNotifier<String?> playingNotifier;

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  AudioPlayer? _player;

  bool _isPlaying = false;
  bool _isCompleted = false;
  double _progress = 0.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  List<double> _waveform = [];

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;

  @override
  void initState() {
    super.initState();
    _duration = widget.recording.duration;
    _waveform = widget.recording.waveformData;
    if (_waveform.isEmpty) _loadWaveform();
    widget.playingNotifier.addListener(_onGlobalPlayingChanged);
  }

  Future<void> _loadWaveform() async {
    final path = widget.recording.filePath;
    final cached = await WaveformCacheService.instance.get(path);
    if (cached != null) {
      if (mounted) setState(() => _waveform = cached);
      return;
    }
    try {
      final data = await WaveformExtractorService().extract(path, sampleCount: 100);
      await WaveformCacheService.instance.set(path, data);
      if (mounted) setState(() => _waveform = data);
    } catch (_) {}
  }

  void _onGlobalPlayingChanged() {
    final active = widget.playingNotifier.value;
    if (active != widget.recording.filePath && _isPlaying) {
      _player?.pause();
    }
  }

  Future<void> _togglePlay() async {
    if (_player == null) {
      final p = AudioPlayer();
      await p.setReleaseMode(ReleaseMode.stop);
      _player = p;

      _stateSub = p.onPlayerStateChanged.listen((s) {
        if (!mounted) return;
        setState(() {
          _isPlaying = s == PlayerState.playing;
          if (s == PlayerState.completed) {
            _isCompleted = true;
            _isPlaying = false;
            _progress = 0.0;
            _position = Duration.zero;
          }
        });
      });

      _durSub = p.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });

      _posSub = p.onPositionChanged.listen((pos) {
        if (!mounted) return;
        final total = _duration.inMilliseconds;
        setState(() {
          _position = pos;
          _progress =
              total > 0 ? (pos.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;
        });
      });

      await p.play(DeviceFileSource(widget.recording.filePath));
      widget.playingNotifier.value = widget.recording.filePath;
      return;
    }

    if (_isCompleted) {
      _isCompleted = false;
      _progress = 0.0;
      _position = Duration.zero;
      await _player!.seek(Duration.zero);
      await _player!.resume();
      widget.playingNotifier.value = widget.recording.filePath;
      return;
    }

    if (_isPlaying) {
      await _player!.pause();
    } else {
      await _player!.resume();
      widget.playingNotifier.value = widget.recording.filePath;
    }
  }

  void _seek(double progress) {
    if (_player == null) return;
    final ms = (progress * _duration.inMilliseconds).round();
    _player!.seek(Duration(milliseconds: ms));
    if (!_isPlaying) {
      setState(() {
        _progress = progress;
        _position = Duration(milliseconds: ms);
      });
    }
  }

  @override
  void dispose() {
    widget.playingNotifier.removeListener(_onGlobalPlayingChanged);
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = (d.inSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _timestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final showPosition = _isPlaying || (_progress > 0 && !_isCompleted);
    final displayTime = showPosition ? _position : _duration;

    const double minWidth = 160;
    final double maxWidth = MediaQuery.of(context).size.width * 0.72;
    final double ratio = sqrt(
      (widget.recording.duration.inSeconds / 60).clamp(0.0, 1.0),
    );
    final double bubbleWidth = minWidth + (maxWidth - minWidth) * ratio;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: bubbleWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Play / pause button
                      GestureDetector(
                        onTap: _togglePlay,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: cs.onPrimary,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Waveform
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 34,
                              child: PreviewWaveformPlayer(
                                waveformData: _waveform,
                                progress: _progress,
                                onSeek: _seek,
                                height: 34,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _fmt(displayTime),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: cs.onPrimaryContainer
                                        .withAlpha(160),
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _timestamp(widget.recording.sentAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.onPrimaryContainer.withAlpha(140),
                            ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.done_all_rounded,
                        size: 14,
                        color: cs.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
