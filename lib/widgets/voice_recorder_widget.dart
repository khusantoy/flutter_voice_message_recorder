import 'package:flutter/material.dart';

import '../controllers/voice_recorder_controller.dart';
import '../models/voice_recording_result.dart';
import '../services/recorder_permission.dart';
import '_live_amplitude_bar.dart';
import '_preview_waveform_player.dart';
import '_recording_timer.dart';

class VoiceRecorderWidget extends StatefulWidget {
  const VoiceRecorderWidget({
    super.key,
    required this.onRecorded,
    this.onCancelled,
  });

  final ValueChanged<VoiceRecordingResult> onRecorded;
  final VoidCallback? onCancelled;

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  late final VoiceRecorderController _controller;
  String? _lastShownError;

  @override
  void initState() {
    super.initState();
    _controller = VoiceRecorderController();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final msg = _controller.errorMessage;
    if (msg != null && msg != _lastShownError) {
      _lastShownError = msg;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            action: _controller.lastPermissionResult ==
                    MicPermissionResult.permanentlyDenied
                ? SnackBarAction(
                    label: 'Sozlamalar',
                    onPressed: _controller.openAppSettings,
                  )
                : null,
          ),
        );
        _controller.clearError();
      });
    }
    if (mounted) setState(() {});
  }

  Future<void> _onSendPressed() async {
    final result = await _controller.finalizeAndSend();
    if (result != null && mounted) {
      widget.onRecorded(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = _controller.state;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: child,
            ),
            child: KeyedSubtree(
              key: ValueKey(state),
              child: _buildForState(state),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForState(RecorderState state) {
    switch (state) {
      case RecorderState.idle:
        return _IdleView(
          onStart: _controller.startRecording,
          onCancel: widget.onCancelled,
          busy: _controller.busy,
        );
      case RecorderState.recording:
        return _RecordingView(
          elapsed: _controller.elapsed,
          amplitude: _controller.amplitude,
          onPause: _controller.pauseRecording,
          onSend: _onSendPressed,
          busy: _controller.busy,
        );
      case RecorderState.paused:
        return _PausedView(
          elapsed: _controller.elapsed,
          busy: _controller.busy,
          onListen: _controller.playPreview,
          onResume: _controller.resumeRecording,
          onDelete: _controller.deleteAll,
          onSend: _onSendPressed,
        );
      case RecorderState.previewing:
        return _PreviewingView(
          elapsed: _controller.elapsed,
          isPlaying: _controller.isPreviewPlaying,
          busy: _controller.busy,
          waveformData: _controller.previewWaveformData,
          progress: _controller.previewProgress,
          onTogglePlay: _controller.playPreview,
          onSeek: _controller.seekPreview,
          onResume: _controller.resumeRecording,
          onDelete: _controller.deleteAll,
          onSend: _onSendPressed,
        );
    }
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.onStart,
    required this.busy,
    this.onCancel,
  });

  final VoidCallback onStart;
  final VoidCallback? onCancel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onCancel != null)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
              onPressed: onCancel,
              tooltip: 'Yopish',
              visualDensity: VisualDensity.compact,
            ),
          ),
        Material(
          color: cs.primary,
          shape: const CircleBorder(),
          elevation: 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: busy ? null : onStart,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Icon(Icons.mic, size: 36, color: cs.onPrimary),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Yozib olish uchun bosing',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _RecordingView extends StatelessWidget {
  const _RecordingView({
    required this.elapsed,
    required this.amplitude,
    required this.onPause,
    required this.onSend,
    required this.busy,
  });

  final Duration elapsed;
  final double amplitude;
  final VoidCallback onPause;
  final VoidCallback onSend;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        _PulseDot(color: cs.error),
        const SizedBox(width: 10),
        RecordingTimer(duration: elapsed),
        const SizedBox(width: 12),
        Expanded(
          child: LiveAmplitudeBar(
            amplitude: amplitude,
            isActive: true,
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: busy ? null : onPause,
          icon: const Icon(Icons.pause_rounded),
          tooltip: 'Pauza',
        ),
        const SizedBox(width: 4),
        IconButton.filled(
          onPressed: busy ? null : onSend,
          icon: const Icon(Icons.send_rounded),
          tooltip: 'Yuborish',
        ),
      ],
    );
  }
}

class _PausedView extends StatelessWidget {
  const _PausedView({
    required this.elapsed,
    required this.busy,
    required this.onListen,
    required this.onResume,
    required this.onDelete,
    required this.onSend,
  });

  final Duration elapsed;
  final bool busy;
  final VoidCallback onListen;
  final VoidCallback onResume;
  final VoidCallback onDelete;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: busy ? null : onListen,
              icon: const Icon(Icons.play_arrow_rounded),
              tooltip: 'Eshitish',
            ),
            const SizedBox(width: 12),
            RecordingTimer(duration: elapsed),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Pauza',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSecondaryContainer,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              onPressed: busy ? null : onDelete,
              icon: Icon(Icons.delete_outline_rounded, color: cs.error),
              tooltip: 'O\'chirish',
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: busy ? null : onResume,
              icon: const Icon(Icons.fiber_manual_record_rounded,
                  color: Colors.redAccent),
              label: const Text('Davom'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: busy ? null : onSend,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Yuborish'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewingView extends StatelessWidget {
  const _PreviewingView({
    required this.elapsed,
    required this.isPlaying,
    required this.busy,
    required this.waveformData,
    required this.progress,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onResume,
    required this.onDelete,
    required this.onSend,
  });

  final Duration elapsed;
  final bool isPlaying;
  final bool busy;
  final List<double> waveformData;
  final double progress;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onSeek;
  final VoidCallback onResume;
  final VoidCallback onDelete;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton.filled(
              onPressed: busy ? null : onTogglePlay,
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              tooltip: isPlaying ? 'To\'xtatish' : 'Eshitish',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PreviewWaveformPlayer(
                waveformData: waveformData,
                progress: progress,
                onSeek: onSeek,
              ),
            ),
            const SizedBox(width: 10),
            RecordingTimer(duration: elapsed),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              onPressed: busy ? null : onDelete,
              icon: Icon(Icons.delete_outline_rounded, color: cs.error),
              tooltip: 'O\'chirish',
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: busy ? null : onResume,
              icon: const Icon(Icons.fiber_manual_record_rounded,
                  color: Colors.redAccent),
              label: const Text('Davom'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: busy ? null : onSend,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Yuborish'),
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
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
