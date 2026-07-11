import 'dart:math';

/// One tracked manga.
class MangaEntry {
  String id;
  String title;
  String coverUrl;
  String readUrl;
  int currentChapter;
  int? totalChapters;
  String status; // "reading" | "read" | "dropped"
  int rating; // 0..5
  int addedAt; // epoch ms
  int lastUpdated; // epoch ms

  MangaEntry({
    required this.id,
    required this.title,
    this.coverUrl = '',
    this.readUrl = '',
    this.currentChapter = 0,
    this.totalChapters,
    this.status = 'reading',
    this.rating = 0,
    required this.addedAt,
    required this.lastUpdated,
  });

  bool get isDone =>
      totalChapters != null &&
      totalChapters! > 0 &&
      currentChapter >= totalChapters!;

  double get progress => (totalChapters == null || totalChapters! <= 0)
      ? 0
      : (currentChapter / totalChapters!).clamp(0.0, 1.0);

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

  static int _asInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static int? _asIntOrNull(dynamic v) {
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
    final status = json['status'] as String? ?? 'reading';
    return MangaEntry(
      id: (json['id'] as String?)?.isNotEmpty == true
          ? json['id'] as String
          : newId(),
      title: json['title'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      readUrl: json['readUrl'] as String? ?? '',
      currentChapter: _asInt(json['currentChapter']),
      totalChapters: _asIntOrNull(json['totalChapters']),
      status: const {'reading', 'read', 'dropped'}.contains(status)
          ? status
          : 'reading',
      rating: _asInt(json['rating']).clamp(0, 5),
      addedAt: _asInt(json['addedAt'], now),
      lastUpdated: _asInt(json['lastUpdated'], now),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'coverUrl': coverUrl,
        'readUrl': readUrl,
        'currentChapter': currentChapter,
        'totalChapters': totalChapters,
        'status': status,
        'rating': rating,
        'addedAt': addedAt,
        'lastUpdated': lastUpdated,
      };

  MangaEntry copy() => MangaEntry.fromJson(toJson());
}
