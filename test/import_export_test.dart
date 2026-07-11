import 'package:flutter_test/flutter_test.dart';

import 'package:manga_companion/models/manga_entry.dart';
import 'package:manga_companion/storage.dart';

void main() {
  test('parses a full backup export', () {
    const raw = '''
[
  {
    "id": "m1abc2def3",
    "title": "Berserk",
    "coverUrl": "https://example.com/berserk.jpg",
    "readUrl": "https://example.com/read/berserk",
    "currentChapter": 364,
    "totalChapters": 380,
    "status": "reading",
    "rating": 0,
    "addedAt": 1700000000000,
    "lastUpdated": 1710000000000
  },
  {
    "id": "m4ghi5jkl6",
    "title": "Vagabond",
    "coverUrl": "",
    "readUrl": "",
    "currentChapter": 327,
    "totalChapters": null,
    "status": "read",
    "rating": 5,
    "addedAt": 1690000000000,
    "lastUpdated": 1695000000000
  }
]
''';
    final entries = MangaStore.parseExport(raw);
    expect(entries, isNotNull);
    expect(entries!.length, 2);
    expect(entries[0].title, 'Berserk');
    expect(entries[0].currentChapter, 364);
    expect(entries[0].totalChapters, 380);
    expect(entries[1].totalChapters, isNull);
    expect(entries[1].status, 'read');
    expect(entries[1].rating, 5);
  });

  test('tolerates string chapter numbers and missing fields', () {
    const raw = '''
[{"id":"x","title":"One Piece","currentChapter":"1100","status":"reading"}]
''';
    final entries = MangaStore.parseExport(raw)!;
    expect(entries.single.currentChapter, 1100);
    expect(entries.single.totalChapters, isNull);
    expect(entries.single.rating, 0);
  });

  test('rejects non-array payloads', () {
    expect(MangaStore.parseExport('{"not":"a list"}'), isNull);
    expect(MangaStore.parseExport('garbage'), isNull);
  });

  test('round-trips through export JSON unchanged', () {
    final e = MangaEntry(
      id: 'abc',
      title: 'Vinland Saga',
      coverUrl: 'https://x/y.png',
      readUrl: 'https://x/read',
      currentChapter: 200,
      totalChapters: 220,
      status: 'reading',
      rating: 4,
      addedAt: 1,
      lastUpdated: 2,
    );
    final json = MangaStore.toExportJson([e]);
    final back = MangaStore.parseExport(json)!.single;
    expect(back.toJson(), e.toJson());
  });
}
