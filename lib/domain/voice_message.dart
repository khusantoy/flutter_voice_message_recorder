import 'audio_source.dart';
import 'waveform.dart';

class VoiceMessage {
  VoiceMessage({
    required this.chatId,
    required this.source,
    required this.duration,
    Waveform? waveform,
    DateTime? sentAt,
  })  : waveform = waveform ?? Waveform.empty(),
        sentAt = sentAt ?? DateTime.now();

  factory VoiceMessage.local({
    required String chatId,
    required String path,
    required Duration duration,
    Waveform? waveform,
    DateTime? sentAt,
  }) =>
      VoiceMessage(
        chatId: chatId,
        source: LocalAudioSource(path),
        duration: duration,
        waveform: waveform,
        sentAt: sentAt,
      );

  factory VoiceMessage.remote({
    required String chatId,
    required String url,
    required Duration duration,
    Waveform? waveform,
    DateTime? sentAt,
  }) =>
      VoiceMessage(
        chatId: chatId,
        source: RemoteAudioSource(url),
        duration: duration,
        waveform: waveform,
        sentAt: sentAt,
      );

  final String chatId;
  final AudioSource source;
  final Duration duration;
  final Waveform waveform;
  final DateTime sentAt;
}
