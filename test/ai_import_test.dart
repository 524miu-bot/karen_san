import 'package:flutter_test/flutter_test.dart';

import 'package:karen_san/bulk_import.dart';

void main() {
  test('AI の結果を確認画面の予定にする', () {
    final list = draftsFromAi([
      {
        'date': '2026-11-01',
        'allDay': false,
        'start': '09:00',
        'end': '12:00',
        'title': '練習',
        'location': '大谷小体育館',
        'note': '当番：千嶋',
      },
      {
        'date': '2026-11-14',
        'allDay': true,
        'start': '',
        'end': '',
        'title': '緑区大会',
        'location': '大谷小',
        'note': '',
      },
      // 時刻がおかしければ終日、終わりが前なら 1 時間
      {'date': '2026-11-20', 'allDay': false, 'start': '9時', 'title': 'A'},
      {
        'date': '2026-11-21',
        'allDay': false,
        'start': '18:00',
        'end': '17:00',
        'title': 'B',
      },
      // 日付かタイトルがなければ飛ばす
      {'date': 'なし', 'title': 'C'},
      {'date': '2026-11-22', 'title': ''},
      'おかしな値',
    ]);
    expect(list, hasLength(4));
    expect(list[0].start, DateTime(2026, 11, 1, 9));
    expect(list[0].end, DateTime(2026, 11, 1, 12));
    expect(list[0].location, '大谷小体育館');
    expect(list[1].allDay, isTrue);
    expect(list[1].end, DateTime(2026, 11, 15));
    expect(list[2].allDay, isTrue);
    expect(list[3].end, DateTime(2026, 11, 21, 19));
  });

  test('ファイル名から種類を決める', () {
    expect(scheduleMimeOf('a.PDF'), 'application/pdf');
    expect(scheduleMimeOf('a.png'), 'image/png');
    expect(scheduleMimeOf('a.heic'), 'image/jpeg');
    expect(scheduleMimeOf('x', 'image/webp'), 'image/webp');
  });

  test('残り回数（使いすぎてもマイナスにならない）', () {
    final q = AiQuota.fromMap({
      'plan': 'premium',
      'normalUsed': 3,
      'normalLimit': 200,
      'preciseUsed': 12,
      'preciseLimit': 10,
    });
    expect(q.isPremium, isTrue);
    expect(q.normalLeft, 197);
    expect(q.preciseLeft, 0);
    final free = AiQuota.fromMap({'normalUsed': 5, 'normalLimit': 5});
    expect(free.isPremium, isFalse);
    expect(free.normalLeft, 0);
  });
}
