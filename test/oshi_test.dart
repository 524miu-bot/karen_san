import 'package:flutter_test/flutter_test.dart';

import 'package:karen_san/oshi.dart';

void main() {
  test('いろいろな書き方からユーザー名を取り出す', () {
    expect(Oshi.parseHandle('@karen_san'), 'karen_san');
    expect(Oshi.parseHandle(' karen_san '), 'karen_san');
    expect(Oshi.parseHandle('https://x.com/karen_san'), 'karen_san');
    expect(
      Oshi.parseHandle('https://twitter.com/Karen_San/status/123'),
      'Karen_San',
    );
    expect(Oshi.parseHandle('x.com/karen_san?s=21'), 'karen_san');
  });

  test('ユーザー名として正しくないものは null', () {
    expect(Oshi.parseHandle(''), isNull);
    expect(Oshi.parseHandle('@'), isNull);
    expect(Oshi.parseHandle('カレン'), isNull);
    expect(Oshi.parseHandle('a' * 16), isNull);
    expect(Oshi.parseHandle('foo bar'), isNull);
  });

  test('検索 URL はその日の 0:00〜24:00（端末の時刻）', () {
    final url = Oshi(handle: 'karen_san')
        .searchUrl(DateTime(2026, 10, 18, 15, 30));
    final start = DateTime(2026, 10, 18).millisecondsSinceEpoch ~/ 1000;
    final end = DateTime(2026, 10, 19).millisecondsSinceEpoch ~/ 1000;
    expect(url.host, 'x.com');
    expect(url.path, '/search');
    expect(
      url.queryParameters['q'],
      'from:karen_san since_time:$start until_time:$end',
    );
    expect(url.queryParameters['f'], 'live');
  });

  test('表示名', () {
    expect(Oshi(handle: 'a').label, '@a');
    expect(Oshi(handle: 'a', name: '推し').label, '推し（@a）');
  });
}
