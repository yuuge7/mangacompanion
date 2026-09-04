// Short, mono-friendly formatting. Everything here ends up set in
// PlexMono with tabular figures, so widths stay stable while numbers change.

/// "just now", "14m", "6h", "3d", "2w", "5mo". Deliberately compact: on a
/// shelf row this sits beside the chapter count and must not compete with it.
String timeAgo(int ts) {
  if (ts <= 0) return '';
  final d = DateTime.now().millisecondsSinceEpoch - ts;
  if (d < 0) return 'just now';
  final minutes = d ~/ 60000;
  if (minutes < 1) return 'just now';
  if (minutes < 60) return '${minutes}m';
  final hours = d ~/ 3600000;
  if (hours < 24) return '${hours}h';
  final days = d ~/ 86400000;
  if (days < 14) return '${days}d';
  if (days < 60) return '${days ~/ 7}w';
  return '${days ~/ 30}mo';
}

/// 4182 -> "4,182". Used wherever a tally is shown as prose.
String groupDigits(int n) {
  final s = n.abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

/// "1 title" / "12 titles" — the app says "titles", never "entries" or
/// "items", because that is the word on the shelf.
String titleCount(int n) => '${groupDigits(n)} ${n == 1 ? 'title' : 'titles'}';
