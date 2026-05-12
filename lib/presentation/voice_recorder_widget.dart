import 'package:flutter/material.dart';

import '../application/recording_controller.dart';
import '../domain/recorder_failure.dart';
import '../domain/voice_message.dart';
import '../domain/waveform.dart';
import 'app_dependencies.dart';
import 'voice_message_style.dart';
import 'widgets/live_amplitude_bar.dart';
import 'widgets/recording_timer.dart';
import 'widgets/waveform_player.dart';

class VoiceRecorderWidget extends StatefulWidget {
  const VoiceRecorderWidget({
    super.key,
    required this.onRecorded,
    this.onCancelled,
    this.onFailure,
    this.style = const VoiceRecorderStyle(),
    this.labels = const VoiceRecorderLabels(),
  });

  final ValueChanged<VoiceMessage> onRecorded;
  final VoidCallback? onCancelled;

  /// Optional failure callback. Host app decides how to render — snackbar,
  /// banner, or anything else. If null the failure is silently cleared.
  final ValueChanged<RecorderFailure>? onFailure;

  final VoiceRecorderStyle style;
  final VoiceRecorderLabels labels;

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  RecordingController? _controller;
  RecorderFailure? _lastForwardedFailure;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final deps = AppDependenciesScope.of(context);
    _controller = RecordingController(
      recorder: deps.newRecorder(),
      concat: deps.concat,
      permission: deps.permission,
      waveformExtractor: deps.waveformExtractor,
      waveformCache: deps.waveformCache,
      paths: deps.paths,
      config: deps.config,
    )..addListener(_forwardFailure);
  }

  @override
  void dispose() {
    _controller?.removeListener(_forwardFailure);
    _controller?.dispose();
    super.dispose();
  }

  void _forwardFailure() {
    final f = _controller?.failure;
    if (f == null || identical(f, _lastForwardedFailure)) return;
    _lastForwardedFailure = f;
    widget.onFailure?.call(f);
    _controller?.clearFailure();
  }

  Future<void> _onSendPressed() async {
    final result = await _controller!.finalizeAndSend();
    if (result != null && mounted) {
      widget.onRecorded(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller!;
    final style = widget.style;

    return Container(
      decoration: BoxDecoration(
        color: style.surfaceColor,
        borderRadius: style.borderRadius,
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          final state = ctrl.state;

          return AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: KeyedSubtree(
                key: ValueKey(state),
                child: _buildForState(state, ctrl, style, widget.labels),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildForState(
    RecorderState state,
    RecordingController ctrl,
    VoiceRecorderStyle style,
    VoiceRecorderLabels labels,
  ) {
    switch (state) {
      case RecorderState.idle:
        return _IdleView(
          style: style,
          labels: labels,
          busy: ctrl.busy,
          onStart: ctrl.startRecording,
          onCancel: widget.onCancelled,
        );
      case RecorderState.recording:
        return _RecordingView(
          style: style,
          elapsed: ctrl.elapsed,
          amplitude: ctrl.amplitude,
          busy: ctrl.busy,
          onPause: ctrl.pauseRecording,
          onSend: _onSendPressed,
        );
      case RecorderState.paused:
        return _PausedView(
          style: style,
          labels: labels,
          elapsed: ctrl.elapsed,
          busy: ctrl.busy,
          onListen: ctrl.playPreview,
          onResume: ctrl.resumeRecording,
          onDelete: ctrl.deleteAll,
          onSend: _onSendPressed,
        );
      case RecorderState.previewing:
        return _PreviewingView(
          style: style,
          labels: labels,
          elapsed: ctrl.elapsed,
          isPlaying: ctrl.preview.isPlaying,
          busy: ctrl.busy,
          waveform: ctrl.preview.waveform,
          progress: ctrl.preview.progress,
          onTogglePlay: ctrl.playPreview,
          onSeek: ctrl.seekPreview,
          onResume: ctrl.resumeRecording,
          onDelete: ctrl.deleteAll,
          onSend: _onSendPressed,
        );
    }
  }
}

// --- Reusable buttons (theme-free)

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.onTap,
    required this.color,
    required this.iconColor,
    required this.icon,
    this.size = 44,
    this.iconSize = 22,
    this.busy = false,
  });

  final VoidCallback? onTap;
  final Color color;
  final Color iconColor;
  final IconData icon;
  final double size;
  final double iconSize;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final disabled = busy || onTap == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.onTap,
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    this.labelStyle,
    this.busy = false,
  });

  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final TextStyle? labelStyle;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: busy ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ).merge(labelStyle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Views

class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.style,
    required this.labels,
    required this.busy,
    required this.onStart,
    this.onCancel,
  });

  final VoiceRecorderStyle style;
  final VoiceRecorderLabels labels;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onCancel != null)
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onCancel,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  color: style.subtitleColor,
                  size: 22,
                ),
              ),
            ),
          ),
        _CircleButton(
          onTap: onStart,
          busy: busy,
          color: style.primaryColor,
          iconColor: style.onPrimaryColor,
          icon: Icons.mic,
          size: 72,
          iconSize: 36,
        ),
        const SizedBox(height: 12),
        Text(
          labels.tapToRecord,
          style: TextStyle(color: style.subtitleColor, fontSize: 14)
              .merge(style.hintTextStyle),
        ),
      ],
    );
  }
}

class _RecordingView extends StatelessWidget {
  const _RecordingView({
    required this.style,
    required this.elapsed,
    required this.amplitude,
    required this.busy,
    required this.onPause,
    required this.onSend,
  });

  final VoiceRecorderStyle style;
  final Duration elapsed;
  final double amplitude;
  final bool busy;
  final VoidCallback onPause;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PulseDot(color: style.recordingDotColor),
        const SizedBox(width: 10),
        RecordingTimer(duration: elapsed, color: style.textColor, style: style.timerTextStyle),
        const SizedBox(width: 12),
        Expanded(
          child: LiveAmplitudeBar(
            amplitude: amplitude,
            isActive: true,
            color: style.primaryColor,
          ),
        ),
        const SizedBox(width: 8),
        _CircleButton(
          onTap: onPause,
          busy: busy,
          color: style.tonalColor,
          iconColor: style.onTonalColor,
          icon: Icons.pause_rounded,
        ),
        const SizedBox(width: 6),
        _CircleButton(
          onTap: onSend,
          busy: busy,
          color: style.primaryColor,
          iconColor: style.onPrimaryColor,
          icon: Icons.send_rounded,
        ),
      ],
    );
  }
}

class _PausedView extends StatelessWidget {
  const _PausedView({
    required this.style,
    required this.labels,
    required this.elapsed,
    required this.busy,
    required this.onListen,
    required this.onResume,
    required this.onDelete,
    required this.onSend,
  });

  final VoiceRecorderStyle style;
  final VoiceRecorderLabels labels;
  final Duration elapsed;
  final bool busy;
  final VoidCallback onListen;
  final VoidCallback onResume;
  final VoidCallback onDelete;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _CircleButton(
              onTap: onListen,
              busy: busy,
              color: style.tonalColor,
              iconColor: style.onTonalColor,
              icon: Icons.play_arrow_rounded,
            ),
            const SizedBox(width: 12),
            RecordingTimer(duration: elapsed, color: style.textColor, style: style.timerTextStyle),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: style.tonalColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                labels.pausedBadge,
                style: TextStyle(
                  color: style.onTonalColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ).merge(style.badgeTextStyle),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            GestureDetector(
              onTap: busy ? null : onDelete,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: style.errorColor,
                  size: 24,
                ),
              ),
            ),
            const Spacer(),
            _PillButton(
              onTap: onResume,
              busy: busy,
              icon: Icons.fiber_manual_record_rounded,
              label: labels.resumeButton,
              background: style.tonalColor,
              foreground: style.onTonalColor,
              labelStyle: style.buttonLabelStyle,
            ),
            const SizedBox(width: 8),
            _PillButton(
              onTap: onSend,
              busy: busy,
              icon: Icons.send_rounded,
              label: labels.sendButton,
              background: style.primaryColor,
              foreground: style.onPrimaryColor,
              labelStyle: style.buttonLabelStyle,
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewingView extends StatelessWidget {
  const _PreviewingView({
    required this.style,
    required this.labels,
    required this.elapsed,
    required this.isPlaying,
    required this.busy,
    required this.waveform,
    required this.progress,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onResume,
    required this.onDelete,
    required this.onSend,
  });

  final VoiceRecorderStyle style;
  final VoiceRecorderLabels labels;
  final Duration elapsed;
  final bool isPlaying;
  final bool busy;
  final Waveform waveform;
  final double progress;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onSeek;
  final VoidCallback onResume;
  final VoidCallback onDelete;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _CircleButton(
              onTap: onTogglePlay,
              busy: busy,
              color: style.primaryColor,
              iconColor: style.onPrimaryColor,
              icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: WaveformPlayer(
                waveform: waveform,
                progress: progress,
                onSeek: onSeek,
                playedColor: style.primaryColor,
                unplayedColor: style.waveformUnplayedColor,
              ),
            ),
            const SizedBox(width: 10),
            RecordingTimer(duration: elapsed, color: style.textColor, style: style.timerTextStyle),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            GestureDetector(
              onTap: busy ? null : onDelete,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: style.errorColor,
                  size: 24,
                ),
              ),
            ),
            const Spacer(),
            _PillButton(
              onTap: onResume,
              busy: busy,
              icon: Icons.fiber_manual_record_rounded,
              label: labels.resumeButton,
              background: style.tonalColor,
              foreground: style.onTonalColor,
              labelStyle: style.buttonLabelStyle,
            ),
            const SizedBox(width: 8),
            _PillButton(
              onTap: onSend,
              busy: busy,
              icon: Icons.send_rounded,
              label: labels.sendButton,
              background: style.primaryColor,
              foreground: style.onPrimaryColor,
              labelStyle: style.buttonLabelStyle,
            ),
          ],
        ),
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_anim),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
