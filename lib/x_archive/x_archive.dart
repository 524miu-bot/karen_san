import 'dart:convert';

import 'package:intl/intl.dart';

import 'zip_reader.dart';

/// X の投稿の種類。
enum XPostKind {
  post('投稿'),
  reply('返信'),
  repost('リポスト'),
  like('いいね');

  const XPostKind(this.label);
  final String label;

  static XPostKind fromCode(String? code) => XPostKind.values.firstWhere(
    (k) => k.name == code,
    orElse: () => XPostKind.post,
  );
}

/// カレンさんに取り込んだ X の投稿 1 件。
class XPost {
  XPost({
    required this.id,
    required this.text,
    required this.postedAt,
    required this.kind,
    this.hasMedia = false,
  });

  final String id;
  final String text;

  /// 投稿された日時（いいねの場合は元の投稿の日時）。
  final DateTime postedAt;
  final XPostKind kind;
  final bool hasMedia;

  /// X で開く URL。
  Uri get url => Uri.parse('https://x.com/i/web/status/$id');
}

/// 端末の時刻での日付キー（例: 2026-10-17）。
String dayKey(DateTime time) => DateFormat('yyyy-MM-dd').format(time.toLocal());

/// X の ID（Snowflake）から投稿日時を求める。2010 年 11 月より前の ID は null。
DateTime? snowflakeTime(String id) {
  final n = BigInt.tryParse(id);
  if (n == null || n < BigInt.from(30000000000000000)) return null;
  final ms = (n >> 22).toInt() + 1288834974657;
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

const _months = {
  'Jan': 1,
  'Feb': 2,
  'Mar': 3,
  'Apr': 4,
  'May': 5,
  'Jun': 6,
  'Jul': 7,
  'Aug': 8,
  'Sep': 9,
  'Oct': 10,
  'Nov': 11,
  'Dec': 12,
};

/// "Wed Oct 15 12:34:56 +0000 2026" の形式を読む。
DateTime? parseXDate(String? s) {
  if (s == null) return null;
  final m = RegExp(
    r'^\w{3} (\w{3}) (\d{1,2}) (\d{2}):(\d{2}):(\d{2}) ([+-])(\d{2})(\d{2}) (\d{4})$',
  ).firstMatch(s.trim());
  if (m == null) return null;
  final month = _months[m[1]];
  if (month == null) return null;
  final utc = DateTime.utc(
    int.parse(m[9]!),
    month,
    int.parse(m[2]!),
    int.parse(m[3]!),
    int.parse(m[4]!),
    int.parse(m[5]!),
  );
  final offset = Duration(hours: int.parse(m[7]!), minutes: int.parse(m[8]!));
  return m[6] == '+' ? utc.subtract(offset) : utc.add(offset);
}

/// アーカイブの .js（`window.YTD.tweets.part0 = [...]`）から中身の配列を取り出す。
List<dynamic> parseYtd(String js) {
  final start = js.indexOf('[');
  if (start < 0) return const [];
  return jsonDecode(js.substring(start)) as List<dynamic>;
}

String _unescapeHtml(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

/// 自分の投稿（tweets.js）を読む。
List<XPost> parseTweets(List<dynamic> items) {
  final posts = <XPost>[];
  for (final item in items) {
    final t =
        (item is Map && item['tweet'] is Map ? item['tweet'] : item)
            as Map<String, dynamic>;
    final id = (t['id_str'] ?? t['id'])?.toString();
    final at =
        parseXDate(t['created_at'] as String?) ??
        (id == null ? null : snowflakeTime(id));
    if (id == null || at == null) continue;

    var text = (t['full_text'] ?? t['text'] ?? '') as String;
    final entities = t['entities'] as Map<String, dynamic>? ?? const {};
    // 短縮 URL（t.co）を元の URL に戻し、画像の URL は本文から消す。
    for (final u in (entities['urls'] as List? ?? const [])) {
      final short = u['url'] as String?;
      final expanded = u['expanded_url'] as String?;
      if (short != null && expanded != null) {
        text = text.replaceAll(short, expanded);
      }
    }
    final media = [
      ...(entities['media'] as List? ?? const []),
      ...((t['extended_entities'] as Map?)?['media'] as List? ?? const []),
    ];
    for (final m in media) {
      final short = m['url'] as String?;
      if (short != null) text = text.replaceAll(short, '');
    }
    text = _unescapeHtml(text).trim();

    final kind = text.startsWith('RT @')
        ? XPostKind.repost
        : t['in_reply_to_status_id_str'] != null ||
              t['in_reply_to_status_id'] != null
        ? XPostKind.reply
        : XPostKind.post;
    posts.add(
      XPost(
        id: id,
        text: text,
        postedAt: at,
        kind: kind,
        hasMedia: media.isNotEmpty,
      ),
    );
  }
  return posts;
}

/// いいねした投稿（like.js）を読む。いいねした日ではなく、元の投稿の日付になる。
List<XPost> parseLikes(List<dynamic> items) {
  final posts = <XPost>[];
  for (final item in items) {
    final l =
        (item is Map && item['like'] is Map ? item['like'] : item)
            as Map<String, dynamic>;
    final id = l['tweetId']?.toString();
    if (id == null) continue;
    final at = snowflakeTime(id);
    if (at == null) continue;
    posts.add(
      XPost(
        id: id,
        text: _unescapeHtml((l['fullText'] as String? ?? '').trim()),
        postedAt: at,
        kind: XPostKind.like,
      ),
    );
  }
  return posts;
}

/// アーカイブの中で読み込む対象のファイルか。
enum XArchiveFileKind { tweets, likes }

XArchiveFileKind? archiveFileKind(String path) {
  final name = path.split('/').last.split('\\').last;
  if (RegExp(r'^tweets?(-part\d+)?\.js$').hasMatch(name)) {
    return XArchiveFileKind.tweets;
  }
  if (RegExp(r'^like(-part\d+)?\.js$').hasMatch(name)) {
    return XArchiveFileKind.likes;
  }
  return null;
}

/// 選ばれたファイル（ZIP そのもの、または中の tweets.js / like.js）から投稿を読む。
class XArchiveReader {
  int tweets = 0;
  int likes = 0;
  final posts = <XPost>[];

  void addJs(String path, String js) {
    switch (archiveFileKind(path)) {
      case XArchiveFileKind.tweets:
        final p = parseTweets(parseYtd(js));
        tweets += p.length;
        posts.addAll(p);
      case XArchiveFileKind.likes:
        final p = parseLikes(parseYtd(js));
        likes += p.length;
        posts.addAll(p);
      case null:
        break;
    }
  }

  /// ZIP の中から tweets.js・like.js だけを取り出して読む。見つかったファイル数を返す。
  Future<int> addZip(RandomAccessSource source) async {
    final zip = await ZipReader.open(source);
    var found = 0;
    for (final entry in zip.entries) {
      if (archiveFileKind(entry.name) == null) continue;
      found++;
      final bytes = await zip.extract(entry);
      addJs(entry.name, utf8.decode(bytes, allowMalformed: true));
    }
    return found;
  }
}
