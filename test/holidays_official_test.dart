import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:karen_san/holidays.dart';

/// 内閣府「国民の祝日について」で公開されている祝日一覧
/// （https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv）の 1980 年以降を
/// UTF-8 に変換したもの。毎年 2 月ごろに翌年分が追加されるので、
/// そのときに取り直してこのテストを流すこと。
const _fixture = 'test/fixtures/syukujitsu_cao.csv';

/// 公式一覧の名前を、アプリで表示する名前に対応づける。
/// 公式一覧では振替休日・国民の休日をどちらも「休日」と書いている。
bool _sameName(String official, String ours) {
  switch (official) {
    case '休日':
      return ours == '振替休日' || ours == '国民の休日';
    case '休日（祝日扱い）':
      return ours == '天皇の即位の日' || ours == '即位礼正殿の儀';
    case '大喪の礼':
      return ours == '昭和天皇の大喪の礼';
    case '結婚の儀':
      return ours == '皇太子徳仁親王の結婚の儀';
    case '体育の日（スポーツの日）':
      return ours == '体育の日';
    default:
      return official == ours;
  }
}

void main() {
  final official = <DateTime, String>{};
  for (final line in File(_fixture).readAsLinesSync().skip(1)) {
    if (line.trim().isEmpty) continue;
    final [date, name] = line.split(',');
    final [y, m, d] = date.split('/').map(int.parse).toList();
    official[DateTime(y, m, d)] = name;
  }
  final years = official.keys.map((d) => d.year).toSet().toList()..sort();

  test('公式一覧は 1980 年から毎年分そろっている', () {
    expect(years.first, 1980);
    expect(years.length, years.last - 1980 + 1);
  });

  for (final year in years) {
    test('$year 年の祝日が内閣府の公式一覧と完全に一致する', () {
      final ours = holidaysOf(year);
      final theirs = {
        for (final e in official.entries)
          if (e.key.year == year) e.key: e.value,
      };

      final missing = theirs.keys.where((d) => !ours.containsKey(d));
      final extra = ours.keys.where((d) => !theirs.containsKey(d));
      final wrongName = theirs.keys.where(
          (d) => ours.containsKey(d) && !_sameName(theirs[d]!, ours[d]!));

      String show(Iterable<DateTime> ds, Map<DateTime, String> names) =>
          ds.map((d) => '${d.month}/${d.day} ${names[d]}').join(', ');

      expect(missing, isEmpty, reason: '足りない祝日: ${show(missing, theirs)}');
      expect(extra, isEmpty, reason: '余分な祝日: ${show(extra, ours)}');
      expect(wrongName, isEmpty,
          reason: '名前が違う: ${wrongName.map((d) => '${d.month}/${d.day} 公式=${theirs[d]} アプリ=${ours[d]}').join(', ')}');
    });
  }
}
