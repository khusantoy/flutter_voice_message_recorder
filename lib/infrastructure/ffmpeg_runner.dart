import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

class FfmpegFailure implements Exception {
  FfmpegFailure({required this.command, required this.returnCode, required this.logs});

  final String command;
  final int? returnCode;
  final String logs;

  @override
  String toString() => 'ffmpeg failed (rc=$returnCode): $logs';
}

class FfmpegRunner {
  const FfmpegRunner();

  Future<void> run(String command) async {
    final session = await FFmpegKit.execute(command);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) return;
    final logs = await session.getAllLogsAsString();
    throw FfmpegFailure(
      command: command,
      returnCode: rc?.getValue(),
      logs: logs ?? '',
    );
  }
}
