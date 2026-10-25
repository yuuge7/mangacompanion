import 'dart:math';

import 'models/manga_entry.dart';

/// Reading activity worked out from every title's history.
class ReadingStats {
  final int thisWeek;
  final int thisMonth;
  final int thisYear;

  /// Days in a row, ending today or yesterday, with at least one chapter.
  final int currentStreak;
  final int longestStreak;

  /// Titles finished this calendar year.
  final int finishedThisYear;

  const ReadingStats({
    required this.thisWeek,
    required this.thisMonth,
    required this.thisYear,
    required this.currentStreak,
    required this.longestStreak,
    required this.finishedThisYear,
  });

  bool get isEmpty => thisYear == 0 && longestStreak == 0;
}

/// Turns timestamps into local calendar dates, fast.
///
/// Converting to local time is slow (a time zone lookup each time), and a
/// big shelf has tens of thousands of steps. Time zone offsets only change
/// on 15-minute boundaries, so one lookup per 15-minute slot is exact; the
/// date itself is then plain UTC arithmetic. Dates come back as UTC
/// midnights, which step by calendar day with no DST surprises.
class _LocalDays {
  static const _slot = 15 * 60 * 1000;
  final _offsets = <int, int>{};

  DateTime of(int ms) {
    final slot = ms ~/ _slot;
    final offset = _offsets.putIfAbsent(
        slot,
        () => DateTime.fromMillisecondsSinceEpoch(slot * _slot)
            .timeZoneOffset
            .inMilliseconds);
    final d = DateTime.fromMillisecondsSinceEpoch(ms + offset, isUtc: true);
    return DateTime.utc(d.year, d.month, d.day);
  }
}

DateTime _date(DateTime local) =>
    DateTime.utc(local.year, local.month, local.day);

DateTime _prev(DateTime d) => DateTime.utc(d.year, d.month, d.day - 1);

/// Net chapters per local calendar day (as UTC midnights). Can be zero or
/// negative on a day spent correcting over-counted steps.
Map<DateTime, int> netChaptersByDay(Iterable<MangaEntry> entries) {
  final days = _LocalDays();
  final net = <DateTime, int>{};
  for (final e in entries) {
    for (final ev in e.history) {
      final d = days.of(ev.at);
      net[d] = (net[d] ?? 0) + ev.delta;
    }
  }
  return net;
}

ReadingStats readingStats(Iterable<MangaEntry> entries, {DateTime? now}) {
  final today = _date(now ?? DateTime.now());
  final net = netChaptersByDay(entries);

  final weekStart =
      DateTime.utc(today.year, today.month, today.day - (today.weekday - 1));
  final monthStart = DateTime.utc(today.year, today.month);
  final yearStart = DateTime.utc(today.year);

  // Totals are net, so a step back corrects an earlier over-count.
  var week = 0, month = 0, year = 0;
  for (final MapEntry(key: d, value: n) in net.entries) {
    if (d.isAfter(today)) continue;
    if (!d.isBefore(weekStart)) week += n;
    if (!d.isBefore(monthStart)) month += n;
    if (!d.isBefore(yearStart)) year += n;
  }

  // A streak day is one where you read more than you took back.
  final days = {
    for (final MapEntry(key: d, value: n) in net.entries)
      if (n > 0) d,
  };

  var current = 0;
  var cursor = days.contains(today) ? today : _prev(today);
  while (days.contains(cursor)) {
    current++;
    cursor = _prev(cursor);
  }

  final sorted = days.toList()..sort();
  var longest = 0, run = 0;
  DateTime? last;
  for (final d in sorted) {
    run = (last != null && _prev(d) == last) ? run + 1 : 1;
    longest = max(longest, run);
    last = d;
  }

  final yearStartMs = DateTime(today.year).millisecondsSinceEpoch;
  final finished = entries
      .where((e) =>
          e.status == ShelfStatus.read &&
          e.finishedAt != null &&
          e.finishedAt! >= yearStartMs)
      .length;

  return ReadingStats(
    thisWeek: max(0, week),
    thisMonth: max(0, month),
    thisYear: max(0, year),
    currentStreak: current,
    longestStreak: longest,
    finishedThisYear: finished,
  );
}
