import 'models/manga_entry.dart';

const csvColumns = [
  'title',
  'status',
  'current_chapter',
  'total_chapters',
  'rating',
  'rereads',
  'started',
  'finished',
  'added',
  'last_updated',
  'read_url',
  'cover_url',
];

/// The shelf as CSV for spreadsheets: RFC 4180 quoting, CRLF rows, and a
/// byte-order mark so Excel reads non-Latin titles correctly.
String toCsv(List<MangaEntry> entries) {
  final out = StringBuffer('﻿')
    ..write(csvColumns.join(','))
    ..write('\r\n');
  for (final e in entries) {
    out
      ..write([
        _text(e.title),
        e.status.json,
        '${e.currentChapter}',
        e.totalChapters?.toString() ?? '',
        '${e.rating}',
        '${e.rereads}',
        _date(e.startedAt),
        _date(e.finishedAt),
        _date(e.addedAt),
        _date(e.lastUpdated),
        _text(e.readUrl),
        _text(e.coverUrl),
      ].join(','))
      ..write('\r\n');
  }
  return out.toString();
}

/// Quotes when needed. A leading = + - @ is prefixed with ' so a
/// spreadsheet never runs a title from an imported file as a formula.
String _text(String s) {
  var v = s;
  if (v.isNotEmpty && '=+-@\t\r'.contains(v[0])) v = "'$v";
  if (v.contains(RegExp('[",\r\n]'))) {
    v = '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

/// Local "2025-03-09 21:04", or empty for no date.
String _date(int? ms) {
  if (ms == null || ms <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} '
      '${two(d.hour)}:${two(d.minute)}';
}
