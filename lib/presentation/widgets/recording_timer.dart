import 'package:flutter/widgets.dart';

class RecordingTimer extends StatelessWidget {
  const RecordingTimer({
    super.key,
    required this.duration,
    required this.color,
    this.style,
  });

  final Duration duration;
  final Color color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return Text(
      '$minutes:$seconds',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ).merge(style),
    );
  }
}
