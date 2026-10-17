import 'package:flutter_test/flutter_test.dart';

import 'package:karen_san/holidays.dart';

/// 'M/D 名前' の一覧から期待値を作る。
Map<DateTime, String> _expected(int year, List<String> lines) => {
  for (final line in lines)
    DateTime(
      year,
      int.parse(line.split(' ').first.split('/')[0]),
      int.parse(line.split(' ').first.split('/')[1]),
    ): line.split(
      ' ',
    )[1],
};

void _expectYear(int year, List<String> lines) {
  final actual = holidaysOf(year);
  final expected = _expected(year, lines);
  String fmt(Map<DateTime, String> m) => (m.keys.toList()..sort())
      .map((d) => '${d.month}/${d.day} ${m[d]}')
      .join('\n');
  expect(fmt(actual), fmt(expected), reason: '$year 年の祝日一覧');
}

void main() {
  // 期待値は内閣府「国民の祝日について」の一覧どおり。
  test('2019 年（改元・即位の日・天皇誕生日なし）', () {
    _expectYear(2019, [
      '1/1 元日',
      '1/14 成人の日',
      '2/11 建国記念の日',
      '3/21 春分の日',
      '4/29 昭和の日',
      '4/30 国民の休日',
      '5/1 天皇の即位の日',
      '5/2 国民の休日',
      '5/3 憲法記念日',
      '5/4 みどりの日',
      '5/5 こどもの日',
      '5/6 振替休日',
      '7/15 海の日',
      '8/11 山の日',
      '8/12 振替休日',
      '9/16 敬老の日',
      '9/23 秋分の日',
      '10/14 体育の日',
      '10/22 即位礼正殿の儀',
      '11/3 文化の日',
      '11/4 振替休日',
      '11/23 勤労感謝の日',
    ]);
  });

  test('2020 年（東京オリンピックで海の日・スポーツの日・山の日が移動）', () {
    _expectYear(2020, [
      '1/1 元日',
      '1/13 成人の日',
      '2/11 建国記念の日',
      '2/23 天皇誕生日',
      '2/24 振替休日',
      '3/20 春分の日',
      '4/29 昭和の日',
      '5/3 憲法記念日',
      '5/4 みどりの日',
      '5/5 こどもの日',
      '5/6 振替休日',
      '7/23 海の日',
      '7/24 スポーツの日',
      '8/10 山の日',
      '9/21 敬老の日',
      '9/22 秋分の日',
      '11/3 文化の日',
      '11/23 勤労感謝の日',
    ]);
  });

  test('2021 年（オリンピック延期に伴う移動）', () {
    _expectYear(2021, [
      '1/1 元日',
      '1/11 成人の日',
      '2/11 建国記念の日',
      '2/23 天皇誕生日',
      '3/20 春分の日',
      '4/29 昭和の日',
      '5/3 憲法記念日',
      '5/4 みどりの日',
      '5/5 こどもの日',
      '7/22 海の日',
      '7/23 スポーツの日',
      '8/8 山の日',
      '8/9 振替休日',
      '9/20 敬老の日',
      '9/23 秋分の日',
      '11/3 文化の日',
      '11/23 勤労感謝の日',
    ]);
  });

  test('2024 年（振替休日が多い年）', () {
    _expectYear(2024, [
      '1/1 元日',
      '1/8 成人の日',
      '2/11 建国記念の日',
      '2/12 振替休日',
      '2/23 天皇誕生日',
      '3/20 春分の日',
      '4/29 昭和の日',
      '5/3 憲法記念日',
      '5/4 みどりの日',
      '5/5 こどもの日',
      '5/6 振替休日',
      '7/15 海の日',
      '8/11 山の日',
      '8/12 振替休日',
      '9/16 敬老の日',
      '9/22 秋分の日',
      '9/23 振替休日',
      '10/14 スポーツの日',
      '11/3 文化の日',
      '11/4 振替休日',
      '11/23 勤労感謝の日',
    ]);
  });

  test('2025 年', () {
    _expectYear(2025, [
      '1/1 元日',
      '1/13 成人の日',
      '2/11 建国記念の日',
      '2/23 天皇誕生日',
      '2/24 振替休日',
      '3/20 春分の日',
      '4/29 昭和の日',
      '5/3 憲法記念日',
      '5/4 みどりの日',
      '5/5 こどもの日',
      '5/6 振替休日',
      '7/21 海の日',
      '8/11 山の日',
      '9/15 敬老の日',
      '9/23 秋分の日',
      '10/13 スポーツの日',
      '11/3 文化の日',
      '11/23 勤労感謝の日',
      '11/24 振替休日',
    ]);
  });

  test('2026 年（シルバーウィークの国民の休日）', () {
    _expectYear(2026, [
      '1/1 元日',
      '1/12 成人の日',
      '2/11 建国記念の日',
      '2/23 天皇誕生日',
      '3/20 春分の日',
      '4/29 昭和の日',
      '5/3 憲法記念日',
      '5/4 みどりの日',
      '5/5 こどもの日',
      '5/6 振替休日',
      '7/20 海の日',
      '8/11 山の日',
      '9/21 敬老の日',
      '9/22 国民の休日',
      '9/23 秋分の日',
      '10/12 スポーツの日',
      '11/3 文化の日',
      '11/23 勤労感謝の日',
    ]);
  });

  test('2027 年（春分の日が日曜日）', () {
    _expectYear(2027, [
      '1/1 元日',
      '1/11 成人の日',
      '2/11 建国記念の日',
      '2/23 天皇誕生日',
      '3/21 春分の日',
      '3/22 振替休日',
      '4/29 昭和の日',
      '5/3 憲法記念日',
      '5/4 みどりの日',
      '5/5 こどもの日',
      '7/19 海の日',
      '8/11 山の日',
      '9/20 敬老の日',
      '9/23 秋分の日',
      '10/11 スポーツの日',
      '11/3 文化の日',
      '11/23 勤労感謝の日',
    ]);
  });

  test('2009 年・2015 年・2032 年のシルバーウィーク', () {
    expect(holidayName(DateTime(2009, 9, 22)), '国民の休日');
    expect(holidayName(DateTime(2015, 9, 22)), '国民の休日');
    expect(holidayName(DateTime(2032, 9, 20)), '敬老の日');
    expect(holidayName(DateTime(2032, 9, 21)), '国民の休日');
    expect(holidayName(DateTime(2032, 9, 22)), '秋分の日');
  });

  test('2006 年以前の振替休日とみどりの日', () {
    // 2006 年 5/4 は国民の休日（みどりの日は 4/29）。
    expect(holidayName(DateTime(2006, 4, 29)), 'みどりの日');
    expect(holidayName(DateTime(2006, 5, 4)), '国民の休日');
    // 2018 年 12/23 は日曜日 → 12/24 振替休日。
    expect(holidayName(DateTime(2018, 12, 23)), '天皇誕生日');
    expect(holidayName(DateTime(2018, 12, 24)), '振替休日');
  });

  test('行事・記念日は祝日にしない', () {
    expect(holidayName(DateTime(2026, 11, 15)), isNull, reason: '七五三');
    expect(holidayName(DateTime(2026, 2, 3)), isNull, reason: '節分');
    expect(holidayName(DateTime(2026, 3, 3)), isNull, reason: 'ひな祭り');
    expect(holidayName(DateTime(2026, 5, 10)), isNull, reason: '母の日');
    expect(holidayName(DateTime(2026, 7, 7)), isNull, reason: '七夕');
    expect(holidayName(DateTime(2026, 12, 25)), isNull, reason: 'クリスマス');
    expect(holidayName(DateTime(2026, 12, 31)), isNull, reason: '大晦日');
    expect(holidayName(DateTime(2026, 1, 2)), isNull, reason: '三が日');
    expect(
      holidayName(DateTime(2019, 12, 23)),
      isNull,
      reason: '2019 年以降は天皇誕生日ではない',
    );
  });

  test('2000〜2099 年のどの年も、祝日の数が妥当で日付が重ならない', () {
    for (var y = 2000; y <= 2099; y++) {
      final h = holidaysOf(y);
      expect(h.length, inInclusiveRange(15, 25), reason: '$y 年');
      expect(h.keys.every((d) => d.year == y), isTrue, reason: '$y 年');
      // 振替休日・国民の休日が日曜日になることはない。
      for (final e in h.entries) {
        if (e.value == '振替休日' || e.value == '国民の休日') {
          expect(e.key.weekday, isNot(DateTime.sunday), reason: '$y ${e.key}');
        }
      }
    }
  });
}
