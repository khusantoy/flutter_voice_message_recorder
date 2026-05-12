# flutter_voice_message_recorder

A production-grade voice message recorder and chat bubble player for Flutter, built for chat apps.

- **True pause / resume** — tap pause, listen back, resume, listen again. As many times as you want.
- **Mid-recording preview with a real waveform** — extracted from the actual audio via FFmpeg PCM decoding, not a fake animation.
- **Playable chat bubbles** — each sent message renders as a scrubbable waveform bubble with play/pause, live position counter, and timestamp.
- **Local *and* network audio** — the same bubble handles a freshly recorded file or a remote URL. Downloads stream with progress, cancel, and on-disk caching (cached_network_image style).
- **Per-chat cache, wipeable on demand** — every `VoiceMessage` carries a `chatId`; audio files and waveforms are stored under that scope and `clearChat(chatId)` evicts both in one call (no orphaned files when a chat is deleted).
- **Waveform cache** — extracted waveform data is persisted to disk so it never needs to be re-computed. Server-supplied waveforms (Telegram-style metadata) are honored and skip extraction entirely.
- **M4A (AAC-LC)** output — the standard chat voice-message format.
- **Theme-agnostic widgets.** No `Theme.of(context)` lookups inside the public widgets — colors are passed explicitly through `VoiceBubbleStyle` / `VoiceRecorderStyle`. Drop the widgets into any app (Material, Cupertino, or your own design system) without colour leakage.
- **`ListenableBuilder` based.** Public widgets contain zero `setState` calls — reactivity flows through the controllers' `ChangeNotifier` and only the affected subtree rebuilds.
- **Ports & adapters architecture** — every device dependency (recorder, ffmpeg, dio, permission handler, filesystem) sits behind a Dart interface, so swapping implementations or unit-testing controllers requires no real I/O.

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
| Remote voice messages from a URL (`VoiceMessage.remote`) | ✓ |
| User-triggered download with progress (%, MB/MB) and cancel | ✓ |
| On-disk audio cache (`voice_cache/<chatId>/<sha1>.<ext>`) — no re-downloads | ✓ |
| Per-chat cache wipe (`voiceCache.clearChat` / `waveformCache.clearChat`) | ✓ |
| Server-supplied waveform metadata honored (Telegram-style) | ✓ |
| Duration-adaptive bubble width (short audio → narrow, long → wide) | ✓ |
| Exclusive playback (only one bubble plays at a time, identity-based) | ✓ |
| Waveform cache persisted to disk (no re-extraction on restart) | ✓ |
| Delete the in-progress recording and reset | ✓ |
| Live amplitude visualization while recording | ✓ |
| Auto-pause when the app goes to background | ✓ |
| Mic permission flow (grant / denied / permanently denied → settings) | ✓ |
| Typed failures (`sealed RecorderFailure`) — no stringly-typed errors | ✓ |

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
  dio: ^5.7.0      # network audio download with progress + cancel
  crypto: ^3.0.6   # sha1 hashing for cache file names
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

### Wire up dependencies once at startup

Every widget pulls its collaborators (recorder, ffmpeg, dio, cache, permission handler) from an `AppDependencies` instance exposed through an `InheritedWidget`. Build it once in `main()`:

```dart
void main() {
  runApp(VoiceRecorderDemoApp(dependencies: AppDependencies()));
}

class VoiceRecorderDemoApp extends StatelessWidget {
  const VoiceRecorderDemoApp({super.key, required this.dependencies});
  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return AppDependenciesScope(
      dependencies: dependencies,
      child: MaterialApp(home: const ChatPage()),
    );
  }
}
```

`AppDependencies()` ships with sensible default adapters (record, audioplayers, FFmpegKit, dio, permission_handler, app-docs filesystem). Override any of them in tests or alternate environments by passing constructor parameters.

### Recorder widget

Drop `VoiceRecorderWidget` into any screen. State, permissions, and cleanup are all handled internally. Colours come from an explicit `VoiceRecorderStyle` — defaults match a Material 3 deepPurple palette but nothing is read from `Theme.of(context)`.

```dart
VoiceRecorderWidget(
  chatId: 'chat-42',   // scopes the recording's waveform cache to this chat
  onRecorded: (VoiceMessage message) {
    // message.source     → LocalAudioSource(path)
    // message.duration   → total recorded Duration
    // message.waveform   → Waveform (immutable, samples clamped to 0..1)
    // message.sentAt     → DateTime the message was finalized
  },
  onCancelled: () {
    // fired when the user discards the recording
  },
  onFailure: (RecorderFailure failure) {
    // sealed: PermissionDenied | PermissionBlocked | EncodingFailed
    //       | StorageError    | UnknownRecorderFailure
    // Show a SnackBar, banner, or whatever your app uses.
  },
  style: const VoiceRecorderStyle(
    primaryColor: Color(0xFF128C7E),  // WhatsApp green, for example
    // …all other colours are optional
  ),
  labels: const VoiceRecorderLabels.en(),  // or supply your own translations
)
```

`VoiceRecorderLabels` exposes every user-visible string in the recorder:

```dart
const VoiceRecorderLabels(
  tapToRecord: 'Tap to record',
  pausedBadge: 'Paused',
  resumeButton: 'Resume',
  sendButton: 'Send',
)
```

### Chat bubble — local or remote

`VoiceMessageBubble` accepts a single `VoiceMessage`. The bubble decides at runtime whether to render the local-playback UI or the download/progress/play UI based on the message's `AudioSource` and the on-disk cache.

```dart
// Local — newly recorded:
VoiceMessageBubble(message: result);

// Remote — coming from your chat backend:
VoiceMessageBubble(
  message: VoiceMessage.remote(
    chatId: 'chat-42',
    url: serverMessage.audioUrl,
    duration: serverMessage.duration,
    waveform: Waveform(serverMessage.waveformBars), // optional but recommended
  ),
  style: const VoiceBubbleStyle(
    bubbleColor: Color(0xFFDCF8C6),    // outgoing-bubble green
    primaryColor: Color(0xFF128C7E),
  ),
);
```

Only one bubble plays at a time. The exclusivity is enforced by the shared `PlaybackCoordinator` inside `AppDependencies` — no manual `ValueNotifier` plumbing.

### Theming

There is no `Theme.of(context)` lookup inside either widget. Every colour and corner radius is taken from the `style:` parameter, and the default style is a self-contained `const` value — so the widgets are fully usable under `WidgetsApp`, `CupertinoApp`, or any custom root.

```dart
class VoiceBubbleStyle {
  Color bubbleColor;            // bubble background
  Color primaryColor;           // play button, played waveform, progress ring
  Color onPrimaryColor;         // icons on top of primary
  Color waveformUnplayedColor;  // unplayed bars + ring track
  Color textColor;
  Color subtitleColor;          // duration / progress text
  Color errorColor;
  BorderRadius borderRadius;
  TextStyle? subtitleTextStyle;  // override font for progress/duration text
  TextStyle? timestampTextStyle; // override font for the time stamp
}

class VoiceRecorderStyle {
  Color surfaceColor;           // recorder card background
  Color primaryColor;           // mic / send buttons
  Color onPrimaryColor;
  Color tonalColor;             // secondary button background (pause, resume)
  Color onTonalColor;
  Color textColor;
  Color subtitleColor;
  Color errorColor;
  Color recordingDotColor;
  Color waveformUnplayedColor;
  BorderRadius borderRadius;
  TextStyle? hintTextStyle;     // override font for "tap to record" hint
  TextStyle? timerTextStyle;    // override font for mm:ss timer
  TextStyle? badgeTextStyle;    // override font for "Paused" badge
  TextStyle? buttonLabelStyle;  // override font for Resume / Send buttons
}
```

All `TextStyle?` fields are merged onto sensible base styles — pass only what you need (e.g. `TextStyle(fontFamily: 'Inter')`).

If your app *does* use Material `Theme`, pull values yourself at the call site:

```dart
final cs = Theme.of(context).colorScheme;
VoiceMessageBubble(
  message: msg,
  style: VoiceBubbleStyle(
    bubbleColor: cs.primaryContainer,
    primaryColor: cs.primary,
    onPrimaryColor: cs.onPrimary,
    waveformUnplayedColor: cs.outlineVariant,
    textColor: cs.onPrimaryContainer,
    subtitleColor: cs.onPrimaryContainer.withAlpha(160),
    errorColor: cs.error,
  ),
);
```

### `VoiceMessage`

```dart
class VoiceMessage {
  final String chatId;        // scopes both audio and waveform caches
  final AudioSource source;   // sealed: LocalAudioSource | RemoteAudioSource
  final Duration duration;
  final Waveform waveform;    // immutable, 0..1 clamped
  final DateTime sentAt;
}

// Factories
VoiceMessage.local(chatId: ..., path: ..., duration: ..., waveform: ...);
VoiceMessage.remote(chatId: ..., url: ..., duration: ..., waveform: ...);
```

`chatId` is required on every message. It does not appear in the rendered UI — it is purely the cache partition key so that `clearChat(chatId)` can wipe everything belonging to a deleted conversation without touching other chats.

`Waveform` is a value object. Pass server-computed bars straight through — the bubble will use them instead of re-extracting on download (saves an FFmpeg pass).

### Clearing a chat's cache

When the user deletes a conversation, evict both caches in one place:

```dart
final deps = AppDependenciesScope.of(context);
await deps.voiceCache.clearChat(chatId);     // deletes voice_cache/<chatId>/
await deps.waveformCache.clearChat(chatId);  // removes "<chatId> *" keys from the JSON map
```

The demo app wires this to the chat AppBar's overflow menu (`⋮ → Chatni o'chirish`).

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

### Bubble state machine (per message)

```
        ┌─ LocalAudioSource ──────────────────────────────▶ Ready
        │
init ───┤
        │                            cache hit
        └─ RemoteAudioSource ────────────────────────────▶ Ready
                  │
                  │ cache miss
                  ▼
                Idle ── tap download ──▶ Downloading ──┬─▶ Ready
                  ▲                          │         │
                  │                          │ cancel  │ error
                  └──────────────────────────┘         ▼
                                                     Error
                                                       │ retry
                                                       ▼
                                                  Downloading
```

`BubbleState` is a sealed class — every state carries the data it needs (e.g. `BubbleDownloading.progress`) and the bubble UI matches with an exhaustive `switch`.

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

`JsonFileWaveformCache` backs `.waveform_cache.json` in the app documents directory. Each entry is keyed by `"<chatId> <key>"` (composite key, space-separated), so wiping a chat is a prefix filter; other chats are untouched. Loaded lazily on first use.

```
send message
    ├─ preview was open → reuse already-extracted data (no FFmpeg call)
    └─ sent directly   → extract now, then cache

open bubble
    ├─ VoiceMessage.waveform already populated   → use directly (server metadata)
    ├─ found in JSON cache                       → use from disk
    └─ not found                                 → extract + cache
```

### Network audio cache (cached_network_image style)

Remote audio uses on-disk caching keyed by a sha1 hash of the URL, partitioned by `chatId` — no JSON index, no SQLite. File existence on disk *is* the cache.

```
<appDocs>/voice_cache/
├── chat-42/
│   ├── a3f5…e91.mp3
│   └── b7c2…d44.m4a
└── chat-99/
    └── …
```

```
tap download
    ├─ cache.getIfCached(url) → file exists? → go straight to Ready
    └─ else → dio.download(url, "<finalPath>.part", onReceiveProgress: …)
              ├─ success → rename .part → finalPath → Ready
              ├─ cancel  → delete .part → Idle
              └─ error   → delete .part → Error (retry)
```

Restarting the app does not lose the cache: `voice_cache/<chatId>/<sha1>.<ext>` survives. The bubble auto-detects this on first build and skips straight to the play state. Deleting a chat removes the entire `voice_cache/<chatId>/` directory in one `recursive: true` call — no per-URL bookkeeping required.

### Module boundaries (ports & adapters)

```
lib/
  domain/                  pure Dart — no Flutter, no I/O
    audio_source.dart        sealed: LocalAudioSource | RemoteAudioSource
    voice_message.dart       VoiceMessage entity + factories
    waveform.dart            value object, clamps to 0..1
    recorder_failure.dart    sealed RecorderFailure hierarchy
    recorder_config.dart     bit rate, sample count, amplitude floor, …
  application/             controllers + abstract ports
    ports.dart                 every dependency surfaced as `abstract interface class`
    recording_controller.dart  ChangeNotifier orchestrating idle/recording/paused/previewing
    preview_playback_controller.dart  AudioPlayer lifecycle for the mid-recording preview
    voice_message_playback_controller.dart  per-bubble: download + play state machine
    playback_coordinator.dart  identity-based "only one speaker at a time"
  infrastructure/          concrete adapters (the only place that touches I/O)
    audio_recorder_record.dart       record package adapter
    audio_concat_ffmpeg.dart         FFmpeg concat demuxer
    waveform_extractor_ffmpeg.dart   FFmpeg → PCM → RMS → Waveform
    waveform_cache_json.dart         on-disk JSON map
    voice_message_cache_fs.dart      voice_cache/<chatId>/sha1(url).<ext>
    voice_message_downloader_dio.dart dio download with progress + cancel
    mic_permission_handler.dart      permission_handler adapter
    voice_paths.dart                 path_provider-backed paths
    ffmpeg_runner.dart               shared FFmpegKit helper (DRY)
  presentation/            Flutter widgets + DI scope
    app_dependencies.dart    AppDependencies + InheritedWidget
    chat_page.dart           demo screen
    voice_recorder_widget.dart  recorder UI (consumes RecordingController)
    voice_message_bubble.dart   chat bubble UI (consumes VoiceMessagePlaybackController)
    widgets/
      recording_timer.dart   mm:ss with tabular figures
      live_amplitude_bar.dart ring-buffer CustomPainter
      waveform_player.dart    waveform + seek CustomPainter
```

The dependency direction is strict: `presentation → application → domain`, and `infrastructure → application → domain`. Nothing in `domain/` imports Flutter or any plugin — the same files compile under pure-Dart unit tests.

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
- **No upload pipeline.** The widget emits a `VoiceMessage` with a local file path; uploading to a backend is intentionally out of scope.
- **In-memory message list.** The demo app stores messages in a `List` — they are lost on restart. The on-disk audio cache and waveform cache *do* survive, so wiring up a local DB (drift, sqflite, isar) for the message list is a small, isolated addition.
- **No size-based eviction.** Per-chat eviction is supported (`clearChat(chatId)`), but there is no LRU sweeper for global cache footprint. Add one if disk usage matters in your app.
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
