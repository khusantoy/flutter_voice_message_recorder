# flutter_voice_message_recorder

A production-grade voice message recorder widget for Flutter, built for chat apps.

- **True pause / resume** — tap pause, listen back, resume, listen again. As many times as you want.
- **Mid-recording preview with a real waveform** — not a fake animation; extracted from the actual audio samples.
- **M4A (AAC-LC)** output — the standard chat voice-message format.
- **Material 3** UI out of the box.

---

## Why this project

Flutter's popular recording packages all hit the same wall: an M4A file cannot be played while the recorder holds it open, because the MP4 `moov` atom is only written on `stop()`. So most "voice message" widgets either:

1. Don't let you listen to what you've recorded until you send it, **or**
2. Let you listen, but block you from resuming afterward (WhatsApp-style), **or**
3. Fall back to WAV which is huge and not the chat standard.

This project solves the problem with a **segment-based architecture**: every pause finalizes a playable M4A segment, every resume starts the next one, and on send all segments are concatenated with FFmpeg (stream-copy, no re-encode) into one file.

The result: the user can pause, preview, resume, preview again, resume, delete, send — every combination works, and the final file is a single playable M4A.

---

## Features

| Feature | Status |
|---|---|
| Record to M4A (AAC-LC, 128 kbps, 44.1 kHz, mono) | Done |
| Pause at any point, resume from the same position | Done |
| Listen to the recording so far during pause, with scrubbable waveform | Done |
| Delete the in-progress recording and reset | Done |
| Seek the preview by dragging the waveform | Done |
| Live amplitude visualization while recording | Done |
| Auto-pause when the app goes to background | Done |
| Mic permission flow (grant / denied / permanently denied → settings) | Done |
| Material 3 theming, follows `ColorScheme` | Done |

---

## Demo

Run the example app to see the full flow:

```bash
flutter pub get
flutter run
```

The example's home screen appends each finished recording to a list. Each entry shows the saved file path and duration.

---

## Installation

Add the dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  record: ^6.2.0
  audio_waveforms: ^2.0.2
  path_provider: ^2.1.5
  permission_handler: ^12.0.1
  ffmpeg_kit_flutter_new: ^4.1.0
  intl: ^0.20.2
```

Then:

```bash
flutter pub get
```

### Android

Add the microphone permission to `android/app/src/main/AndroidManifest.xml` (inside `<manifest>`, before `<application>`):

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

Bump `minSdk` to **24** in `android/app/build.gradle.kts` (required by FFmpeg and `record` plugin internals):

```kotlin
defaultConfig {
    minSdk = 24
}
```

### iOS

Add a usage description to `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>We need access to the microphone to record voice messages.</string>
```

Set the iOS deployment target to **14.0** in `ios/Podfile`:

```ruby
platform :ios, '14.0'
```

The `ffmpeg_kit_flutter_new` pod requires iOS 14+.

---

## Usage

Drop `VoiceRecorderWidget` into any screen. It's self-contained — state, permissions, and cleanup are all handled internally.

```dart
import 'package:flutter/material.dart';
import 'package:recording/models/voice_recording_result.dart';
import 'package:recording/widgets/voice_recorder_widget.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          const Expanded(child: MessageList()),
          Padding(
            padding: const EdgeInsets.all(12),
            child: VoiceRecorderWidget(
              onRecorded: (VoiceRecordingResult result) {
                // result.filePath  -> absolute path to the final .m4a file
                // result.duration  -> total recorded Duration
                // send it, persist it, play it back — up to you.
                debugPrint('Saved ${result.filePath} (${result.duration})');
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

### `VoiceRecordingResult`

```dart
class VoiceRecordingResult {
  final String filePath;   // absolute path to the final .m4a
  final Duration duration; // sum of all recorded segments
}
```

The widget emits `VoiceRecordingResult` via `onRecorded` when the user taps **Send**. The file is written to the app documents directory and persists across app launches. You own it after that — move it, upload it, delete it as needed.

### Listening for cancellation

```dart
VoiceRecorderWidget(
  onRecorded: (result) { /* ... */ },
  onCancelled: () {
    // fired when the user discards the recording
  },
)
```

---

## Architecture

### State machine

```
                     tap mic
         idle ───────────────────▶ recording
           ▲                       │     │
           │                       │     │ tap pause
           │                       │     ▼
           │   tap send       ┌─── paused ◀─────────────┐
           │ (any state with  │    │   │                │
           │  segments)       │    │   │ tap listen     │
           │                  │    │   ▼                │
           │                  │    │ previewing ────────┤
           │                  │    │   │ (play/pause)   │
           │                  │    │   │                │
           │                  │    │   │ tap resume     │
           │                  │    │   └────────────────┘
           │                  │    │
           │    tap delete    │    │
           └──────────────────┴────┘
```

Invariants:

- Entering `recording` from `paused` or `previewing` always tears down the preview `PlayerController` first.
- The merged preview file is regenerated on every `listen` tap (because a new segment may have been added since the last preview).
- `WidgetsBindingObserver` auto-pauses recording on `AppLifecycleState.paused` so backgrounding the app never corrupts a segment.

### Segment-based M4A pipeline

```
┌────────── user flow ──────────┐        ┌──── file system ────┐
│                               │        │                     │
│  start                        │────────│  voice_seg_1.m4a    │
│                               │        │                     │
│  pause   (stop segment)       │────────│  ✓ finalized        │
│                               │        │                     │
│  listen ─ ffmpeg concat ─▶    │────────│  voice_preview.m4a  │
│          PlayerController     │        │  (scratch)          │
│          extracts waveform    │        │                     │
│                               │        │                     │
│  resume                       │────────│  voice_seg_2.m4a    │
│                               │        │                     │
│  pause                        │────────│  ✓ finalized        │
│                               │        │                     │
│  listen (regenerates preview) │────────│  voice_preview.m4a  │
│                               │        │  = seg_1 + seg_2    │
│                               │        │                     │
│  send  ─ ffmpeg concat ─▶     │────────│  voice_final_*.m4a  │
│                               │        │  = seg_1 + seg_2    │
│                               │        │  (segments deleted) │
└───────────────────────────────┘        └─────────────────────┘
```

Because every segment is encoded with identical `RecordConfig` (AAC-LC, 128 kbps, 44.1 kHz, mono), FFmpeg concatenation uses the **concat demuxer with `-c copy`** — no re-encoding, sub-second for typical voice messages.

```bash
ffmpeg -y -f concat -safe 0 -i list.txt -c copy output.m4a
```

### Module boundaries

```
lib/
  models/
    voice_recording_result.dart            data class emitted on send
  services/
    recorder_permission.dart               mic permission (granted/denied/permanent)
    voice_recorder_service.dart            wraps `record` — start/stop segment
    audio_concat_service.dart              wraps FFmpeg — concat demuxer
  controllers/
    voice_recorder_controller.dart         ChangeNotifier orchestrating state
  widgets/
    voice_recorder_widget.dart             public widget (this is the API)
    _recording_timer.dart                  mm:ss with tabular figures
    _live_amplitude_bar.dart               ring-buffer CustomPainter
    _preview_waveform_player.dart          AudioFileWaveforms adapter
```

The `VoiceRecorderController` is a plain `ChangeNotifier` with no third-party state-management dependency. If you want to embed the recorder elsewhere or drive it programmatically, you can instantiate the controller yourself — it's the only non-private moving part.

---

## Requirements

| | Minimum |
|---|---|
| Flutter | 3.41 (Dart 3.11+) |
| Android | API 24 (Android 7.0) |
| iOS | 14.0 |
| Mic permission | Required at runtime |

---

## Known limitations

- **FFmpeg binary size.** `ffmpeg_kit_flutter_new` ships a full FFmpeg build that adds ~15 MB to release APKs/IPAs. You can swap in a smaller audio-only subspec if that matters to you — concat only needs AAC muxer/demuxer support, which is in every subspec.
- **No swipe-to-cancel gesture.** Mic is a tap-to-toggle button, not a hold-to-record. Swipe-to-cancel can be added with a `GestureDetector` around the idle mic button.
- **No network upload.** The widget emits a file path via `onRecorded`. Uploading is intentionally out of scope.
- **Concat uses `-c copy`.** If a user's device records segments with divergent encoder parameters (shouldn't happen — `RecordConfig` is constant — but theoretically), the stream-copy concat can fail. A fallback to re-encoding is trivial if you hit this.
- **Emulator microphones** on both platforms are unreliable. Test on a real device.

---

## Project status

MVP. The five user-visible behaviors (record, pause, listen while paused, resume, delete, waveform playback) are implemented and verified. API is small and intentionally boring — feedback and PRs welcome.

---

## Contributing

1. Fork the repo and create a feature branch.
2. Run `flutter analyze` — it must stay clean.
3. Run `flutter test`.
4. Open a PR with a description of the change and how you tested it on a real device.

---

## License

MIT. See [LICENSE](LICENSE).

---

## Credits

- [`record`](https://pub.dev/packages/record) — cross-platform audio recording.
- [`audio_waveforms`](https://pub.dev/packages/audio_waveforms) — waveform extraction and scrubbable playback UI.
- [`ffmpeg_kit_flutter_new`](https://pub.dev/packages/ffmpeg_kit_flutter_new) — maintained fork of Arthenica's FFmpegKit bindings.
