import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';

class PreviewWaveformPlayer extends StatelessWidget {
  const PreviewWaveformPlayer({
    super.key,
    required this.controller,
    this.height = 40,
  });

  final PlayerController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return AudioFileWaveforms(
          size: Size(constraints.maxWidth, height),
          playerController: controller,
          enableSeekGesture: true,
          waveformType: WaveformType.fitWidth,
          continuousWaveform: true,
          playerWaveStyle: PlayerWaveStyle(
            fixedWaveColor: cs.outlineVariant,
            liveWaveColor: cs.primary,
            seekLineColor: cs.primary,
            showSeekLine: true,
            waveThickness: 2.5,
            spacing: 5,
          ),
        );
      },
    );
  }
}
