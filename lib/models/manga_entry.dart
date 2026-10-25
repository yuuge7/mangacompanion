import 'dart:math';

import 'package:flutter/foundation.dart';

/// Which shelf a title sits on.
enum ShelfStatus {
  reading('reading', 'Reading', 'READING'),
  onHold('on-hold', 'On hold', 'ON HOLD'),
  planned('planned', 'Plan to read', 'PLANNED'),
  read('read', 'Read', 'READ'),
  dropped('dropped', 'Dropped', 'DROPPED');

  /// Value written to backups. Never change these: old files depend on them.
  final String json;

  /// Name in menus and prose.
  final String label;

  /// Name on the status rail.
  final String rail;

  const ShelfStatus(this.json, this.label, this.rail);

  /// Unknown values (from a newer or foreign file) land on reading.
  static ShelfStatus fromJson(Object? value) {
    for (final s in values) {
      if (s.json == value) return s;
    }
    return reading;
  }

  /// Statuses where the chapter stepper means "I read another one".
  bool get tracksProgress => this != read;
}

/// One change to the chapter you are on: from [from] to [to] at [at].
/// Signed, so stepping back cancels a step forward in the totals.
@immutable
class ReadEvent {
  final int at; // epoch ms
  final int from;
  final int to;

  const ReadEvent({required this.at, required this.from, required this.to});

  int get delta => to - from;

  List<int> toJson() => [at, from, to];

  static ReadEvent? fromJson(Object? v) {
    if (v is! List || v.length < 3) return null;
    final [at, from, to, ...] = v;
    if (at is! num || from is! num || to is! num) return null;
    return ReadEvent(at: at.toInt(), from: from.toInt(), to: to.toInt());
  }

  @override
  bool operator ==(Object other) =>
      other is ReadEvent &&
      other.at == at &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(at, from, to);
}

/// Sentinel so [MangaEntry.copyWith] can tell "leave alone" from "set null".
const Object _keep = Object();

/// One tracked manga. Immutable: every change makes a new copy.
@immutable
class MangaEntry {
  final String id;
  final String title;
  final String coverUrl;
  final String readUrl;
  final int currentChapter;
  final int? totalChapters;
  final ShelfStatus status;
  final int rating; // 0..5
  /// Times the title was started over after finishing it.
  final int rereads;
  final int addedAt; // epoch ms
  final int lastUpdated; // epoch ms
  final int? startedAt; // epoch ms
  final int? finishedAt; // epoch ms
  final List<ReadEvent> history;

  MangaEntry({
    required this.id,
    required this.title,
    this.coverUrl = '',
    this.readUrl = '',
    this.currentChapter = 0,
    this.totalChapters,
    this.status = ShelfStatus.reading,
    this.rating = 0,
    this.rereads = 0,
    required this.addedAt,
    required this.lastUpdated,
    this.startedAt,
    this.finishedAt,
    List<ReadEvent> history = const [],
  }) : history = List.unmodifiable(history);

  bool get isDone =>
      totalChapters != null &&
      totalChapters! > 0 &&
      currentChapter >= totalChapters!;

  double get progress => (totalChapters == null || totalChapters! <= 0)
      ? 0
      : (currentChapter / totalChapters!).clamp(0.0, 1.0);

  MangaEntry copyWith({
    String? id,
    String? title,
    String? coverUrl,
    String? readUrl,
    int? currentChapter,
    Object? totalChapters = _keep,
    ShelfStatus? status,
    int? rating,
    int? rereads,
    int? addedAt,
    int? lastUpdated,
    Object? startedAt = _keep,
    Object? finishedAt = _keep,
    List<ReadEvent>? history,
  }) {
    return MangaEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      readUrl: readUrl ?? this.readUrl,
      currentChapter: currentChapter ?? this.currentChapter,
      totalChapters: identical(totalChapters, _keep)
          ? this.totalChapters
          : totalChapters as int?,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      rereads: rereads ?? this.rereads,
      addedAt: addedAt ?? this.addedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      startedAt:
          identical(startedAt, _keep) ? this.startedAt : startedAt as int?,
      finishedAt:
          identical(finishedAt, _keep) ? this.finishedAt : finishedAt as int?,
      history: history ?? this.history,
    );
  }

  /// Moves to chapter [to] and logs it. Steps close together on the same
  /// day fold into one event, so a binge of twenty chapters is one entry.
  MangaEntry recordProgress(int to, {required int now}) {
    if (to == currentChapter) return this;
    return copyWith(
      currentChapter: to,
      lastUpdated: now,
      startedAt: startedAt ?? (to > currentChapter ? now : null),
      history: appendEvent(
          history, ReadEvent(at: now, from: currentChapter, to: to)),
    );
  }

  /// Puts the title on another shelf, stamping start and finish dates.
  MangaEntry moveTo(ShelfStatus next, {required int now}) {
    if (next == status) return this;
    return copyWith(
      status: next,
      lastUpdated: now,
      startedAt: startedAt ?? (next == ShelfStatus.reading ? now : null),
      finishedAt: next == ShelfStatus.read ? now : finishedAt,
    );
  }

  /// Starts a finished title over from chapter 0.
  MangaEntry startReread({required int now}) => copyWith(
        status: ShelfStatus.reading,
        currentChapter: 0,
        rereads: rereads + 1,
        lastUpdated: now,
      );

  static const _foldWindow = 30 * 60 * 1000;

  /// Appends [e], folding it into the last event when it continues it
  /// within half an hour on the same day. Drops the result if the two
  /// cancel out.
  static List<ReadEvent> appendEvent(List<ReadEvent> history, ReadEvent e) {
    if (history.isNotEmpty) {
      final last = history.last;
      if (last.to == e.from &&
          e.at - last.at < _foldWindow &&
          _sameDay(last.at, e.at)) {
        final merged = ReadEvent(at: e.at, from: last.from, to: e.to);
        return [
          ...history.take(history.length - 1),
          if (merged.from != merged.to) merged,
        ];
      }
    }
    return [...history, e];
  }

  static bool _sameDay(int a, int b) {
    final x = DateTime.fromMillisecondsSinceEpoch(a);
    final y = DateTime.fromMillisecondsSinceEpoch(b);
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  /// Loose key for spotting the same title written two ways:
  /// "Kaguya-sama: Love Is War" and "kaguya sama love is war" match.
  static String titleKey(String title) {
    final lower = title.trim().toLowerCase();
    final key = lower.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
    // A title made only of punctuation would otherwise match every other.
    return key.isEmpty ? lower : key;
  }

  /// Same scheme the site uses: base36 timestamp + random tail.
  static String newId() {
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    final rnd = Random();
    final tail =
        List.generate(10, (_) => chars[rnd.nextInt(chars.length)]).join();
    return '$ts$tail';
  }

  factory MangaEntry.blank() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return MangaEntry(id: newId(), title: '', addedAt: now, lastUpdated: now);
  }

  static int _asInt(Object? v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static int? _asIntOrNull(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Tolerant parse: site data may carry chapter counts as strings and
  /// omit rating/timestamps on old entries.
  factory MangaEntry.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = json['id'];
    final rawHistory = json['history'];
    return MangaEntry(
      id: id is String && id.isNotEmpty ? id : newId(),
      title: json['title'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      readUrl: json['readUrl'] as String? ?? '',
      currentChapter: _asInt(json['currentChapter']),
      totalChapters: _asIntOrNull(json['totalChapters']),
      status: ShelfStatus.fromJson(json['status']),
      rating: _asInt(json['rating']).clamp(0, 5),
      rereads: max(0, _asInt(json['rereads'])),
      addedAt: _asInt(json['addedAt'], now),
      lastUpdated: _asInt(json['lastUpdated'], now),
      startedAt: _asIntOrNull(json['startedAt']),
      finishedAt: _asIntOrNull(json['finishedAt']),
      history: rawHistory is List
          ? rawHistory.map(ReadEvent.fromJson).nonNulls.toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'coverUrl': coverUrl,
        'readUrl': readUrl,
        'currentChapter': currentChapter,
        'totalChapters': totalChapters,
        'status': status.json,
        'rating': rating,
        'rereads': rereads,
        'addedAt': addedAt,
        'lastUpdated': lastUpdated,
        'startedAt': startedAt,
        'finishedAt': finishedAt,
        if (history.isNotEmpty)
          'history': [for (final e in history) e.toJson()],
      };
}
