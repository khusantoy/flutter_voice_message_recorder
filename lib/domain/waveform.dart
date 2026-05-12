import 'dart:math' as math;

class Waveform {
  Waveform(List<double> samples)
      : samples = List.unmodifiable(
          samples.map((v) => v.clamp(0.0, 1.0).toDouble()),
        );

  factory Waveform.empty() => Waveform(const []);

  factory Waveform.flat(int count) =>
      Waveform(List<double>.filled(math.max(0, count), 0.0));

  final List<double> samples;

  bool get isEmpty => samples.isEmpty;
  int get length => samples.length;
}
