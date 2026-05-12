import 'dart:math';

import 'package:flutter/material.dart';

import '../application/voice_message_playback_controller.dart';
import '../domain/voice_message.dart';
import 'app_dependencies.dart';
import 'voice_message_style.dart';
import 'widgets/waveform_player.dart';

class VoiceMessageBubble extends StatefulWidget {
  const VoiceMessageBubble({
    super.key,
    required this.message,
    this.style = const VoiceBubbleStyle(),
  });

  final VoiceMessage message;
  final VoiceBubbleStyle style;

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  VoiceMessagePlaybackController? _ctrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ctrl != null) return;
    final deps = AppDependenciesScope.of(context);
    _ctrl = VoiceMessagePlaybackController(
      message: widget.message,
      cache: deps.voiceCache,
      downloader: deps.downloader,
      waveformExtractor: deps.waveformExtractor,
      waveformCache: deps.waveformCache,
      coordinator: deps.coordinator,
      config: deps.config,
    );
  }

  @override
  void dispose() {
    _ctrl?.dispose();
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
    final ctrl = _ctrl!;
    final style = widget.style;

    const double minWidth = 180;
    final double maxWidth = MediaQuery.of(context).size.width * 0.72;
    final double ratio = sqrt(
      (widget.message.duration.inSeconds / 60).clamp(0.0, 1.0),
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
              color: style.bubbleColor,
              borderRadius: style.borderRadius,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 6),
              child: ListenableBuilder(
                listenable: ctrl,
                builder: (context, _) {
                  final state = ctrl.state;
                  final isPlaying = ctrl.isPlaying;
                  final showPosition =
                      state is BubbleReady && ctrl.progress > 0;
                  final displayTime = showPosition
                      ? ctrl.position
                      : widget.message.duration;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _LeadingButton(
                            state: state,
                            isPlaying: isPlaying,
                            style: style,
                            onPlay: ctrl.togglePlay,
                            onDownload: ctrl.startDownload,
                            onCancel: ctrl.cancelDownload,
                            onRetry: ctrl.startDownload,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 34,
                                  child: WaveformPlayer(
                                    waveform: ctrl.waveform,
                                    progress: ctrl.progress,
                                    onSeek: ctrl.seek,
                                    playedColor: style.primaryColor,
                                    unplayedColor: style.waveformUnplayedColor,
                                    height: 34,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                _Subtitle(
                                  state: state,
                                  style: style,
                                  displayTime: _fmt(displayTime),
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
                            _timestamp(widget.message.sentAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: style.subtitleColor,
                            ).merge(style.timestampTextStyle),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.done_all_rounded,
                            size: 14,
                            color: style.primaryColor,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeadingButton extends StatelessWidget {
  const _LeadingButton({
    required this.state,
    required this.isPlaying,
    required this.style,
    required this.onPlay,
    required this.onDownload,
    required this.onCancel,
    required this.onRetry,
  });

  final BubbleState state;
  final bool isPlaying;
  final VoiceBubbleStyle style;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    const size = 42.0;

    Widget circle({required Widget child, VoidCallback? onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: style.primaryColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: child,
        ),
      );
    }

    switch (state) {
      case BubbleIdle():
        return circle(
          onTap: onDownload,
          child: Icon(
            Icons.download_rounded,
            color: style.onPrimaryColor,
            size: 24,
          ),
        );
      case BubbleDownloading(:final progress):
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: progress.total > 0 ? progress.fraction : 0.0,
                  strokeWidth: 2.5,
                  color: style.primaryColor,
                  backgroundColor: style.primaryColor.withAlpha(60),
                ),
              ),
              GestureDetector(
                onTap: onCancel,
                child: Container(
                  width: size - 12,
                  height: size - 12,
                  decoration: BoxDecoration(
                    color: style.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.close_rounded,
                    color: style.onPrimaryColor,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        );
      case BubbleReady():
        return circle(
          onTap: onPlay,
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: style.onPrimaryColor,
            size: 24,
          ),
        );
      case BubbleError():
        return circle(
          onTap: onRetry,
          child: Icon(
            Icons.refresh_rounded,
            color: style.onPrimaryColor,
            size: 22,
          ),
        );
    }
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle({
    required this.state,
    required this.style,
    required this.displayTime,
  });

  final BubbleState state;
  final VoiceBubbleStyle style;
  final String displayTime;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: 11,
      color: style.subtitleColor,
      fontFeatures: const [FontFeature.tabularFigures()],
    ).merge(style.subtitleTextStyle);

    String text;
    switch (state) {
      case BubbleDownloading(:final progress):
        if (progress.total > 0) {
          final pct = (progress.fraction * 100).toStringAsFixed(0);
          final mbReceived =
              (progress.received / (1024 * 1024)).toStringAsFixed(1);
          final mbTotal =
              (progress.total / (1024 * 1024)).toStringAsFixed(1);
          text = '$pct% · $mbReceived/$mbTotal MB';
        } else {
          text = '0%';
        }
      case BubbleError(:final message):
        text = message;
      default:
        text = displayTime;
    }
    return Text(
      text,
      style: textStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
