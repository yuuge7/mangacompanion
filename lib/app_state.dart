import 'package:flutter/foundation.dart';

import 'models/manga_entry.dart';
import 'storage.dart';

enum SortMode { recent, title, progress, rating }

class AppState extends ChangeNotifier {
  final MangaStore _store;
  List<MangaEntry> entries;
  SortMode sortMode = SortMode.recent;

  AppState(this._store) : entries = _store.load();

  /// The saved shelf was there but unreadable. Drives the recovery state.
  bool get loadFailed => _store.loadFailed;

  /// Chapters counted across a given slice of the shelf.
  int chaptersIn(List<MangaEntry> list) =>
      list.fold(0, (sum, e) => sum + e.currentChapter);

  Future<void> _persist() async {
    await _store.save(entries);
    notifyListeners();
  }

  int countFor(String status) =>
      entries.where((e) => e.status == status).length;

  List<MangaEntry> visible(String status, String search) {
    final q = search.trim().toLowerCase();
    final list = entries
        .where((e) =>
            e.status == status &&
            (q.isEmpty || e.title.toLowerCase().contains(q)))
        .toList();
    switch (sortMode) {
      case SortMode.recent:
        // Same as the site: reading tab by activity, others by date added.
        if (status == 'reading') {
          list.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        } else {
          list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        }
      case SortMode.title:
        list.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case SortMode.progress:
        list.sort((a, b) => b.progress.compareTo(a.progress));
      case SortMode.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return list;
  }

  void setSort(SortMode mode) {
    sortMode = mode;
    notifyListeners();
  }

  Future<void> add(MangaEntry entry) async {
    entries.insert(0, entry);
    await _persist();
  }

  Future<void> addAll(List<MangaEntry> items) async {
    entries.insertAll(0, items);
    await _persist();
  }

  Future<void> update(MangaEntry entry) async {
    final i = entries.indexWhere((e) => e.id == entry.id);
    if (i >= 0) entries[i] = entry;
    await _persist();
  }

  Future<void> remove(String id) async {
    entries.removeWhere((e) => e.id == id);
    await _persist();
  }

  Future<void> bumpChapter(MangaEntry entry, int dir) async {
    if (dir > 0 && entry.isDone) return;
    if (dir < 0 && entry.currentChapter <= 0) return;
    entry.currentChapter += dir;
    entry.lastUpdated = DateTime.now().millisecondsSinceEpoch;
    await _persist();
  }

  Future<void> setStatus(MangaEntry entry, String status) async {
    entry.status = status;
    entry.lastUpdated = DateTime.now().millisecondsSinceEpoch;
    await _persist();
  }

  Future<void> setRating(MangaEntry entry, int rating) async {
    entry.rating = rating;
    await _persist();
  }

  /// Replace wipes the list first; merge
  /// updates entries with matching id (or same title, so a site export and
  /// local copy of the same manga don't duplicate) and appends the rest.
  Future<int> importEntries(List<MangaEntry> imported,
      {required bool replace}) async {
    if (replace) {
      entries = imported;
      await _persist();
      return imported.length;
    }
    var added = 0;
    for (final inc in imported) {
      final i = entries.indexWhere((e) =>
          e.id == inc.id ||
          e.title.trim().toLowerCase() == inc.title.trim().toLowerCase());
      if (i >= 0) {
        inc.id = entries[i].id;
        entries[i] = inc;
      } else {
        entries.add(inc);
        added++;
      }
    }
    await _persist();
    return added;
  }

  String exportJson() => MangaStore.toExportJson(entries);

  // Stats
  int get totalChaptersRead =>
      entries.fold(0, (sum, e) => sum + e.currentChapter);
  double get averageRating {
    final rated = entries.where((e) => e.status == 'read' && e.rating > 0);
    if (rated.isEmpty) return 0;
    return rated.fold<int>(0, (s, e) => s + e.rating) / rated.length;
  }
}
