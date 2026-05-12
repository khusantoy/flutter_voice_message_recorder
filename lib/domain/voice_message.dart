import 'audio_source.dart';
import 'waveform.dart';

class VoiceMessage {
  VoiceMessage({
    required this.source,
    required this.duration,
    Waveform? waveform,
    DateTime? sentAt,
  })  : waveform = waveform ?? Waveform.empty(),
        sentAt = sentAt ?? DateTime.now();

  factory VoiceMessage.local({
    required String path,
    required Duration duration,
    Waveform? waveform,
    DateTime? sentAt,
  }) =>
      VoiceMessage(
        source: LocalAudioSource(path),
        duration: duration,
        waveform: waveform,
        sentAt: sentAt,
      );

  factory VoiceMessage.remote({
    required String url,
    required Duration duration,
    Waveform? waveform,
    DateTime? sentAt,
  }) =>
      VoiceMessage(
        source: RemoteAudioSource(url),
        duration: duration,
        waveform: waveform,
        sentAt: sentAt,
      );

  final AudioSource source;
  final Duration duration;
  final Waveform waveform;
  final DateTime sentAt;
}
