import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'models/manga_entry.dart';
import 'storage.dart';

/// Which app a backup file came from.
enum BackupSource {
  mangaCompanion('Manga Companion'),
  myAnimeList('MyAnimeList'),
  animePlanet('Anime-Planet'),
  mihon('Mihon');

  final String label;
  const BackupSource(this.label);
}

class ParsedBackup {
  final BackupSource source;
  final List<MangaEntry> entries;
  const ParsedBackup(this.source, this.entries);
}

/// Reads any file the app understands: its own JSON backup, a MyAnimeList
/// XML export, an Anime-Planet JSON export, or a Mihon/Tachiyomi backup.
/// Any of them may be gzipped.
///
/// Returns null when the file is none of these. Top-level so it can run in
/// a background isolate via `compute`.
ParsedBackup? parseBackupFile(Uint8List bytes) {
  var data = bytes;
  if (data.length > 2 && data[0] == 0x1f && data[1] == 0x8b) {
    try {
      data = Uint8List.fromList(gzip.decode(data));
    } catch (_) {
      return null;
    }
  }

  // Sniffing by first character can misfire on binary data, so a text
  // parser that fails falls through to the next format instead of ending
  // the attempt.
  final text = _tryUtf8(data);
  if (text != null) {
    final head = text.replaceFirst('﻿', '').trimLeft();
    if (head.startsWith('[') || head.startsWith('{')) {
      final own = MangaStore.parseExport(text);
      if (own != null) return ParsedBackup(BackupSource.mangaCompanion, own);
      final ap = parseAnimePlanetJson(text);
      if (ap != null) return ParsedBackup(BackupSource.animePlanet, ap);
    }
    if (head.startsWith('<')) {
      final mal = parseMalXml(text);
      if (mal != null) return ParsedBackup(BackupSource.myAnimeList, mal);
    }
  }

  final mihon = parseMihonBackup(data);
  if (mihon != null) return ParsedBackup(BackupSource.mihon, mihon);
  return null;
}

String? _tryUtf8(Uint8List data) {
  try {
    return utf8.decode(data);
  } catch (_) {
    return null;
  }
}

int _now() => DateTime.now().millisecondsSinceEpoch;

/// "2021-04-09" or "2021-04-09 13:00:00" to epoch ms. Unknown parts may be
/// written as zeros ("2021-00-00"), an unknown date as all zeros.
int? _parseDate(Object? raw) {
  if (raw is! String) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw.trim());
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  if (y == 0) return null;
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  return DateTime(y, mo == 0 ? 1 : mo, d == 0 ? 1 : d).millisecondsSinceEpoch;
}

int _toInt(Object? v) {
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v.trim()) ?? 0;
  return 0;
}

double _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? 0;
  return 0;
}

// ------------------------------------------------------------ MyAnimeList

/// Parses MyAnimeList's list export (other sites export the same format).
/// Returns null if the text is not one; an empty list if it is one with no
/// manga in it, such as an anime export.
List<MangaEntry>? parseMalXml(String xml) {
  if (!xml.contains('<myanimelist')) return null;
  final now = _now();
  final out = <MangaEntry>[];
  final blocks =
      RegExp(r'<manga>(.*?)</manga>', dotAll: true).allMatches(xml);
  for (final m in blocks) {
    final block = m.group(1)!;
    final title = _xmlField(block, 'manga_title').trim();
    if (title.isEmpty) continue;

    final malId = _toInt(_xmlField(block, 'manga_mangadb_id'));
    final total = _toInt(_xmlField(block, 'manga_chapters'));
    final read = _toInt(_xmlField(block, 'my_read_chapters'));
    final score = _toInt(_xmlField(block, 'my_score'));
    final status = _malStatus(_xmlField(block, 'my_status'));
    final started = _parseDate(_xmlField(block, 'my_start_date'));
    final finished = _parseDate(_xmlField(block, 'my_finish_date'));

    out.add(MangaEntry(
      id: MangaEntry.newId(),
      title: title,
      readUrl: malId > 0 ? 'https://myanimelist.net/manga/$malId' : '',
      currentChapter: read < 0 ? 0 : read,
      totalChapters: total > 0 ? total : null,
      status: status,
      rating: (score / 2).round().clamp(0, 5),
      addedAt: started ?? now,
      // The export has no "last changed" time. A finish date is the best
      // stand-in for finished titles; anything else counts as just now.
      lastUpdated: status != 'reading' && finished != null ? finished : now,
    ));
  }
  return out;
}

/// MAL writes statuses as words, some third-party exports as numbers.
/// The shelf has no "on hold" or "plan to read", so those land in reading.
String _malStatus(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'completed':
    case '2':
      return 'read';
    case 'dropped':
    case '4':
      return 'dropped';
    default:
      return 'reading';
  }
}

/// Text of `<name>…</name>` inside [block], with CDATA unwrapped and
/// entities decoded. Empty when missing.
String _xmlField(String block, String name) {
  final m = RegExp('<$name>(.*?)</$name>', dotAll: true).firstMatch(block);
  if (m == null) return '';
  final raw = m.group(1)!.trim();
  final cdata =
      RegExp(r'^<!\[CDATA\[(.*)\]\]>$', dotAll: true).firstMatch(raw);
  if (cdata != null) return cdata.group(1)!;
  return _decodeEntities(raw);
}

String _decodeEntities(String s) {
  return s.replaceAllMapped(
    RegExp(r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos);'),
    (m) {
      final e = m.group(1)!;
      switch (e) {
        case 'amp':
          return '&';
        case 'lt':
          return '<';
        case 'gt':
          return '>';
        case 'quot':
          return '"';
        case 'apos':
          return "'";
      }
      final code = e.startsWith('#x')
          ? int.tryParse(e.substring(2), radix: 16)
          : int.tryParse(e.substring(1));
      if (code == null || code > 0x10FFFF) return m.group(0)!;
      return String.fromCharCode(code);
    },
  );
}

// ----------------------------------------------------------- Anime-Planet

/// Parses Anime-Planet's list export:
/// `{"user": {...}, "entries": [{"name", "status", "ch", "rating", ...}]}`.
/// Returns null if the text is not one; an empty list for an anime export.
List<MangaEntry>? parseAnimePlanetJson(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  final list = decoded['entries'];
  if (list is! List) return null;

  final now = _now();
  final out = <MangaEntry>[];
  for (final e in list.whereType<Map<String, dynamic>>()) {
    // Anime exports count episodes ("eps") instead of chapters.
    if (!e.containsKey('ch')) continue;
    final title = (e['name'] as Object?)?.toString().trim() ?? '';
    if (title.isEmpty) continue;

    final apStatus = (e['status'] as Object?)?.toString().toLowerCase() ?? '';
    // "Won't read" is a list of things the user chose to never start.
    if (apStatus == "won't read") continue;
    final status = switch (apStatus) {
      'read' => 'read',
      'dropped' => 'dropped',
      // reading, stalled, want to read: the shelf has no separate
      // "on hold" or "plan to read", so they go to reading.
      _ => 'reading',
    };

    final ch = _toInt(e['ch']);
    final started = _parseDate(e['started']);
    final completed = _parseDate(e['completed']);
    out.add(MangaEntry(
      id: MangaEntry.newId(),
      title: title,
      currentChapter: ch < 0 ? 0 : ch,
      // No series length in the export; for a finished title the chapters
      // read is the best guess.
      totalChapters: status == 'read' && ch > 0 ? ch : null,
      status: status,
      // Anime-Planet rates 0–5 in half stars.
      rating: _toDouble(e['rating']).round().clamp(0, 5),
      addedAt: started ?? now,
      lastUpdated: status != 'reading' && completed != null ? completed : now,
    ));
  }
  return out;
}

// ------------------------------------------------------------------ Mihon

/// Parses a Mihon (or Tachiyomi fork) backup: protobuf, already un-gzipped.
/// Only titles in the library are taken. Returns null if [data] does not
/// look like a backup at all.
///
/// Field numbers follow Mihon's `Backup`, `BackupManga`, `BackupChapter`,
/// `BackupTracking` and `BackupHistory` models.
List<MangaEntry>? parseMihonBackup(Uint8List data) {
  try {
    final r = _Proto(data);
    final out = <MangaEntry>[];
    var sawManga = false;
    while (!r.done) {
      final (field, wire) = r.tag();
      if (field == 1 && wire == 2) {
        sawManga = true;
        final entry = _mihonManga(r.message());
        if (entry != null) out.add(entry);
      } else {
        r.skip(wire);
      }
    }
    return sawManga ? out : null;
  } catch (_) {
    return null;
  }
}

MangaEntry? _mihonManga(_Proto r) {
  var url = '';
  var title = '';
  var thumbnail = '';
  var publishStatus = 0;
  var dateAdded = 0;
  var modified = 0;
  var favorite = true;
  var lastRead = 0;
  // Highest chapter number marked read, highest seen at all, and a plain
  // count for sources that leave chapter numbers unset (-1).
  var maxRead = -1.0;
  var maxSeen = -1.0;
  var readCount = 0;
  var trackedRead = 0.0;
  var trackedTotal = 0;
  var trackingUrl = '';

  while (!r.done) {
    final (field, wire) = r.tag();
    switch ((field, wire)) {
      case (2, 2):
        url = r.string();
      case (3, 2):
        title = r.string();
      case (8, 0):
        publishStatus = r.varint();
      case (9, 2):
        thumbnail = r.string();
      case (13, 0):
        dateAdded = r.varint();
      case (16, 2):
        final ch = _mihonChapter(r.message());
        if (ch.number > maxSeen) maxSeen = ch.number;
        if (ch.read) {
          readCount++;
          if (ch.number > maxRead) maxRead = ch.number;
        }
      case (18, 2):
        final t = _mihonTracking(r.message());
        if (t.lastRead > trackedRead) trackedRead = t.lastRead;
        if (t.total > trackedTotal) trackedTotal = t.total;
        if (trackingUrl.isEmpty && t.url.startsWith('http')) {
          trackingUrl = t.url;
        }
      case (100, 0):
        favorite = r.varint() != 0;
      case (104, 2):
        final at = _mihonHistory(r.message());
        if (at > lastRead) lastRead = at;
      // 106 is lastModifiedAt in older backups, 107 favoriteModifiedAt.
      case (106, 0) || (107, 0):
        final v = r.varint();
        if (v > modified) modified = v;
      default:
        r.skip(wire);
    }
  }

  title = title.trim();
  if (!favorite || title.isEmpty) return null;

  var current = maxRead >= 0 ? maxRead.floor() : readCount;
  if (trackedRead.floor() > current) current = trackedRead.floor();

  // 2 = completed, 4 = publishing finished. Only then is the last chapter
  // the source lists also the last one there is.
  int? total;
  if (trackedTotal > 0) {
    total = trackedTotal;
  } else if ((publishStatus == 2 || publishStatus == 4) && maxSeen >= 1) {
    total = maxSeen.floor();
  }

  final added = _asMs(dateAdded) ?? _now();
  return MangaEntry(
    id: MangaEntry.newId(),
    title: title,
    coverUrl: thumbnail.startsWith('http') ? thumbnail : '',
    // Source links are usually relative to an extension's site, which the
    // backup does not name. A tracker page is the next best link.
    readUrl: url.startsWith('http') ? url : trackingUrl,
    currentChapter: current,
    totalChapters: total,
    status: total != null && current >= total ? 'read' : 'reading',
    addedAt: added,
    lastUpdated: lastRead > 0 ? lastRead : (_asMs(modified) ?? added),
  );
}

/// Mihon stores some times in seconds and some in ms; normalise to ms.
int? _asMs(int v) {
  if (v <= 0) return null;
  return v < 100000000000 ? v * 1000 : v;
}

({double number, bool read}) _mihonChapter(_Proto r) {
  var number = -1.0;
  var read = false;
  while (!r.done) {
    final (field, wire) = r.tag();
    switch ((field, wire)) {
      case (4, 0):
        read = r.varint() != 0;
      case (9, 5):
        number = r.float32();
      default:
        r.skip(wire);
    }
  }
  return (number: number, read: read);
}

({double lastRead, int total, String url}) _mihonTracking(_Proto r) {
  var lastRead = 0.0;
  var total = 0;
  var url = '';
  while (!r.done) {
    final (field, wire) = r.tag();
    switch ((field, wire)) {
      case (4, 2):
        url = r.string();
      case (6, 5):
        lastRead = r.float32();
      case (7, 0):
        total = r.varint();
      default:
        r.skip(wire);
    }
  }
  return (lastRead: lastRead, total: total, url: url);
}

int _mihonHistory(_Proto r) {
  var lastRead = 0;
  while (!r.done) {
    final (field, wire) = r.tag();
    if (field == 2 && wire == 0) {
      lastRead = r.varint();
    } else {
      r.skip(wire);
    }
  }
  return lastRead;
}

/// Minimal protobuf wire-format reader: just enough to walk a message and
/// pull out the fields above. Throws [FormatException] on malformed input.
class _Proto {
  final Uint8List _b;
  int _pos = 0;

  _Proto(this._b);

  bool get done => _pos >= _b.length;

  void _need(int n) {
    if (n < 0 || _pos + n > _b.length) {
      throw const FormatException('Truncated protobuf');
    }
  }

  int varint() {
    var result = 0;
    var shift = 0;
    while (true) {
      _need(1);
      final byte = _b[_pos++];
      result |= (byte & 0x7f) << shift;
      if (byte & 0x80 == 0) return result;
      shift += 7;
      if (shift > 63) throw const FormatException('Varint too long');
    }
  }

  /// Field number and wire type of the next field.
  (int, int) tag() {
    final t = varint();
    final field = t >> 3;
    if (field <= 0) throw const FormatException('Bad field number');
    return (field, t & 7);
  }

  Uint8List bytes() {
    final len = varint();
    _need(len);
    final out = Uint8List.sublistView(_b, _pos, _pos + len);
    _pos += len;
    return out;
  }

  _Proto message() => _Proto(bytes());

  String string() => utf8.decode(bytes(), allowMalformed: true);

  double float32() {
    _need(4);
    final v = ByteData.sublistView(_b, _pos, _pos + 4)
        .getFloat32(0, Endian.little);
    _pos += 4;
    return v;
  }

  void skip(int wire) {
    switch (wire) {
      case 0:
        varint();
      case 1:
        _need(8);
        _pos += 8;
      case 2:
        final len = varint();
        _need(len);
        _pos += len;
      case 5:
        _need(4);
        _pos += 4;
      default:
        throw FormatException('Unsupported wire type $wire');
    }
  }
}
