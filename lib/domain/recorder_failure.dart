sealed class RecorderFailure {
  const RecorderFailure();
}

class PermissionDenied extends RecorderFailure {
  const PermissionDenied();
}

class PermissionBlocked extends RecorderFailure {
  const PermissionBlocked();
}

class EncodingFailed extends RecorderFailure {
  const EncodingFailed(this.detail);
  final String detail;
}

class StorageError extends RecorderFailure {
  const StorageError(this.detail);
  final String detail;
}

class UnknownRecorderFailure extends RecorderFailure {
  const UnknownRecorderFailure(this.detail);
  final String detail;
}
