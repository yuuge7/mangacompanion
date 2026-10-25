import 'dart:async';
import 'dart:collection';

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

int _now() => DateTime.now().millisecondsSinceEpoch;

class AppState extends ChangeNotifier {
  final MangaStore _store;

  /// Called after every save, e.g. to refresh the home screen widget.
  final VoidCallback? onSaved;

  List<MangaEntry> _entries;
  SortMode sortMode;

  AppState(this._store, {this.onSaved})
      : _entries = _store.load(),
        sortMode = SortMode.values.asNameMap()[_store.loadSortMode()] ??
            SortMode.recent;

  /// Read-only view, not a copy: cheap to read often. Take [snapshot] to
  /// keep the shelf as it is now.
  List<MangaEntry> get entries => UnmodifiableListView(_entries);

  /// The saved shelf was there but unreadable. Drives the recovery state.
  bool get loadFailed => _store.loadFailed;

  Future<void> _persist() async {
    await _store.save(_entries);
    notifyListeners();
    onSaved?.call();
  }

  /// Picks up changes written outside the app, e.g. by the home screen
  /// widget.
  Future<void> reloadFromDisk() async {
    _entries = await _store.reload();
    notifyListeners();
  }

  MangaEntry? byId(String id) {
    for (final e in _entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<void> _replace(MangaEntry next) async {
    final i = _entries.indexWhere((e) => e.id == next.id);
    if (i < 0) return;
    _entries[i] = next;
    await _persist();
  }

  // ------------------------------------------------------------- queries

  int countFor(ShelfStatus status) =>
      _entries.where((e) => e.status == status).length;

  /// Chapters counted across a given slice of the shelf.
  int chaptersIn(List<MangaEntry> list) =>
      list.fold(0, (sum, e) => sum + e.currentChapter);

  List<MangaEntry> visible(ShelfStatus status, String search) {
    final q = search.trim().toLowerCase();
    final list = _entries
        .where((e) =>
            e.status == status &&
            (q.isEmpty || e.title.toLowerCase().contains(q)))
        .toList();
    switch (sortMode) {
      case SortMode.recent:
        // By activity, except shelves of things not being read, which go
        // by when they were added.
        if (status == ShelfStatus.dropped || status == ShelfStatus.planned) {
          list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        } else {
          list.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
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

  /// A title already on the shelf under the same name, written loosely
  /// ("Kaguya-sama: Love Is War" matches "kaguya sama love is war").
  MangaEntry? findDuplicate(String title, {String? exceptId}) {
    final key = MangaEntry.titleKey(title);
    if (key.isEmpty) return null;
    for (final e in _entries) {
      if (e.id != exceptId && MangaEntry.titleKey(e.title) == key) return e;
    }
    return null;
  }

  void setSort(SortMode mode) {
    sortMode = mode;
    notifyListeners();
    unawaited(_store.saveSortMode(mode.name));
  }

  // ------------------------------------------------------------- changes

  Future<void> add(MangaEntry entry) async {
    _entries.insert(0, entry);
    await _persist();
  }

  Future<void> update(MangaEntry entry) => _replace(entry);

  /// Returns where the title was, for [restoreRemoved]. Null if it was
  /// already gone.
  Future<RemovedEntry?> remove(String id) async {
    final i = _entries.indexWhere((e) => e.id == id);
    if (i < 0) return null;
    final entry = _entries.removeAt(i);
    await _persist();
    return (index: i, entry: entry);
  }

  /// Undo for [remove].
  Future<void> restoreRemoved(RemovedEntry removed) async {
    if (_entries.any((e) => e.id == removed.entry.id)) return;
    _entries.insert(removed.index.clamp(0, _entries.length), removed.entry);
    await _persist();
  }

  /// Steps the chapter by [dir] and logs it. Stepping forward on a title
  /// that is planned or on hold puts it back on reading. Returns the entry
  /// as it was, or null when nothing changed.
  Future<MangaEntry?> bumpChapter(String id, int dir) async {
    final before = byId(id);
    if (before == null) return null;
    if (dir > 0 && before.isDone) return null;
    if (dir < 0 && before.currentChapter <= 0) return null;
    final now = _now();
    var next = before.recordProgress(before.currentChapter + dir, now: now);
    if (dir > 0 &&
        (next.status == ShelfStatus.planned ||
            next.status == ShelfStatus.onHold)) {
      next = next.moveTo(ShelfStatus.reading, now: now);
    }
    await _replace(next);
    return before;
  }

  /// Returns the entry as it was, for undo.
  Future<MangaEntry?> setStatus(String id, ShelfStatus status) async {
    final before = byId(id);
    if (before == null || before.status == status) return null;
    await _replace(before.moveTo(status, now: _now()));
    return before;
  }

  Future<void> setRating(String id, int rating) async {
    final e = byId(id);
    if (e != null) await _replace(e.copyWith(rating: rating));
  }

  /// Starts a finished title over. Returns the entry as it was, for undo.
  Future<MangaEntry?> startReread(String id) async {
    final before = byId(id);
    if (before == null) return null;
    await _replace(before.startReread(now: _now()));
    return before;
  }

  /// Whole shelf as it is now, for undoing changes to many titles.
  /// Entries are immutable, so a shallow copy is enough.
  List<MangaEntry> snapshot() => List.of(_entries);

  /// Swaps the whole shelf. Used by Replace imports and by undo.
  Future<void> replaceAll(List<MangaEntry> items) async {
    _entries = List.of(items);
    await _persist();
  }

  Future<void> setStatusMany(Set<String> ids, ShelfStatus status) async {
    final now = _now();
    _entries = [
      for (final e in _entries)
        ids.contains(e.id) ? e.moveTo(status, now: now) : e,
    ];
    await _persist();
  }

  Future<void> removeMany(Set<String> ids) async {
    _entries = _entries.where((e) => !ids.contains(e.id)).toList();
    await _persist();
  }

  // -------------------------------------------------------------- import

  /// Matches each incoming title to the shelf by id, or by title so a copy
  /// from another app does not duplicate. A match only wins when its
  /// [MangaEntry.lastUpdated] is newer, so an old backup can never roll
  /// your progress back.
  ImportPlan planMerge(List<MangaEntry> imported) {
    // A file can list the same title twice; keep its newest copy.
    final byTitle = <String, MangaEntry>{};
    for (final inc in imported) {
      final key = MangaEntry.titleKey(inc.title);
      final seen = byTitle[key];
      if (seen == null || inc.lastUpdated > seen.lastUpdated) {
        byTitle[key] = inc;
      }
    }

    // Indexed once, so a big file against a big shelf stays linear.
    final mineById = {for (final e in _entries) e.id: e};
    final mineByKey = <String, MangaEntry>{};
    for (final e in _entries) {
      mineByKey.putIfAbsent(MangaEntry.titleKey(e.title), () => e);
    }

    final added = <MangaEntry>[];
    final updated = <MangaEntry>[];
    final skipped = <MangaEntry>[];
    for (final MapEntry(key: key, value: inc) in byTitle.entries) {
      final mine = mineById[inc.id] ?? mineByKey[key];
      if (mine == null) {
        added.add(inc);
        continue;
      }
      if (inc.lastUpdated <= mine.lastUpdated) {
        skipped.add(inc);
        continue;
      }
      // Other trackers' files carry less than ours (no cover, no rating,
      // no history), so keep what the shelf has wherever the file is blank.
      updated.add(inc.copyWith(
        id: mine.id,
        addedAt: inc.addedAt < mine.addedAt ? inc.addedAt : mine.addedAt,
        coverUrl: inc.coverUrl.isEmpty ? mine.coverUrl : null,
        readUrl: inc.readUrl.isEmpty ? mine.readUrl : null,
        totalChapters: inc.totalChapters ?? mine.totalChapters,
        rating: inc.rating == 0 ? mine.rating : null,
        rereads: inc.rereads == 0 ? mine.rereads : null,
        startedAt: inc.startedAt ?? mine.startedAt,
        finishedAt: inc.finishedAt ?? mine.finishedAt,
        history: inc.history.isEmpty ? mine.history : null,
      ));
    }
    return ImportPlan(added: added, updated: updated, skipped: skipped);
  }

  Future<void> applyMerge(ImportPlan plan) async {
    for (final next in plan.updated) {
      final i = _entries.indexWhere((e) => e.id == next.id);
      if (i >= 0) _entries[i] = next;
    }
    _entries.addAll(plan.added);
    await _persist();
  }

  String exportJson() => MangaStore.toExportJson(_entries);

  // --------------------------------------------------------------- stats

  int get totalChaptersRead =>
      _entries.fold(0, (sum, e) => sum + e.currentChapter);

  double get averageRating {
    final rated =
        _entries.where((e) => e.status == ShelfStatus.read && e.rating > 0);
    if (rated.isEmpty) return 0;
    return rated.fold<int>(0, (s, e) => s + e.rating) / rated.length;
  }
}
