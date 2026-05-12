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
  Future<Waveform?> get(String key);
  Future<void> set(String key, Waveform waveform);
  Future<void> remove(String key);
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
  Future<String> cachedPathFor(String url);
  Future<String?> getIfCached(String url);
  Future<void> remove(String url);
}

abstract interface class VoicePathsPort {
  Future<String> newSegmentPath();
  Future<String> previewPath();
  Future<String> newFinalPath();
}
