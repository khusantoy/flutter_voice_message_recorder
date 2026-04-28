import 'package:flutter/material.dart';

class PreviewWaveformPlayer extends StatelessWidget {
  const PreviewWaveformPlayer({
    super.key,
    required this.waveformData,
    required this.progress,
    required this.onSeek,
    this.height = 40,
  });

  final List<double> waveformData;
  final double progress;
  final ValueChanged<double> onSeek;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => onSeek((d.localPosition.dx / width).clamp(0.0, 1.0)),
          onHorizontalDragUpdate: (d) =>
              onSeek((d.localPosition.dx / width).clamp(0.0, 1.0)),
          child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(
              painter: _WaveformPainter(
                samples: waveformData,
                progress: progress,
                playedColor: cs.primary,
                unplayedColor: cs.outlineVariant,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.samples,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
  });

  final List<double> samples;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;

  static const double _barWidth = 2.0;
  static const double _gap = 1.5;
  static const double _minBarHeight = 2.0;

  static int _barCount(double width) =>
      ((width + _gap) / (_barWidth + _gap)).floor().clamp(1, 500);

  static List<double> _aggregate(List<double> src, int targetCount) {
    if (src.isEmpty) return List.filled(targetCount, 0.0);
    if (src.length == targetCount) return src;
    return List.generate(targetCount, (i) {
      final start = (i * src.length / targetCount).floor();
      final end =
          ((i + 1) * src.length / targetCount).ceil().clamp(0, src.length);
      if (start >= end) return 0.0;
      return src.sublist(start, end).fold(0.0, (a, b) => a + b) / (end - start);
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final count = _barCount(size.width);
    final bars = _aggregate(samples, count);
    final centerY = size.height / 2;
    final seekX = size.width * progress.clamp(0.0, 1.0);

    final playedPaint = Paint()
      ..color = playedColor
      ..style = PaintingStyle.fill;
    final unplayedPaint = Paint()
      ..color = unplayedColor
      ..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final x = i * (_barWidth + _gap);
      final v = bars[i].clamp(0.0, 1.0);
      final barH = (v * size.height).clamp(_minBarHeight, size.height);
      final barCenterX = x + _barWidth / 2;

      canvas.drawRRect(
        RRect.fromLTRBR(
          x,
          centerY - barH / 2,
          x + _barWidth,
          centerY + barH / 2,
          const Radius.circular(_barWidth / 2),
        ),
        barCenterX <= seekX ? playedPaint : unplayedPaint,
      );
    }

    if (progress > 0.0) {
      canvas.drawLine(
        Offset(seekX, 0),
        Offset(seekX, size.height),
        Paint()
          ..color = playedColor
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.progress != progress || old.samples != samples;
}
