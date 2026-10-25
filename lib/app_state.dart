import 'package:flutter/foundation.dart';

import 'models/manga_entry.dart';
import 'storage.dart';

enum SortMode { recent, title, progress, rating }

/// Where a deleted title sat, so undo can put it back in the same place.
typedef RemovedEntry = ({int index, MangaEntry entry});

/// What merging a backup would do, worked out before anything changes so
/// the user can see it first.
class ImportPlan {
  /// Titles not on the shelf yet.
  final List<MangaEntry> added;

  /// Titles on the shelf where the file's copy is newer. Already carry the
  /// shelf's id, so applying them replaces in place.
  final List<MangaEntry> updated;

  /// Titles on the shelf where your copy is newer or the same. Left alone.
  final List<MangaEntry> skipped;

  const ImportPlan({
    required this.added,
    required this.updated,
    required this.skipped,
  });

  bool get changesAnything => added.isNotEmpty || updated.isNotEmpty;
}

class AppState extends ChangeNotifier {
  final MangaStore _store;
  List<MangaEntry> entries;
  SortMode sortMode;

  AppState(this._store)
      : entries = _store.load(),
        sortMode = SortMode.values.asNameMap()[_store.loadSortMode()] ??
            SortMode.recent;

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
        // Reading by activity, read by when it was finished (the status
        // change stamps lastUpdated), dropped by date added.
        if (status != 'dropped') {
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
    _store.saveSortMode(mode.name);
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

  /// Returns where the title was, for [restoreRemoved]. Null if it was
  /// already gone.
  Future<RemovedEntry?> remove(String id) async {
    final i = entries.indexWhere((e) => e.id == id);
    if (i < 0) return null;
    final entry = entries.removeAt(i);
    await _persist();
    return (index: i, entry: entry);
  }

  /// Undo for [remove].
  Future<void> restoreRemoved(RemovedEntry removed) async {
    if (entries.any((e) => e.id == removed.entry.id)) return;
    entries.insert(removed.index.clamp(0, entries.length), removed.entry);
    await _persist();
  }

  /// Deep copy of the shelf, for undoing whole-shelf changes like an import.
  List<MangaEntry> snapshot() => entries.map((e) => e.copy()).toList();

  /// Swaps the whole shelf. Used by Replace imports and by undo.
  Future<void> replaceAll(List<MangaEntry> items) async {
    entries = List.of(items);
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

  int _indexOfMatch(MangaEntry inc) {
    final byId = entries.indexWhere((e) => e.id == inc.id);
    if (byId >= 0) return byId;
    final key = _titleKey(inc.title);
    return entries.indexWhere((e) => _titleKey(e.title) == key);
  }

  static String _titleKey(String title) => title.trim().toLowerCase();

  /// Matches each incoming title to the shelf by id, or by title so a copy
  /// from another app does not duplicate. A match only wins when its
  /// [MangaEntry.lastUpdated] is newer, so an old backup can never roll
  /// your progress back.
  ImportPlan planMerge(List<MangaEntry> imported) {
    // A file can list the same title twice; keep its newest copy.
    final byTitle = <String, MangaEntry>{};
    for (final inc in imported) {
      final key = _titleKey(inc.title);
      final seen = byTitle[key];
      if (seen == null || inc.lastUpdated > seen.lastUpdated) {
        byTitle[key] = inc;
      }
    }

    final added = <MangaEntry>[];
    final updated = <MangaEntry>[];
    final skipped = <MangaEntry>[];
    for (final inc in byTitle.values) {
      final i = _indexOfMatch(inc);
      if (i < 0) {
        added.add(inc.copy());
        continue;
      }
      final mine = entries[i];
      if (inc.lastUpdated <= mine.lastUpdated) {
        skipped.add(inc);
        continue;
      }
      // Other trackers' files carry less than ours (no cover, no rating),
      // so keep what the shelf has wherever the file is blank.
      final next = inc.copy()
        ..id = mine.id
        ..addedAt = inc.addedAt < mine.addedAt ? inc.addedAt : mine.addedAt;
      if (next.coverUrl.isEmpty) next.coverUrl = mine.coverUrl;
      if (next.readUrl.isEmpty) next.readUrl = mine.readUrl;
      next.totalChapters ??= mine.totalChapters;
      if (next.rating == 0) next.rating = mine.rating;
      updated.add(next);
    }
    return ImportPlan(added: added, updated: updated, skipped: skipped);
  }

  Future<void> applyMerge(ImportPlan plan) async {
    for (final next in plan.updated) {
      final i = entries.indexWhere((e) => e.id == next.id);
      if (i >= 0) entries[i] = next;
    }
    entries.addAll(plan.added);
    await _persist();
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
