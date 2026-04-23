import 'package:flutter/material.dart';

class RecordingTimer extends StatelessWidget {
  const RecordingTimer({
    super.key,
    required this.duration,
    this.style,
  });

  final Duration duration;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    final theme = Theme.of(context);
    return Text(
      '$minutes:$seconds',
      style: style ??
          theme.textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            color: theme.colorScheme.onSurface,
          ),
    );
  }
}
