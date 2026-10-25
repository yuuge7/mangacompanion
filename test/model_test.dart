import 'package:flutter_test/flutter_test.dart';
import 'package:manga_companion/csv_export.dart';
import 'package:manga_companion/models/manga_entry.dart';
import 'package:manga_companion/stats.dart';

int at(int y, int m, int d, [int h = 12, int min = 0]) =>
    DateTime(y, m, d, h, min).millisecondsSinceEpoch;

MangaEntry entry({
  String title = 'Berserk',
  ShelfStatus status = ShelfStatus.reading,
  List<ReadEvent> history = const [],
  int? finishedAt,
}) =>
    MangaEntry(
      id: 'x',
      title: title,
      status: status,
      addedAt: 1,
      lastUpdated: 1,
      history: history,
      finishedAt: finishedAt,
    );

void main() {
  group('MangaEntry', () {
    test('copyWith can clear nullable fields and leave others', () {
      final e = MangaEntry(
          id: 'a', title: 'A', totalChapters: 10, addedAt: 1, lastUpdated: 1);
      expect(e.copyWith(title: 'B').totalChapters, 10);
      expect(e.copyWith(totalChapters: null).totalChapters, isNull);
    });

    test('history cannot be changed from outside', () {
      final e = entry(history: [const ReadEvent(at: 1, from: 0, to: 1)]);
      expect(() => e.history.add(const ReadEvent(at: 2, from: 1, to: 2)),
          throwsUnsupportedError);
    });

    test('steps close together on one day fold into one event', () {
      var h = <ReadEvent>[];
      h = MangaEntry.appendEvent(
          h, ReadEvent(at: at(2025, 3, 9, 20), from: 4, to: 5));
      h = MangaEntry.appendEvent(
          h, ReadEvent(at: at(2025, 3, 9, 20, 20), from: 5, to: 6));
      expect(h, [ReadEvent(at: at(2025, 3, 9, 20, 20), from: 4, to: 6)]);
    });

    test('a gap over half an hour, or a new day, starts a new event', () {
      var h = [ReadEvent(at: at(2025, 3, 9, 20), from: 4, to: 5)];
      h = MangaEntry.appendEvent(
          h, ReadEvent(at: at(2025, 3, 9, 21), from: 5, to: 6));
      expect(h.length, 2);
      h = MangaEntry.appendEvent(
          h, ReadEvent(at: at(2025, 3, 9, 23, 50), from: 6, to: 7));
      h = MangaEntry.appendEvent(
          h, ReadEvent(at: at(2025, 3, 10, 0, 5), from: 7, to: 8));
      expect(h.length, 4);
    });

    test('moving shelves stamps start and finish', () {
      final started = entry(status: ShelfStatus.planned)
          .moveTo(ShelfStatus.reading, now: 50);
      expect(started.startedAt, 50);
      final done = started.moveTo(ShelfStatus.read, now: 90);
      expect(done.startedAt, 50);
      expect(done.finishedAt, 90);
      expect(done.lastUpdated, 90);
    });

    test('JSON keeps every field', () {
      final e = MangaEntry(
        id: 'a',
        title: 'A',
        currentChapter: 3,
        status: ShelfStatus.onHold,
        rereads: 2,
        addedAt: 1,
        lastUpdated: 2,
        startedAt: 3,
        finishedAt: 4,
        history: const [ReadEvent(at: 5, from: 2, to: 3)],
      );
      final back = MangaEntry.fromJson(e.toJson());
      expect(back.toJson(), e.toJson());
      expect(back.history, e.history);
    });

    test('bad history items are skipped, not fatal', () {
      final e = MangaEntry.fromJson({
        'title': 'A',
        'history': [
          [1, 0, 1],
          'junk',
          [2, 1],
          [3, 1, 2],
        ],
      });
      expect(e.history.map((h) => h.at), [1, 3]);
    });

    test('titleKey ignores case, spacing and punctuation', () {
      expect(MangaEntry.titleKey('Kaguya-sama: Love Is War'),
          MangaEntry.titleKey(' kaguya sama love is war '));
      expect(MangaEntry.titleKey('進撃の巨人'), '進撃の巨人');
      expect(MangaEntry.titleKey('!!!'), '!!!');
    });
  });

  group('stats', () {
    // Wednesday 12 March 2025.
    final now = DateTime(2025, 3, 12, 18);

    test('counts chapters by week, month and year', () {
      final e = entry(history: [
        ReadEvent(at: at(2024, 12, 31), from: 0, to: 50), // last year
        ReadEvent(at: at(2025, 1, 5), from: 50, to: 60), // this year
        ReadEvent(at: at(2025, 3, 2), from: 60, to: 63), // this month
        ReadEvent(at: at(2025, 3, 10), from: 63, to: 66), // Monday
        ReadEvent(at: at(2025, 3, 12), from: 66, to: 65), // stepped back
      ]);
      final s = readingStats([e], now: now);
      expect(s.thisWeek, 2);
      expect(s.thisMonth, 5);
      expect(s.thisYear, 15);
    });

    test('streaks count calendar days with reading', () {
      final e = entry(history: [
        ReadEvent(at: at(2025, 2, 1), from: 0, to: 1),
        ReadEvent(at: at(2025, 2, 2), from: 1, to: 2),
        ReadEvent(at: at(2025, 2, 3), from: 2, to: 3),
        ReadEvent(at: at(2025, 2, 4), from: 3, to: 4),
        ReadEvent(at: at(2025, 3, 10), from: 4, to: 5),
        ReadEvent(at: at(2025, 3, 11), from: 5, to: 6),
      ]);
      // Nothing yet today: the streak through yesterday still counts.
      final s = readingStats([e], now: now);
      expect(s.currentStreak, 2);
      expect(s.longestStreak, 4);

      expect(readingStats([e], now: DateTime(2025, 3, 14)).currentStreak, 0);
    });

    test('finished this year counts read titles only', () {
      final s = readingStats([
        entry(status: ShelfStatus.read, finishedAt: at(2025, 2, 1)),
        entry(status: ShelfStatus.read, finishedAt: at(2024, 2, 1)),
        entry(finishedAt: at(2025, 2, 1)), // re-reading now
      ], now: now);
      expect(s.finishedThisYear, 1);
    });
  });

  group('CSV', () {
    test('has a header, quotes where needed, and guards formulas', () {
      final csv = toCsv([
        MangaEntry(
          id: 'a',
          title: 'Kaguya-sama: "Love", War',
          currentChapter: 281,
          totalChapters: 281,
          status: ShelfStatus.read,
          rating: 5,
          addedAt: at(2025, 3, 9, 21, 4),
          lastUpdated: at(2025, 3, 9, 21, 4),
        ),
        MangaEntry(
            id: 'b', title: '=HYPERLINK("x")', addedAt: 1, lastUpdated: 1),
      ]);
      final lines = csv.split('\r\n');
      expect(lines[0], '﻿${csvColumns.join(',')}');
      const row =
          '"Kaguya-sama: ""Love"", War",read,281,281,5,0,,,2025-03-09 21:04,2025-03-09 21:04,,';
      expect(lines[1], row);
      expect(lines[2], startsWith('"\'=HYPERLINK(""x"")",reading,0,,'));
      expect(lines.last, '');
    });
  });
}
