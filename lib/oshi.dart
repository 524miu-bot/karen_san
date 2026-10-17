/// X で投稿を見たい人（推しなど）。本人だけの設定。
class Oshi {
  Oshi({required this.handle, this.name = ''});

  /// @ を除いたユーザー名。
  final String handle;

  /// 表示名（空ならユーザー名を出す）。
  final String name;

  String get label => name.isEmpty ? '@$handle' : '$name（@$handle）';

  factory Oshi.fromMap(Map<String, dynamic> m) => Oshi(
    handle: m['handle'] as String? ?? '',
    name: m['name'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {'handle': handle, 'name': name};

  /// 入力（@名前、x.com/名前 の URL など）からユーザー名を取り出す。正しくなければ null。
  static String? parseHandle(String input) {
    var s = input.trim();
    final url = RegExp(
      r'^(?:https?://)?(?:www\.|mobile\.)?(?:x|twitter)\.com/([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(s);
    if (url != null) s = url[1]!;
    if (s.startsWith('@')) s = s.substring(1);
    return RegExp(r'^[A-Za-z0-9_]{1,15}$').hasMatch(s) ? s : null;
  }

  /// [day]（端末の時刻の 0:00〜24:00）にこの人が投稿したものを X で検索する URL。
  Uri searchUrl(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    final s = start.millisecondsSinceEpoch ~/ 1000;
    final e = end.millisecondsSinceEpoch ~/ 1000;
    return Uri.https('x.com', '/search', {
      'q': 'from:$handle since_time:$s until_time:$e',
      'src': 'typed_query',
      'f': 'live',
    });
  }
}
