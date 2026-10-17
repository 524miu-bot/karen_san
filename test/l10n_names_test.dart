import 'package:flutter_test/flutter_test.dart';

import 'package:karen_san/holidays.dart';
import 'package:karen_san/l10n.dart';

void main() {
  test('1980〜2099 年に出てくる祝日名がすべて英語名を持つ', () {
    final names = <String>{
      for (var y = holidayFirstYear; y <= holidayLastYear; y++)
        ...holidaysOf(y).values,
    };
    expect(names.difference(holidayNamesEn.keys.toSet()), isEmpty);
  });
}
