class VoiceRecorderConfig {
  const VoiceRecorderConfig({
    this.bitRate = 128000,
    this.sampleRate = 44100,
    this.numChannels = 1,
    this.amplitudeFloorDb = 45.0,
    this.previewWaveformSampleCount = 200,
    this.bubbleWaveformSampleCount = 100,
    this.amplitudeIntervalMs = 100,
    this.tickerIntervalMs = 200,
  });

  final int bitRate;
  final int sampleRate;
  final int numChannels;
  final double amplitudeFloorDb;
  final int previewWaveformSampleCount;
  final int bubbleWaveformSampleCount;
  final int amplitudeIntervalMs;
  final int tickerIntervalMs;

  double normalizeAmplitudeDb(double db) =>
      ((db + amplitudeFloorDb).clamp(0.0, amplitudeFloorDb)) /
      amplitudeFloorDb;
}
