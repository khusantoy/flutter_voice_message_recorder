abstract interface class PausableSpeaker {
  void pauseFromCoordinator();
}

class PlaybackCoordinator {
  PausableSpeaker? _active;

  void requestPlay(PausableSpeaker speaker) {
    if (identical(_active, speaker)) return;
    _active?.pauseFromCoordinator();
    _active = speaker;
  }

  void release(PausableSpeaker speaker) {
    if (identical(_active, speaker)) _active = null;
  }
}
