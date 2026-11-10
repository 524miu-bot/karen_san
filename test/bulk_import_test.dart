import 'package:flutter_test/flutter_test.dart';

import 'package:karen_san/bulk_import.dart';

void main() {
  test('1 行 1 件で、時間・終日・場所・メモを読む', () {
    final errors = <int>[];
    final list = parseBulkEvents('''
# バスケ 11 月
2026-11-01 09:00-12:00 | 練習 | 大谷小体育館 | 当番：千嶋
2026/11/14 終日 | 緑区大会 | 大谷小
2026-11-21 終日 | ブロンコス戦 前座試合・観戦 | | 男女メンバー
2026-11-22 18:00〜20:00 | 打ち上げ

2026-11-04 終日 | 早番 精算
''', errors: errors);
    expect(errors, isEmpty);
    expect(list, hasLength(5));
    expect(list[0].start, DateTime(2026, 11, 1, 9));
    expect(list[0].end, DateTime(2026, 11, 1, 12));
    expect(list[0].location, '大谷小体育館');
    expect(list[0].note, '当番：千嶋');
    expect(list[1].allDay, isTrue);
    expect(list[1].end, DateTime(2026, 11, 15));
    expect(list[2].location, '');
    expect(list[2].note, '男女メンバー');
    expect(list[3].end, DateTime(2026, 11, 22, 20));
    expect(list[4].title, '早番 精算');
  });

  test('読めない行は飛ばして行番号を返す', () {
    final errors = <int>[];
    final list = parseBulkEvents('''
2026-11-01 09:00-12:00 | 練習
11/1 9:00 練習
2026-02-30 終日 | ない日
2026-11-01 12:00-09:00 | 終わりが前
2026-11-01 終日 |
''', errors: errors);
    expect(list, hasLength(1));
    expect(errors, [2, 3, 4, 5]);
  });
}
