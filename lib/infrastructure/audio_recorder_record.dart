import 'package:record/record.dart' as record;

import '../application/ports.dart';
import '../domain/recorder_config.dart';

class RecordPackageRecorder implements AudioRecorderPort {
  RecordPackageRecorder({
    required this.config,
    required this.paths,
  });

  final VoiceRecorderConfig config;
  final VoicePathsPort paths;

  final record.AudioRecorder _recorder = record.AudioRecorder();

  late final record.RecordConfig _recordConfig = record.RecordConfig(
    encoder: record.AudioEncoder.aacLc,
    bitRate: config.bitRate,
    sampleRate: config.sampleRate,
    numChannels: config.numChannels,
  );

  @override
  Future<String> startNewSegment() async {
    final path = await paths.newSegmentPath();
    await _recorder.start(_recordConfig, path: path);
    return path;
  }

  @override
  Future<String?> stopCurrentSegment() => _recorder.stop();

  @override
  Future<bool> isRecording() => _recorder.isRecording();

  @override
  Stream<AmplitudeReading> amplitudeStream() => _recorder
      .onAmplitudeChanged(Duration(milliseconds: config.amplitudeIntervalMs))
      .map((a) => AmplitudeReading(a.current));

  @override
  Future<void> dispose() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await _recorder.dispose();
  }
}
