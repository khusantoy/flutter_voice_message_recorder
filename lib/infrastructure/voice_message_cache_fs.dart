import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../application/ports.dart';

class FileSystemVoiceCache implements VoiceMessageCachePort {
  FileSystemVoiceCache();

  Directory? _root;

  Future<Directory> _ensureRoot() async {
    if (_root != null) return _root!;
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/voice_cache');
    if (!await d.exists()) await d.create(recursive: true);
    _root = d;
    return d;
  }

  Future<Directory> _ensureChatDir(String chatId) async {
    final root = await _ensureRoot();
    final d = Directory('${root.path}/${_sanitize(chatId)}');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  String _sanitize(String chatId) =>
      chatId.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');

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
  Future<String> cachedPathFor({
    required String chatId,
    required String url,
  }) async {
    final dir = await _ensureChatDir(chatId);
    final hash = sha1.convert(url.codeUnits).toString();
    return '${dir.path}/$hash.${_extensionFor(url)}';
  }

  @override
  Future<String?> getIfCached({
    required String chatId,
    required String url,
  }) async {
    final p = await cachedPathFor(chatId: chatId, url: url);
    return await File(p).exists() ? p : null;
  }

  @override
  Future<void> remove({
    required String chatId,
    required String url,
  }) async {
    final p = await cachedPathFor(chatId: chatId, url: url);
    final f = File(p);
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  @override
  Future<void> clearChat(String chatId) async {
    final root = await _ensureRoot();
    final d = Directory('${root.path}/${_sanitize(chatId)}');
    if (await d.exists()) {
      try {
        await d.delete(recursive: true);
      } catch (_) {}
    }
  }
}
