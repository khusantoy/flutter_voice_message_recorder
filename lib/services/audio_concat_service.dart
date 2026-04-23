import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

class AudioConcatService {
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

    final cmd =
        "-y -f concat -safe 0 -i '${listFile.path}' -c copy '$outputPath'";
    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();

    try {
      await listFile.delete();
    } catch (_) {}

    if (!ReturnCode.isSuccess(rc)) {
      final logs = await session.getAllLogsAsString();
      throw Exception('ffmpeg concat failed (rc=${rc?.getValue()}): $logs');
    }
    return outputPath;
  }
}
