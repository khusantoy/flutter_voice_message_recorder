import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  static const _config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 128000,
    sampleRate: 44100,
    numChannels: 1,
  );

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<String> startNewSegment() async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/voice_seg_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(_config, path: path);
    return path;
  }

  Future<String?> stopCurrentSegment() => _recorder.stop();

  Future<bool> isRecording() => _recorder.isRecording();

  Stream<Amplitude> amplitudeStream() =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 100));

  Future<void> dispose() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await _recorder.dispose();
  }
}
