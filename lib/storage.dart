import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/manga_entry.dart';

/// Persists the list as one JSON array string
class MangaStore {
  static const _key = 'manga-entries-v1';

  final SharedPreferences _prefs;
  MangaStore(this._prefs);

  static Future<MangaStore> open() async =>
      MangaStore(await SharedPreferences.getInstance());

  List<MangaEntry> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(MangaEntry.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<MangaEntry> entries) async {
    await _prefs.setString(
        _key, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  /// Returns null when the file is not a JSON array of entries.
  static List<MangaEntry>? parseExport(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final entries = decoded
          .whereType<Map<String, dynamic>>()
          .map(MangaEntry.fromJson)
          .where((e) => e.title.trim().isNotEmpty)
          .toList();
      return entries;
    } catch (_) {
      return null;
    }
  }

  static String toExportJson(List<MangaEntry> entries) =>
      const JsonEncoder.withIndent('  ')
          .convert(entries.map((e) => e.toJson()).toList());
}
