import 'dart:collection';

import 'package:flutter/material.dart';

class LiveAmplitudeBar extends StatefulWidget {
  const LiveAmplitudeBar({
    super.key,
    required this.amplitude,
    required this.isActive,
    this.height = 40,
  });

  final double amplitude;
  final bool isActive;
  final double height;

  @override
  State<LiveAmplitudeBar> createState() => _LiveAmplitudeBarState();
}

class _LiveAmplitudeBarState extends State<LiveAmplitudeBar> {
  static const double _barWidth = 3.0;
  static const double _gap = 4.5;

  final Queue<double> _buffer = Queue<double>();
  int _barCount = 0;

  static int _computeCount(double width) =>
      ((width + _gap) / (_barWidth + _gap)).floor().clamp(1, 300);

  void _syncBuffer(int count) {
    if (count == _barCount) return;
    _barCount = count;
    while (_buffer.length > count) _buffer.removeFirst();
    while (_buffer.length < count) _buffer.addFirst(0.0);
  }

  @override
  void didUpdateWidget(covariant LiveAmplitudeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_barCount == 0) return;
    if (widget.isActive && widget.amplitude != oldWidget.amplitude) {
      if (_buffer.length >= _barCount) _buffer.removeFirst();
      _buffer.addLast(widget.amplitude.clamp(0.0, 1.0));
    } else if (!widget.isActive && _buffer.any((v) => v > 0)) {
      _buffer
        ..clear()
        ..addAll(List<double>.filled(_barCount, 0.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        _syncBuffer(_computeCount(constraints.maxWidth));
        return SizedBox(
          height: widget.height,
          child: CustomPaint(
            painter: _AmpPainter(
              values: _buffer.toList(),
              color: color,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _AmpPainter extends CustomPainter {
  _AmpPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  static const double _barWidth = 3.0;
  static const double _gap = 4.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final centerY = size.height / 2;
    for (var i = 0; i < values.length; i++) {
      final v = values[i].clamp(0.0, 1.0);
      final barHeight = (v * size.height).clamp(_barWidth, size.height);
      final x = i * (_barWidth + _gap);
      canvas.drawRRect(
        RRect.fromLTRBR(
          x,
          centerY - barHeight / 2,
          x + _barWidth,
          centerY + barHeight / 2,
          const Radius.circular(_barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AmpPainter old) =>
      old.values != values || old.color != color;
}
