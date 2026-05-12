import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../application/ports.dart';
import '../domain/waveform.dart';

class JsonFileWaveformCache implements WaveformCachePort {
  JsonFileWaveformCache();

  Map<String, List<double>>? _cache;
  File? _file;

  @override
  Future<Waveform?> get(String key) async {
    await _ensureLoaded();
    final raw = _cache![key];
    return raw == null ? null : Waveform(raw);
  }

  @override
  Future<void> set(String key, Waveform waveform) async {
    await _ensureLoaded();
    _cache![key] = List<double>.from(waveform.samples);
    await _persist();
  }

  @override
  Future<void> remove(String key) async {
    await _ensureLoaded();
    if (_cache!.remove(key) != null) await _persist();
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
          (k, v) => MapEntry(
            k,
            (v as List).map((e) => (e as num).toDouble()).toList(),
          ),
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
