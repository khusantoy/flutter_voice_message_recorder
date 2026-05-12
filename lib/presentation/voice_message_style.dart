import 'package:flutter/painting.dart';

/// Visual configuration for [VoiceMessageBubble]. Default values give a
/// Material-3-like deepPurple look; override any field to match your design.
///
/// `TextStyle?` fields are merged with sensible defaults — pass only the
/// properties you want to override (e.g. `fontFamily`).
class VoiceBubbleStyle {
  const VoiceBubbleStyle({
    this.bubbleColor = const Color(0xFFE7DEFC),
    this.primaryColor = const Color(0xFF6750A4),
    this.onPrimaryColor = const Color(0xFFFFFFFF),
    this.waveformUnplayedColor = const Color(0xFFC8C5D0),
    this.textColor = const Color(0xFF1D1B20),
    this.subtitleColor = const Color(0x991D1B20),
    this.errorColor = const Color(0xFFB3261E),
    this.borderRadius = const BorderRadius.only(
      topLeft: Radius.circular(18),
      topRight: Radius.circular(4),
      bottomLeft: Radius.circular(18),
      bottomRight: Radius.circular(18),
    ),
    this.subtitleTextStyle,
    this.timestampTextStyle,
  });

  final Color bubbleColor;
  final Color primaryColor;
  final Color onPrimaryColor;
  final Color waveformUnplayedColor;
  final Color textColor;
  final Color subtitleColor;
  final Color errorColor;
  final BorderRadius borderRadius;

  /// Style for the subtitle text under the waveform (duration / progress / error).
  /// Defaults to `fontSize: 11, color: subtitleColor` with tabular figures.
  final TextStyle? subtitleTextStyle;

  /// Style for the timestamp shown at the bottom-right of the bubble.
  /// Defaults to `fontSize: 11, color: subtitleColor`.
  final TextStyle? timestampTextStyle;
}

/// User-facing strings for [VoiceRecorderWidget]. Override for localization.
class VoiceRecorderLabels {
  const VoiceRecorderLabels({
    this.tapToRecord = 'Yozib olish uchun bosing',
    this.pausedBadge = 'Pauza',
    this.resumeButton = 'Davom',
    this.sendButton = 'Yuborish',
  });

  /// English defaults — handy as `const VoiceRecorderLabels.en()`.
  const VoiceRecorderLabels.en()
      : tapToRecord = 'Tap to record',
        pausedBadge = 'Paused',
        resumeButton = 'Resume',
        sendButton = 'Send';

  final String tapToRecord;
  final String pausedBadge;
  final String resumeButton;
  final String sendButton;
}

/// Visual configuration for [VoiceRecorderWidget]. See [VoiceBubbleStyle] for
/// notes on `TextStyle?` fields.
class VoiceRecorderStyle {
  const VoiceRecorderStyle({
    this.surfaceColor = const Color(0xFFF3EDF7),
    this.primaryColor = const Color(0xFF6750A4),
    this.onPrimaryColor = const Color(0xFFFFFFFF),
    this.tonalColor = const Color(0xFFE8DEF8),
    this.onTonalColor = const Color(0xFF1D192B),
    this.textColor = const Color(0xFF1D1B20),
    this.subtitleColor = const Color(0x991D1B20),
    this.errorColor = const Color(0xFFB3261E),
    this.recordingDotColor = const Color(0xFFB3261E),
    this.waveformUnplayedColor = const Color(0xFFC8C5D0),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.hintTextStyle,
    this.timerTextStyle,
    this.badgeTextStyle,
    this.buttonLabelStyle,
  });

  final Color surfaceColor;
  final Color primaryColor;
  final Color onPrimaryColor;
  final Color tonalColor;
  final Color onTonalColor;
  final Color textColor;
  final Color subtitleColor;
  final Color errorColor;
  final Color recordingDotColor;
  final Color waveformUnplayedColor;
  final BorderRadius borderRadius;

  /// "Tap to record" hint under the idle mic. Default: 14 px, subtitle color.
  final TextStyle? hintTextStyle;

  /// mm:ss timer text during recording. Default: 16 px w600, [textColor], tabular figures.
  final TextStyle? timerTextStyle;

  /// "Paused" badge text. Default: 12 px w600, [onTonalColor].
  final TextStyle? badgeTextStyle;

  /// Text inside the pill buttons ("Resume", "Send"). Default: 14 px w600.
  final TextStyle? buttonLabelStyle;
}
