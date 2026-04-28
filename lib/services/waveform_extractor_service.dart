import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

class WaveformExtractorService {
  Future<List<double>> extract(String audioPath, {int sampleCount = 100}) async {
    final tmpDir = await getTemporaryDirectory();
    final pcmPath =
        '${tmpDir.path}/waveform_${DateTime.now().microsecondsSinceEpoch}.raw';

    final cmd = '-y -i "$audioPath" -ac 1 -ar 8000 -f s16le "$pcmPath"';
    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();

    if (!ReturnCode.isSuccess(rc)) {
      final logs = await session.getAllLogsAsString();
      throw Exception('waveform extraction failed (rc=${rc?.getValue()}): $logs');
    }

    final bytes = await File(pcmPath).readAsBytes();
    try {
      await File(pcmPath).delete();
    } catch (_) {}

    if (bytes.isEmpty) return List.filled(sampleCount, 0.0);

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
    if (maxRms == 0) return List.filled(sampleCount, 0.0);

    return rms.map((v) => sqrt(v / maxRms)).toList();
  }
}
