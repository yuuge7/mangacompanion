import 'package:flutter_test/flutter_test.dart';
import 'package:manga_companion/app_state.dart';
import 'package:manga_companion/models/manga_entry.dart';
import 'package:manga_companion/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

MangaEntry entry(
  String title, {
  String? id,
  int chapter = 0,
  int? total,
  int updated = 1000,
  String cover = '',
  int rating = 0,
  ShelfStatus status = ShelfStatus.reading,
  List<ReadEvent> history = const [],
}) =>
    MangaEntry(
      id: id ?? 'id-$title',
      title: title,
      coverUrl: cover,
      currentChapter: chapter,
      totalChapters: total,
      rating: rating,
      status: status,
      addedAt: 1,
      lastUpdated: updated,
      history: history,
    );

Future<AppState> stateWith(List<MangaEntry> items) async {
  SharedPreferences.setMockInitialValues({});
  final store = await MangaStore.open();
  await store.save(items);
  return AppState(store);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('merge', () {
    test('an older copy never rolls progress back', () async {
      final state =
          await stateWith([entry('Berserk', chapter: 364, updated: 2000)]);
      final plan = state.planMerge(
          [entry('Berserk', id: 'other', chapter: 300)]);

      expect(plan.skipped.single.title, 'Berserk');
      expect(plan.updated, isEmpty);
      expect(plan.changesAnything, isFalse);

      await state.applyMerge(plan);
      expect(state.entries.single.currentChapter, 364);
    });

    test('the same backup twice changes nothing', () async {
      final state = await stateWith([entry('Berserk', updated: 2000)]);
      final plan = state.planMerge([entry('Berserk', updated: 2000)]);
      expect(plan.changesAnything, isFalse);
    });

    test('a newer copy updates in place and keeps what it lacks', () async {
      final history = [const ReadEvent(at: 900, from: 299, to: 300)];
      final state = await stateWith([
        entry('Berserk',
            chapter: 300,
            cover: 'https://c',
            rating: 4,
            history: history),
      ]);
      // Matched by title, loosely, from another app's file.
      final plan = state.planMerge(
          [entry('  BERSERK! ', id: 'mal-1', chapter: 364, updated: 2000)]);
      await state.applyMerge(plan);

      final e = state.entries.single;
      expect(e.id, 'id-Berserk');
      expect(e.currentChapter, 364);
      expect(e.coverUrl, 'https://c');
      expect(e.rating, 4);
      expect(e.history, history);
    });

    test('new titles are added, duplicates in the file collapse', () async {
      final state = await stateWith([entry('Berserk')]);
      final plan = state.planMerge([
        entry('Vagabond', id: 'a', chapter: 10, updated: 1),
        entry('Vagabond', id: 'b', chapter: 20, updated: 5),
      ]);
      expect(plan.added.single.currentChapter, 20);

      await state.applyMerge(plan);
      expect(state.entries.map((e) => e.title), ['Berserk', 'Vagabond']);
    });

    test('import can be undone with a snapshot', () async {
      final state = await stateWith([entry('Berserk', chapter: 1)]);
      final before = state.snapshot();
      await state.replaceAll([entry('Monster')]);
      expect(state.entries.single.title, 'Monster');

      await state.replaceAll(before);
      expect(state.entries.single.title, 'Berserk');
      expect(state.entries.single.currentChapter, 1);
    });
  });

  group('progress', () {
    test('a step is logged in history', () async {
      final state = await stateWith([entry('A', chapter: 4)]);
      await state.bumpChapter('id-A', 1);
      final e = state.entries.single;
      expect(e.currentChapter, 5);
      expect(e.history.single.from, 4);
      expect(e.history.single.to, 5);
      expect(e.startedAt, isNotNull);
    });

    test('quick steps fold into one event, and a step back cancels',
        () async {
      final state = await stateWith([entry('A', chapter: 4)]);
      await state.bumpChapter('id-A', 1);
      await state.bumpChapter('id-A', 1);
      expect(state.entries.single.history.single.delta, 2);

      await state.bumpChapter('id-A', -1);
      await state.bumpChapter('id-A', -1);
      expect(state.entries.single.history, isEmpty);
    });

    test('stops at the last chapter and at zero', () async {
      final state = await stateWith([
        entry('Done', chapter: 10, total: 10),
        entry('Zero'),
      ]);
      expect(await state.bumpChapter('id-Done', 1), isNull);
      expect(await state.bumpChapter('id-Zero', -1), isNull);
    });

    test('logging a chapter on a planned title starts it', () async {
      final state =
          await stateWith([entry('A', status: ShelfStatus.planned)]);
      final before = await state.bumpChapter('id-A', 1);
      expect(before!.status, ShelfStatus.planned);
      expect(state.entries.single.status, ShelfStatus.reading);
    });

    test('finishing stamps a date; reading again counts a re-read',
        () async {
      final state = await stateWith([entry('A', chapter: 10, total: 10)]);
      await state.setStatus('id-A', ShelfStatus.read);
      expect(state.entries.single.finishedAt, isNotNull);

      await state.startReread('id-A');
      final e = state.entries.single;
      expect(e.status, ShelfStatus.reading);
      expect(e.currentChapter, 0);
      expect(e.rereads, 1);
    });
  });

  group('undo', () {
    test('a deleted title comes back in the same place', () async {
      final state = await stateWith([entry('A'), entry('B'), entry('C')]);
      final removed = await state.remove('id-B');
      expect(state.entries.map((e) => e.title), ['A', 'C']);

      await state.restoreRemoved(removed!);
      expect(state.entries.map((e) => e.title), ['A', 'B', 'C']);
    });

    test('restoring twice does not duplicate', () async {
      final state = await stateWith([entry('A')]);
      final removed = await state.remove('id-A');
      await state.restoreRemoved(removed!);
      await state.restoreRemoved(removed);
      expect(state.entries.length, 1);
    });

    test('a status change reverts to the entry as it was', () async {
      final state = await stateWith([entry('A')]);
      final before = await state.setStatus('id-A', ShelfStatus.dropped);

      await state.update(before!);
      expect(state.entries.single.status, ShelfStatus.reading);
      expect(state.entries.single.lastUpdated, 1000);
    });
  });

  group('bulk', () {
    test('moves and deletes many at once', () async {
      final state = await stateWith([entry('A'), entry('B'), entry('C')]);
      await state.setStatusMany({'id-A', 'id-C'}, ShelfStatus.onHold);
      expect(state.countFor(ShelfStatus.onHold), 2);
      expect(state.byId('id-B')!.status, ShelfStatus.reading);

      final before = state.snapshot();
      await state.removeMany({'id-A', 'id-B'});
      expect(state.entries.map((e) => e.title), ['C']);

      await state.replaceAll(before);
      expect(state.entries.length, 3);
    });
  });

  test('spots duplicates written loosely, but not the title itself',
      () async {
    final state = await stateWith([entry('Kaguya-sama: Love Is War')]);
    expect(state.findDuplicate('kaguya sama love is war'), isNotNull);
    expect(
        state.findDuplicate('Kaguya-sama: Love Is War',
            exceptId: 'id-Kaguya-sama: Love Is War'),
        isNull);
    expect(state.findDuplicate('Kaguya'), isNull);
    expect(state.findDuplicate('   '), isNull);
  });

  test('planned and dropped shelves sort by date added', () async {
    final state = await stateWith([
      entry('Old', status: ShelfStatus.planned, updated: 5)
          .copyWith(addedAt: 1),
      entry('New', status: ShelfStatus.planned, updated: 1)
          .copyWith(addedAt: 9),
    ]);
    expect(state.visible(ShelfStatus.planned, '').map((e) => e.title),
        ['New', 'Old']);
  });

  test('sort mode survives a restart', () async {
    final state = await stateWith([]);
    state.setSort(SortMode.rating);

    final reopened = AppState(await MangaStore.open());
    expect(reopened.sortMode, SortMode.rating);
  });

  test('reload picks up changes written outside the app', () async {
    final state = await stateWith([entry('A')]);
    final other = await MangaStore.open();
    await other.save([entry('A', chapter: 9)]);

    await state.reloadFromDisk();
    expect(state.entries.single.currentChapter, 9);
  });
}
