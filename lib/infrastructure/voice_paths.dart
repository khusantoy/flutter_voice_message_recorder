import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../application/ports.dart';

class AppDocsVoicePaths implements VoicePathsPort {
  AppDocsVoicePaths();

  @override
  Future<String> newSegmentPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/voice_seg_${DateTime.now().microsecondsSinceEpoch}.m4a';
  }

  @override
  Future<String> previewPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/voice_preview.m4a';
  }

  @override
  Future<String> newFinalPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/voice_final_${DateTime.now().microsecondsSinceEpoch}.m4a';
  }
}

Future<void> safeDeleteFile(String path) async {
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}
