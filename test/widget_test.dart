import 'package:flutter_test/flutter_test.dart';
import 'package:recording/domain/waveform.dart';

void main() {
  test('Waveform.flat returns zero-filled samples', () {
    final w = Waveform.flat(5);
    expect(w.length, 5);
    expect(w.samples, [0.0, 0.0, 0.0, 0.0, 0.0]);
  });

  test('Waveform clamps values to 0..1', () {
    final w = Waveform([-0.5, 0.25, 1.5]);
    expect(w.samples, [0.0, 0.25, 1.0]);
  });

  test('Waveform.empty is empty', () {
    expect(Waveform.empty().isEmpty, true);
  });
}
