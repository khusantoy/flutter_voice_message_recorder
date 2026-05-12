import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../application/ports.dart';

class FileSystemVoiceCache implements VoiceMessageCachePort {
  FileSystemVoiceCache();

  Directory? _dir;

  Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/voice_cache');
    if (!await d.exists()) await d.create(recursive: true);
    _dir = d;
    return d;
  }

  String _extensionFor(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? '';
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return 'm4a';
    final ext = path.substring(dot + 1).toLowerCase();
    if (ext.length > 5 || !RegExp(r'^[a-z0-9]+$').hasMatch(ext)) return 'm4a';
    return ext;
  }

  @override
  Future<String> cachedPathFor(String url) async {
    final dir = await _ensureDir();
    final hash = sha1.convert(url.codeUnits).toString();
    return '${dir.path}/$hash.${_extensionFor(url)}';
  }

  @override
  Future<String?> getIfCached(String url) async {
    final p = await cachedPathFor(url);
    return await File(p).exists() ? p : null;
  }

  @override
  Future<void> remove(String url) async {
    final p = await cachedPathFor(url);
    final f = File(p);
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }
}
