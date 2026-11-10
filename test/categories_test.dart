import 'package:flutter_test/flutter_test.dart';

import 'package:karen_san/categories.dart';
import 'package:karen_san/models.dart';
import 'package:karen_san/planner.dart';

CalendarEvent _e({String? category, CalendarKind kind = CalendarKind.family}) =>
    CalendarEvent(
      title: 't',
      start: DateTime(2026, 11, 10, 9),
      end: DateTime(2026, 11, 10, 10),
      allDay: false,
      kind: kind,
      categoryId: category,
    );

void main() {
  group('予定の種類', () {
    test('種類のない古い予定は、保存場所で家庭か仕事になる', () {
      expect(categoryOf(_e()), Category.familyId);
      expect(categoryOf(_e(kind: CalendarKind.work)), Category.workId);
      expect(categoryOf(_e(category: 'c_basket')), 'c_basket');
    });

    test('家庭・共有の種類・仕事・自分だけの種類の順に並ぶ', () {
      final list = mergeCategories(
        familyName: '家庭',
        workName: '仕事',
        shared: {
          'b': const Category(id: 'b', name: '空手', shared: true, order: 2),
          'a': const Category(id: 'a', name: 'バスケ', shared: true, order: 1),
        },
        private: {'p': const Category(id: 'p', name: '副業', shared: false)},
      );
      expect(list.map((c) => c.name), ['家庭', 'バスケ', '空手', '仕事', '副業']);
      expect(list.first.isBuiltIn, isTrue);
      expect(list[1].kind, CalendarKind.family);
      expect(list.last.kind, CalendarKind.work);
    });

    test('保存用の形と読み込みが一致する', () {
      const c = Category(
        id: 'x',
        name: 'バスケ',
        shared: true,
        color: 0xFF112233,
        order: 3,
      );
      final back = Category.fromMap('x', c.toMap(), shared: true);
      expect(back.name, 'バスケ');
      expect(back.color, 0xFF112233);
      expect(back.order, 3);
    });
  });

  group('表示カレンダー', () {
    test('「すべて」は全部、組み合わせは選んだ種類だけ', () {
      const all = CalendarViewDef(id: 'all', name: 'すべて');
      const sports = CalendarViewDef(
        id: 'v1',
        name: 'バスケ＋空手',
        categoryIds: {'c_basket', 'c_karate'},
      );
      const karateHome = CalendarViewDef(
        id: 'v2',
        name: '空手＋家庭',
        categoryIds: {'c_karate', Category.familyId},
      );
      final basket = _e(category: 'c_basket');
      final karate = _e(category: 'c_karate');
      final home = _e(); // 古い家庭の予定
      final work = _e(kind: CalendarKind.work);

      expect([basket, karate, home, work].every(all.shows), isTrue);
      expect([basket, karate, home, work].where(sports.shows), [
        basket,
        karate,
      ]);
      expect([basket, karate, home, work].where(karateHome.shows), [
        karate,
        home,
      ]);
    });

    test('保存した一覧の先頭には必ず「すべて」がある', () {
      final views = withAllFirst([
        const CalendarViewDef(id: 'v1', name: '空手', categoryIds: {'k'}),
        const CalendarViewDef(id: 'all', name: '古い名前'),
      ], allName: 'すべて');
      expect(views.map((v) => v.name), ['すべて', '空手']);
    });

    test('保存用の形と読み込みが一致する（「すべて」は種類なし）', () {
      const v = CalendarViewDef(
        id: 'v1',
        name: 'バスケ＋空手',
        categoryIds: {'a', 'b'},
      );
      final back = CalendarViewDef.fromMap(v.toMap());
      expect(back.categoryIds, {'a', 'b'});
      expect(
        CalendarViewDef.fromMap(
          const CalendarViewDef(id: 'all', name: 'x').toMap(),
        ).isAll,
        isTrue,
      );
    });

    test('ルーティーンの予定も種類を引き継ぐ', () {
      final r = Routine(
        id: 'r',
        title: '空手',
        weekdays: {DateTime.tuesday},
        categoryId: 'c_karate',
      );
      final e = r.occurrenceOn(DateTime(2026, 11, 10));
      expect(categoryOf(e), 'c_karate');
    });
  });

  group('月のカレンダー（縦スクロール）', () {
    test('6 週間・42 日で、日曜日から始まる', () {
      final days = monthGridDays(DateTime(2026, 11, 1));
      expect(days, hasLength(42));
      expect(days.first, DateTime(2026, 11, 1)); // 2026-11-01 は日曜
      expect(days.first.weekday, DateTime.sunday);
      expect(days.last, DateTime(2026, 12, 12));
    });

    test('月の途中から始まる月は前の月の日曜日から', () {
      final days = monthGridDays(DateTime(2026, 10, 1)); // 10/1 は木曜
      expect(days.first, DateTime(2026, 9, 27));
      expect(days[4], DateTime(2026, 10, 1));
    });

    test('ページ番号と月の行き来（年をまたぐ）', () {
      final base = DateTime(2026, 11, 1);
      expect(monthAt(base, 2), DateTime(2027, 1, 1));
      expect(monthAt(base, -11), DateTime(2025, 12, 1));
      expect(monthOffset(base, DateTime(2027, 1, 15)), 2);
      expect(monthOffset(base, DateTime(2025, 12, 1)), -11);
    });
  });
}
