class VoiceRecordingResult {
  VoiceRecordingResult({
    required this.filePath,
    required this.duration,
    this.waveformData = const [],
    DateTime? sentAt,
  }) : sentAt = sentAt ?? DateTime.now();

  final String filePath;
  final Duration duration;
  final List<double> waveformData;
  final DateTime sentAt;
}
