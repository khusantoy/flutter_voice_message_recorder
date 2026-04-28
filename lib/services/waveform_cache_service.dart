import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class WaveformCacheService {
  WaveformCacheService._();
  static final WaveformCacheService instance = WaveformCacheService._();

  Map<String, List<double>>? _cache;
  File? _file;

  Future<List<double>?> get(String filePath) async {
    await _ensureLoaded();
    return _cache![filePath];
  }

  Future<void> set(String filePath, List<double> data) async {
    await _ensureLoaded();
    _cache![filePath] = data;
    await _persist();
  }

  Future<void> remove(String filePath) async {
    await _ensureLoaded();
    if (_cache!.remove(filePath) != null) await _persist();
  }

  Future<void> _ensureLoaded() async {
    if (_cache != null) return;
    _cache = {};
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/.waveform_cache.json');
      if (await _file!.exists()) {
        final raw = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        _cache = raw.map(
          (k, v) => MapEntry(k, (v as List).map((e) => (e as num).toDouble()).toList()),
        );
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      await _file?.writeAsString(jsonEncode(_cache));
    } catch (_) {}
  }
}
