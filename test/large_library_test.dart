import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manga_companion/app_state.dart';
import 'package:manga_companion/csv_export.dart';
import 'package:manga_companion/models/manga_entry.dart';
import 'package:manga_companion/screens/home_screen.dart';
import 'package:manga_companion/stats.dart';
import 'package:manga_companion/storage.dart';
import 'package:manga_companion/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 5,000 titles with ten logged steps each: well past any real shelf.
const titles = 5000;
const stepsEach = 10;

/// Budget per operation. Generous: tests run unoptimised (JIT, asserts on)
/// and CI machines are slow. A real regression, like going quadratic,
/// blows through this by orders of magnitude.
const budget = Duration(seconds: 2);

List<MangaEntry> library() {
  final base = DateTime(2025).millisecondsSinceEpoch;
  const day = 86400000;
  return List.generate(titles, (i) {
    final start = base + i * 3600000;
    return MangaEntry(
      id: 'id-$i',
      title: 'Title number $i ${i.isEven ? 'Saga' : 'Chronicles'}',
      coverUrl: i % 3 == 0 ? '' : 'https://example.com/$i.jpg',
      readUrl: 'https://example.com/read/$i',
      currentChapter: stepsEach * 3,
      totalChapters: i % 4 == 0 ? null : 200,
      status: ShelfStatus.values[i % ShelfStatus.values.length],
      rating: i % 6,
      addedAt: start,
      lastUpdated: start + stepsEach * day,
      history: [
        for (var s = 0; s < stepsEach; s++)
          ReadEvent(at: start + s * day, from: s * 3, to: s * 3 + 3),
      ],
    );
  });
}

final timings = <String, Duration>{};

T timed<T>(String label, T Function() run) {
  final sw = Stopwatch()..start();
  final result = run();
  sw.stop();
  timings[label] = sw.elapsed;
  expect(sw.elapsed, lessThan(budget), reason: '$label took ${sw.elapsed}');
  return result;
}

Future<T> timedAsync<T>(String label, Future<T> Function() run) async {
  final sw = Stopwatch()..start();
  final result = await run();
  sw.stop();
  timings[label] = sw.elapsed;
  expect(sw.elapsed, lessThan(budget), reason: '$label took ${sw.elapsed}');
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<MangaEntry> shelf;
  late AppState state;

  setUpAll(() async {
    shelf = library();
    SharedPreferences.setMockInitialValues({});
    final store = await MangaStore.open();
    await timedAsync('save $titles titles', () => store.save(shelf));
    state = timed('load', () => AppState(store));
  });

  tearDownAll(() {
    for (final MapEntry(:key, :value) in timings.entries) {
      debugPrint('${key.padRight(28)} ${value.inMilliseconds} ms');
    }
  });

  test('loads everything back', () {
    expect(state.entries.length, titles);
    expect(state.entries.last.history.length, stepsEach);
  });

  test('filters, sorts and searches', () {
    for (final mode in SortMode.values) {
      state.setSort(mode);
      timed('sort by ${mode.name}',
          () => state.visible(ShelfStatus.reading, ''));
    }
    final hits =
        timed('search', () => state.visible(ShelfStatus.read, 'number 49'));
    expect(hits, isNotEmpty);
    timed('duplicate check', () => state.findDuplicate('title number 4999'));
  });

  test('logs a chapter and saves', () async {
    await timedAsync('bump + save', () => state.bumpChapter('id-0', 1));
    expect(state.byId('id-0')!.currentChapter, stepsEach * 3 + 1);
  });

  test('stats over every logged step', () {
    final s = timed('reading stats',
        () => readingStats(state.entries, now: DateTime(2025, 12, 31)));
    expect(s.thisYear, greaterThan(0));
  });

  test('exports and re-imports', () {
    final json = timed('export JSON', state.exportJson);
    final back = timed('parse JSON', () => MangaStore.parseExport(json)!);
    expect(back.length, titles);
    final csv = timed('export CSV', () => toCsv(state.entries));
    expect('\r\n'.allMatches(csv).length, titles + 1);
  });

  test('merging a full backup into a full shelf stays linear', () {
    final incoming = [
      for (final e in state.entries)
        e.copyWith(id: 'other-${e.id}', lastUpdated: e.lastUpdated + 1),
    ];
    final plan = timed('plan merge', () => state.planMerge(incoming));
    expect(plan.updated.length, titles);
    expect(plan.added, isEmpty);
  });

  testWidgets('the shelf scrolls and searches smoothly', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: HomeScreen(state: state),
    ));
    await tester.pump();

    final list = find.byType(Scrollable).last;
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      await tester.fling(list, const Offset(0, -3000), 5000);
      await tester.pumpAndSettle();
    }
    sw.stop();
    timings['10 flings (debug build)'] = sw.elapsed;
    // Rows are built lazily: per-frame cost here matches a 50-title shelf.
    // Debug-mode frames run many times slower than a release build.
    expect(sw.elapsed, lessThan(budget * 15));

    await tester.tap(find.byTooltip('Search your shelf'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'number 4');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
