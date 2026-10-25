import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:manga_companion/importers.dart';

/// Tiny protobuf writer, the mirror of the reader under test.
class Pb {
  final _b = BytesBuilder();

  void _varint(int v) {
    while ((v & ~0x7f) != 0) {
      _b.addByte((v & 0x7f) | 0x80);
      v = v >>> 7;
    }
    _b.addByte(v);
  }

  void _tag(int field, int wire) => _varint((field << 3) | wire);

  void int64(int field, int v) {
    _tag(field, 0);
    _varint(v);
  }

  void boolean(int field, bool v) => int64(field, v ? 1 : 0);

  void bytes(int field, List<int> v) {
    _tag(field, 2);
    _varint(v.length);
    _b.add(v);
  }

  void string(int field, String v) => bytes(field, utf8.encode(v));

  void message(int field, Pb m) => bytes(field, m.toBytes());

  void float32(int field, double v) {
    _tag(field, 5);
    _b.add((ByteData(4)..setFloat32(0, v, Endian.little))
        .buffer
        .asUint8List());
  }

  Uint8List toBytes() => _b.toBytes();
}

Pb chapter(double number, {required bool read}) => Pb()
  ..string(1, '/ch/$number')
  ..string(2, 'Chapter $number')
  ..boolean(4, read)
  ..float32(9, number);

Uint8List bytesOf(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('Mihon', () {
    Uint8List backup() {
      final berserk = Pb()
        ..int64(1, 12345) // source id
        ..string(2, '/manga/berserk')
        ..string(3, 'Berserk')
        ..string(7, 'Action') // genre, ignored
        ..int64(8, 1) // ongoing
        ..string(9, 'https://x/berserk.jpg')
        ..int64(13, 1700000000000)
        ..message(16, chapter(1, read: true))
        ..message(16, chapter(2, read: true))
        ..message(16, chapter(3, read: false))
        ..int64(17, 1) // category, ignored
        ..message(
            18,
            Pb()
              ..int64(1, 2)
              ..string(4, 'https://anilist.co/manga/30002')
              ..float32(6, 2)
              ..int64(7, 0))
        ..boolean(100, true)
        ..message(
            104,
            Pb()
              ..string(1, '/ch/2')
              ..int64(2, 1710000000000));

      final notInLibrary = Pb()
        ..string(3, 'Browsed once')
        ..boolean(100, false);

      final monster = Pb()
        ..string(2, '/manga/monster')
        ..string(3, 'Monster')
        ..int64(8, 2); // completed
      for (var i = 1; i <= 10; i++) {
        monster.message(16, chapter(i.toDouble(), read: true));
      }
      monster.int64(107, 1710000000); // seconds

      final root = Pb()
        ..message(1, berserk)
        ..message(1, notInLibrary)
        ..message(1, monster)
        ..message(
            101,
            Pb()
              ..string(1, 'Some source')
              ..int64(2, 12345));
      return Uint8List.fromList(gzip.encode(root.toBytes()));
    }

    test('reads library titles from a gzipped backup', () {
      final parsed = parseBackupFile(backup())!;
      expect(parsed.source, BackupSource.mihon);
      expect(parsed.entries.map((e) => e.title), ['Berserk', 'Monster']);

      final berserk = parsed.entries[0];
      expect(berserk.currentChapter, 2);
      expect(berserk.totalChapters, isNull);
      expect(berserk.status, 'reading');
      expect(berserk.coverUrl, 'https://x/berserk.jpg');
      // Relative source link swapped for the tracker page.
      expect(berserk.readUrl, 'https://anilist.co/manga/30002');
      expect(berserk.addedAt, 1700000000000);
      expect(berserk.lastUpdated, 1710000000000);

      final monster = parsed.entries[1];
      expect(monster.currentChapter, 10);
      expect(monster.totalChapters, 10);
      expect(monster.status, 'read');
      expect(monster.lastUpdated, 1710000000000);
    });

    test('rejects random bytes', () {
      expect(parseBackupFile(Uint8List.fromList([0xff, 0x00, 0x13, 0x37])),
          isNull);
    });
  });

  group('MyAnimeList', () {
    const xml = '''<?xml version="1.0" encoding="UTF-8" ?>
<myanimelist>
  <myinfo><user_export_type>2</user_export_type></myinfo>
  <manga>
    <manga_mangadb_id>2</manga_mangadb_id>
    <manga_title><![CDATA[Berserk]]></manga_title>
    <manga_chapters>0</manga_chapters>
    <my_read_chapters>364</my_read_chapters>
    <my_start_date>2019-03-00</my_start_date>
    <my_finish_date>0000-00-00</my_finish_date>
    <my_score>9</my_score>
    <my_status>Reading</my_status>
  </manga>
  <manga>
    <manga_mangadb_id>1</manga_mangadb_id>
    <manga_title>Monster &amp; Friends</manga_title>
    <manga_chapters>162</manga_chapters>
    <my_read_chapters>162</my_read_chapters>
    <my_start_date>0000-00-00</my_start_date>
    <my_finish_date>2021-05-01</my_finish_date>
    <my_score>10</my_score>
    <my_status>Completed</my_status>
  </manga>
  <manga>
    <manga_mangadb_id>3</manga_mangadb_id>
    <manga_title><![CDATA[Gave Up]]></manga_title>
    <manga_chapters>0</manga_chapters>
    <my_read_chapters>4</my_read_chapters>
    <my_score>0</my_score>
    <my_status>Dropped</my_status>
  </manga>
</myanimelist>''';

    test('reads a manga list export', () {
      final parsed = parseBackupFile(bytesOf(xml))!;
      expect(parsed.source, BackupSource.myAnimeList);
      final [berserk, monster, dropped] = parsed.entries;

      expect(berserk.title, 'Berserk');
      expect(berserk.currentChapter, 364);
      expect(berserk.totalChapters, isNull);
      expect(berserk.rating, 5);
      expect(berserk.readUrl, 'https://myanimelist.net/manga/2');
      expect(berserk.addedAt, DateTime(2019, 3, 1).millisecondsSinceEpoch);

      expect(monster.title, 'Monster & Friends');
      expect(monster.status, 'read');
      expect(monster.totalChapters, 162);
      expect(monster.lastUpdated,
          DateTime(2021, 5, 1).millisecondsSinceEpoch);

      expect(dropped.status, 'dropped');
      expect(dropped.rating, 0);
    });

    test('works gzipped, as MAL serves it', () {
      final parsed =
          parseBackupFile(Uint8List.fromList(gzip.encode(utf8.encode(xml))))!;
      expect(parsed.entries.length, 3);
    });

    test('an anime export has no manga', () {
      final parsed = parseBackupFile(bytesOf(
          '<myanimelist><anime><series_title>X</series_title></anime>'
          '</myanimelist>'))!;
      expect(parsed.entries, isEmpty);
    });
  });

  group('Anime-Planet', () {
    const json = '''
{
  "user": {"name": "someone"},
  "export": {"version": "1.0"},
  "entries": [
    {"name": "Berserk", "status": "reading", "started": "2020-01-15 00:00:00",
     "completed": null, "rating": 4.5, "times": 0, "vol": 0, "ch": 300},
    {"name": "Monster", "status": "read", "started": null,
     "completed": "2021-05-01 00:00:00", "rating": 5, "times": 1, "vol": 18,
     "ch": 162},
    {"name": "Later", "status": "want to read", "rating": 0, "vol": 0, "ch": 0},
    {"name": "Never", "status": "won't read", "rating": 0, "vol": 0, "ch": 0}
  ]
}''';

    test('reads a manga list export', () {
      final parsed = parseBackupFile(bytesOf(json))!;
      expect(parsed.source, BackupSource.animePlanet);
      expect(parsed.entries.map((e) => e.title),
          ['Berserk', 'Monster', 'Later']);

      final [berserk, monster, later] = parsed.entries;
      expect(berserk.currentChapter, 300);
      expect(berserk.rating, 5);
      expect(berserk.addedAt, DateTime(2020, 1, 15).millisecondsSinceEpoch);

      expect(monster.status, 'read');
      expect(monster.totalChapters, 162);
      expect(monster.lastUpdated,
          DateTime(2021, 5, 1).millisecondsSinceEpoch);

      expect(later.status, 'reading');
    });

    test('an anime export has no manga', () {
      final parsed = parseBackupFile(bytesOf(
          '{"entries":[{"name":"X","status":"watched","eps":12}]}'))!;
      expect(parsed.entries, isEmpty);
    });
  });

  test('own backups still work, plain or gzipped', () {
    const own = '[{"id":"a","title":"Berserk","currentChapter":3}]';
    expect(parseBackupFile(bytesOf(own))!.source, BackupSource.mangaCompanion);
    final zipped = Uint8List.fromList(gzip.encode(utf8.encode(own)));
    expect(parseBackupFile(zipped)!.entries.single.currentChapter, 3);
  });

  test('unknown text is rejected', () {
    expect(parseBackupFile(bytesOf('hello there')), isNull);
    expect(parseBackupFile(bytesOf('{"some": "json"}')), isNull);
  });
}
