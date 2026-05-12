import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../application/ports.dart';

class DioVoiceDownloader implements VoiceMessageDownloaderPort {
  DioVoiceDownloader({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  VoiceMessageDownloadHandle download({
    required String url,
    required String destinationPath,
  }) {
    final controller = StreamController<DownloadEvent>();
    final cancelToken = CancelToken();
    final partPath = '$destinationPath.part';

    Future<void> run() async {
      try {
        await _dio.download(
          url,
          partPath,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            if (controller.isClosed) return;
            controller.add(DownloadProgressEvent(
              DownloadProgress(received: received, total: total),
            ));
          },
        );
        final part = File(partPath);
        if (await part.exists()) {
          await part.rename(destinationPath);
        }
        if (!controller.isClosed) {
          controller.add(DownloadCompleted(destinationPath));
          await controller.close();
        }
      } catch (e) {
        try {
          final part = File(partPath);
          if (await part.exists()) await part.delete();
        } catch (_) {}
        if (controller.isClosed) return;
        if (e is DioException && CancelToken.isCancel(e)) {
          controller.add(const DownloadCancelledEvent());
        } else {
          controller.add(DownloadFailed(e));
        }
        await controller.close();
      }
    }

    unawaited(run());

    return _DioDownloadHandle(
      stream: controller.stream,
      cancelFn: () {
        if (!cancelToken.isCancelled) cancelToken.cancel();
      },
    );
  }
}

class _DioDownloadHandle implements VoiceMessageDownloadHandle {
  _DioDownloadHandle({required Stream<DownloadEvent> stream, required this.cancelFn})
      : events = stream.asBroadcastStream();

  @override
  final Stream<DownloadEvent> events;
  final void Function() cancelFn;

  @override
  void cancel() => cancelFn();
}
