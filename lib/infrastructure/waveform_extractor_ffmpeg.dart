import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../application/ports.dart';
import '../domain/waveform.dart';
import 'ffmpeg_runner.dart';

class FfmpegWaveformExtractor implements WaveformExtractorPort {
  FfmpegWaveformExtractor({FfmpegRunner? runner})
      : _runner = runner ?? const FfmpegRunner();

  final FfmpegRunner _runner;

  @override
  Future<Waveform> extract(String audioPath, {required int sampleCount}) async {
    final tmpDir = await getTemporaryDirectory();
    final pcmPath =
        '${tmpDir.path}/waveform_${DateTime.now().microsecondsSinceEpoch}.raw';

    await _runner.run('-y -i "$audioPath" -ac 1 -ar 8000 -f s16le "$pcmPath"');

    final bytes = await File(pcmPath).readAsBytes();
    try {
      await File(pcmPath).delete();
    } catch (_) {}

    if (bytes.isEmpty) return Waveform.flat(sampleCount);

    final data = bytes.buffer.asByteData();
    final totalSamples = bytes.length ~/ 2;
    final chunkSize = max(1, totalSamples ~/ sampleCount);

    final rms = <double>[];
    for (var i = 0; i < sampleCount; i++) {
      final start = i * chunkSize;
      final end = min(start + chunkSize, totalSamples);
      if (start >= totalSamples) {
        rms.add(0.0);
        continue;
      }
      double sum = 0;
      for (var j = start; j < end; j++) {
        final s = data.getInt16(j * 2, Endian.little).toDouble();
        sum += s * s;
      }
      rms.add(sqrt(sum / (end - start)));
    }

    final maxRms = rms.reduce(max);
    if (maxRms == 0) return Waveform.flat(sampleCount);

    return Waveform(rms.map((v) => sqrt(v / maxRms)).toList());
  }
}
