import 'dart:collection';

import 'package:flutter/material.dart';

class LiveAmplitudeBar extends StatefulWidget {
  const LiveAmplitudeBar({
    super.key,
    required this.amplitude,
    required this.isActive,
    this.barCount = 28,
    this.height = 32,
  });

  final double amplitude;
  final bool isActive;
  final int barCount;
  final double height;

  @override
  State<LiveAmplitudeBar> createState() => _LiveAmplitudeBarState();
}

class _LiveAmplitudeBarState extends State<LiveAmplitudeBar> {
  late final Queue<double> _buffer = Queue<double>.of(
    List<double>.filled(widget.barCount, 0.0),
  );

  @override
  void didUpdateWidget(covariant LiveAmplitudeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && widget.amplitude != oldWidget.amplitude) {
      if (_buffer.length >= widget.barCount) _buffer.removeFirst();
      _buffer.addLast(widget.amplitude.clamp(0.0, 1.0));
    } else if (!widget.isActive) {
      if (_buffer.any((v) => v > 0)) {
        _buffer
          ..clear()
          ..addAll(List<double>.filled(widget.barCount, 0.0));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: widget.height,
      child: CustomPaint(
        painter: _AmpPainter(
          values: _buffer.toList(),
          color: theme.colorScheme.primary,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _AmpPainter extends CustomPainter {
  _AmpPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const gap = 2.0;
    final barWidth =
        (size.width - gap * (values.length - 1)) / values.length;
    if (barWidth <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;
    final centerY = size.height / 2;
    for (var i = 0; i < values.length; i++) {
      final v = values[i].clamp(0.0, 1.0);
      final barHeight = (v * size.height).clamp(2.0, size.height);
      final x = i * (barWidth + gap);
      final rect = RRect.fromLTRBR(
        x,
        centerY - barHeight / 2,
        x + barWidth,
        centerY + barHeight / 2,
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmpPainter old) =>
      old.values != values || old.color != color;
}
