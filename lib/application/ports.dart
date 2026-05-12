import '../domain/waveform.dart';

class AmplitudeReading {
  const AmplitudeReading(this.currentDb);
  final double currentDb;
}

abstract interface class AudioRecorderPort {
  Future<String> startNewSegment();
  Future<String?> stopCurrentSegment();
  Future<bool> isRecording();
  Stream<AmplitudeReading> amplitudeStream();
  Future<void> dispose();
}

abstract interface class AudioConcatPort {
  Future<String> concat({
    required List<String> segmentPaths,
    required String outputPath,
  });
}

abstract interface class WaveformExtractorPort {
  Future<Waveform> extract(String audioPath, {required int sampleCount});
}

enum MicPermissionResult { granted, denied, permanentlyDenied }

abstract interface class MicPermissionPort {
  Future<MicPermissionResult> ensureMicPermission();
  Future<void> openSettings();
}

abstract interface class WaveformCachePort {
  Future<Waveform?> get({required String chatId, required String key});
  Future<void> set({
    required String chatId,
    required String key,
    required Waveform waveform,
  });
  Future<void> remove({required String chatId, required String key});
  Future<void> clearChat(String chatId);
}

class DownloadProgress {
  const DownloadProgress({
    required this.received,
    required this.total,
  });

  final int received;
  final int total;

  double get fraction => total > 0 ? received / total : 0.0;
}

sealed class DownloadEvent {
  const DownloadEvent();
}

class DownloadProgressEvent extends DownloadEvent {
  const DownloadProgressEvent(this.progress);
  final DownloadProgress progress;
}

class DownloadCompleted extends DownloadEvent {
  const DownloadCompleted(this.localPath);
  final String localPath;
}

class DownloadFailed extends DownloadEvent {
  const DownloadFailed(this.error);
  final Object error;
}

class DownloadCancelledEvent extends DownloadEvent {
  const DownloadCancelledEvent();
}

abstract interface class VoiceMessageDownloadHandle {
  void cancel();
  Stream<DownloadEvent> get events;
}

abstract interface class VoiceMessageDownloaderPort {
  VoiceMessageDownloadHandle download({
    required String url,
    required String destinationPath,
  });
}

abstract interface class VoiceMessageCachePort {
  Future<String> cachedPathFor({required String chatId, required String url});
  Future<String?> getIfCached({required String chatId, required String url});
  Future<void> remove({required String chatId, required String url});
  Future<void> clearChat(String chatId);
}

abstract interface class VoicePathsPort {
  Future<String> newSegmentPath();
  Future<String> previewPath();
  Future<String> newFinalPath();
}
