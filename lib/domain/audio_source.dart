sealed class AudioSource {
  const AudioSource();
}

class LocalAudioSource extends AudioSource {
  const LocalAudioSource(this.path);
  final String path;
}

class RemoteAudioSource extends AudioSource {
  const RemoteAudioSource(this.url);
  final String url;
}
