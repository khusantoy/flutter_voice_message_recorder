import 'package:flutter/widgets.dart';

import '../application/playback_coordinator.dart';
import '../application/ports.dart';
import '../domain/recorder_config.dart';
import '../infrastructure/audio_concat_ffmpeg.dart';
import '../infrastructure/audio_recorder_record.dart';
import '../infrastructure/mic_permission_handler.dart';
import '../infrastructure/voice_message_cache_fs.dart';
import '../infrastructure/voice_message_downloader_dio.dart';
import '../infrastructure/voice_paths.dart';
import '../infrastructure/waveform_cache_json.dart';
import '../infrastructure/waveform_extractor_ffmpeg.dart';

class AppDependencies {
  AppDependencies({
    VoiceRecorderConfig? config,
    VoicePathsPort? paths,
    AudioConcatPort? concat,
    WaveformExtractorPort? waveformExtractor,
    WaveformCachePort? waveformCache,
    MicPermissionPort? permission,
    VoiceMessageCachePort? voiceCache,
    VoiceMessageDownloaderPort? downloader,
    PlaybackCoordinator? coordinator,
  })  : config = config ?? const VoiceRecorderConfig(),
        paths = paths ?? AppDocsVoicePaths(),
        concat = concat ?? FfmpegAudioConcat(),
        waveformExtractor = waveformExtractor ?? FfmpegWaveformExtractor(),
        waveformCache = waveformCache ?? JsonFileWaveformCache(),
        permission = permission ?? PermissionHandlerMic(),
        voiceCache = voiceCache ?? FileSystemVoiceCache(),
        downloader = downloader ?? DioVoiceDownloader(),
        coordinator = coordinator ?? PlaybackCoordinator();

  final VoiceRecorderConfig config;
  final VoicePathsPort paths;
  final AudioConcatPort concat;
  final WaveformExtractorPort waveformExtractor;
  final WaveformCachePort waveformCache;
  final MicPermissionPort permission;
  final VoiceMessageCachePort voiceCache;
  final VoiceMessageDownloaderPort downloader;
  final PlaybackCoordinator coordinator;

  AudioRecorderPort newRecorder() =>
      RecordPackageRecorder(config: config, paths: paths);
}

class AppDependenciesScope extends InheritedWidget {
  const AppDependenciesScope({
    super.key,
    required this.dependencies,
    required super.child,
  });

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppDependenciesScope>();
    assert(scope != null, 'AppDependenciesScope is missing above this context');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(covariant AppDependenciesScope old) =>
      dependencies != old.dependencies;
}
