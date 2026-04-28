# flutter_voice_message_recorder

A production-grade voice message recorder and chat bubble player for Flutter, built for chat apps.

- **True pause / resume** — tap pause, listen back, resume, listen again. As many times as you want.
- **Mid-recording preview with a real waveform** — extracted from the actual audio via FFmpeg PCM decoding, not a fake animation.
- **Playable chat bubbles** — each sent message renders as a scrubbable waveform bubble with play/pause, live position counter, and timestamp.
- **Waveform cache** — extracted waveform data is persisted to disk so it never needs to be re-computed.
- **M4A (AAC-LC)** output — the standard chat voice-message format.
- **Material 3** UI, follows `ColorScheme` automatically.

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
| Record to M4A (AAC-LC, 128 kbps, 44.1 kHz, mono) | ✓ |
| Pause at any point, resume from the same position | ✓ |
| Preview the recording during pause with a scrubbable waveform | ✓ |
| Send as a playable chat bubble with waveform + seek | ✓ |
| Duration-adaptive bubble width (short audio → narrow, long → wide) | ✓ |
| Exclusive playback (only one bubble plays at a time) | ✓ |
| Waveform cache persisted to disk (no re-extraction on restart) | ✓ |
| Delete the in-progress recording and reset | ✓ |
| Live amplitude visualization while recording | ✓ |
| Auto-pause when the app goes to background | ✓ |
| Mic permission flow (grant / denied / permanently denied → settings) | ✓ |

---

## Demo

```bash
flutter pub get
flutter run
```

The example app renders a chat screen. Tap the mic button in the input bar to record, send the message, and play it back from the bubble. Multiple messages can exist simultaneously; only one plays at a time.

---

## Installation

```yaml
dependencies:
  record: ^6.2.0
  audioplayers: ^6.6.0
  path_provider: ^2.1.5
  permission_handler: ^12.0.1
  ffmpeg_kit_flutter_new: ^4.1.0
```

```bash
flutter pub get
```

### Android

Add the microphone permission to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

Bump `minSdk` to **24** in `android/app/build.gradle.kts`:

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

---

## Usage

### Recorder widget

Drop `VoiceRecorderWidget` into any screen. State, permissions, and cleanup are all handled internally.

```dart
VoiceRecorderWidget(
  onRecorded: (VoiceRecordingResult result) {
    // result.filePath      → absolute path to the final .m4a
    // result.duration      → total recorded Duration
    // result.waveformData  → List<double> (0.0–1.0), ready to render
    // result.sentAt        → DateTime the message was finalized
  },
  onCancelled: () {
    // fired when the user discards the recording
  },
)
```

### Chat bubble

`VoiceMessageBubble` is a self-contained playback widget. Pass a shared `ValueNotifier<String?>` across all bubbles so only one plays at a time.

```dart
final ValueNotifier<String?> playingPath = ValueNotifier(null);

// in your list builder:
VoiceMessageBubble(
  recording: result,
  playingNotifier: playingPath,
)
```

The bubble manages its own `AudioPlayer`, subscribes to position and state streams, and pauses itself whenever `playingNotifier` changes to a different file path.

### `VoiceRecordingResult`

```dart
class VoiceRecordingResult {
  final String filePath;         // absolute path to the final .m4a
  final Duration duration;       // sum of all recorded segments
  final List<double> waveformData; // normalized RMS samples (0.0–1.0)
  final DateTime sentAt;         // timestamp when the message was finalized
}
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

- Entering `recording` from `paused` or `previewing` always tears down the preview player first.
- The merged preview file is regenerated on every `listen` tap (a new segment may have been added since the last preview).
- `WidgetsBindingObserver` auto-pauses recording on `AppLifecycleState.paused` so backgrounding never corrupts a segment.

### Segment-based M4A pipeline

```
┌────────── user flow ──────────┐        ┌──── file system ────┐
│                               │        │                     │
│  start                        │────────│  voice_seg_1.m4a    │
│                               │        │                     │
│  pause   (stop segment)       │────────│  ✓ finalized        │
│                               │        │                     │
│  listen ─ ffmpeg concat ─▶    │────────│  voice_preview.m4a  │
│          audioplayers plays   │        │  (scratch)          │
│          FFmpeg extracts      │        │                     │
│          waveform via PCM     │        │                     │
│                               │        │                     │
│  resume                       │────────│  voice_seg_2.m4a    │
│                               │        │                     │
│  pause                        │────────│  ✓ finalized        │
│                               │        │                     │
│  send  ─ ffmpeg concat ─▶     │────────│  voice_final_*.m4a  │
│          waveform cached      │        │  = seg_1 + seg_2    │
│                               │        │  (segments deleted) │
└───────────────────────────────┘        └─────────────────────┘
```

FFmpeg concatenation uses the **concat demuxer with `-c copy`** — no re-encoding, sub-second for typical voice messages.

### Waveform extraction

The waveform is extracted independently of playback using a second FFmpeg pass:

```
audio file → FFmpeg → raw PCM (8 kHz, mono, s16le)
    → split into N chunks → RMS per chunk
    → normalize by max RMS → sqrt (dynamic range compression)
    → List<double> (0.0–1.0)
```

This gives a consistent waveform regardless of which audio player is used.

### Waveform cache

`WaveformCacheService` is a singleton backed by `.waveform_cache.json` in the app documents directory. Waveform data is keyed by file path and loaded lazily on first use.

```
send message
    ├─ preview was open → reuse already-extracted data (no FFmpeg call)
    └─ sent directly   → extract now, then cache

open bubble
    ├─ VoiceRecordingResult.waveformData present → use directly
    ├─ found in JSON cache                       → use from disk
    └─ not found                                 → extract + cache
```

### Module boundaries

```
lib/
  models/
    voice_recording_result.dart          data class emitted on send
  services/
    recorder_permission.dart             mic permission flow
    voice_recorder_service.dart          wraps `record` — start/stop segment
    audio_concat_service.dart            wraps FFmpeg — concat demuxer
    waveform_extractor_service.dart      FFmpeg PCM → RMS → List<double>
    waveform_cache_service.dart          disk-backed waveform cache
  controllers/
    voice_recorder_controller.dart       ChangeNotifier orchestrating state
  widgets/
    voice_recorder_widget.dart           recorder UI (public API)
    voice_message_bubble.dart            playable chat bubble (public API)
    _recording_timer.dart                mm:ss with tabular figures
    _live_amplitude_bar.dart             ring-buffer CustomPainter
    _preview_waveform_player.dart        StatelessWidget waveform + seek
```

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

- **FFmpeg binary size.** `ffmpeg_kit_flutter_new` adds ~15 MB to release builds. An audio-only subspec can reduce this; concat only needs AAC muxer/demuxer support.
- **No swipe-to-cancel gesture.** Mic is tap-to-toggle. Swipe-to-cancel can be added with a `GestureDetector` around the idle mic button.
- **No network upload.** The widget emits a file path. Uploading is intentionally out of scope.
- **In-memory message list.** The demo app stores messages in a `List` — they are lost on restart. A real app would persist them to a local database.
- **Emulator microphones** on both platforms are unreliable. Test on a real device.

---

## Contributing

1. Fork the repo and create a feature branch.
2. Run `flutter analyze` — it must stay clean.
3. Open a PR with a description of the change and how you tested it on a real device.

---

## License

MIT. See [LICENSE](LICENSE).

---

## Credits

- [`record`](https://pub.dev/packages/record) — cross-platform audio recording.
- [`audioplayers`](https://pub.dev/packages/audioplayers) — audio playback.
- [`ffmpeg_kit_flutter_new`](https://pub.dev/packages/ffmpeg_kit_flutter_new) — maintained fork of Arthenica's FFmpegKit bindings.
