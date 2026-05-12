import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../application/ports.dart';
import 'ffmpeg_runner.dart';

class FfmpegAudioConcat implements AudioConcatPort {
  FfmpegAudioConcat({FfmpegRunner? runner})
      : _runner = runner ?? const FfmpegRunner();

  final FfmpegRunner _runner;

  @override
  Future<String> concat({
    required List<String> segmentPaths,
    required String outputPath,
  }) async {
    if (segmentPaths.isEmpty) {
      throw ArgumentError('segmentPaths is empty');
    }

    if (segmentPaths.length == 1) {
      final src = File(segmentPaths.first);
      final dst = File(outputPath);
      if (dst.existsSync()) await dst.delete();
      await src.copy(outputPath);
      return outputPath;
    }

    final tmpDir = await getTemporaryDirectory();
    final listFile = File(
      '${tmpDir.path}/concat_list_${DateTime.now().microsecondsSinceEpoch}.txt',
    );
    final listContent = segmentPaths
        .map((p) => "file '${p.replaceAll("'", r"'\''")}'")
        .join('\n');
    await listFile.writeAsString(listContent);

    if (File(outputPath).existsSync()) {
      await File(outputPath).delete();
    }

    try {
      await _runner.run(
        "-y -f concat -safe 0 -i '${listFile.path}' -c copy '$outputPath'",
      );
      return outputPath;
    } finally {
      try {
        await listFile.delete();
      } catch (_) {}
    }
  }
}
