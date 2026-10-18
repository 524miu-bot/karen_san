import 'package:flutter_test/flutter_test.dart';

import 'package:karen_san/models.dart';
import 'package:karen_san/planner.dart';

void main() {
  group('ルーティーン', () {
    final school = Routine(
      id: 'r1',
      title: '学校',
      weekdays: {
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
      },
      startMinutes: 8 * 60 + 15,
      endMinutes: 15 * 60,
      skipHolidays: true,
    );

    test('決めた曜日だけに表示される', () {
      // 2026-10-19 は月曜日、10-24 は土曜日
      expect(school.occursOn(DateTime(2026, 10, 19)), isTrue);
      expect(school.occursOn(DateTime(2026, 10, 23)), isTrue);
      expect(school.occursOn(DateTime(2026, 10, 24)), isFalse);
      expect(school.occursOn(DateTime(2026, 10, 25)), isFalse);
    });

    test('「祝日はお休み」なら祝日・振替休日には出ない', () {
      // 2026-11-03（火）文化の日、2026-11-23（月）勤労感謝の日
      expect(school.occursOn(DateTime(2026, 11, 3)), isFalse);
      expect(school.occursOn(DateTime(2026, 11, 23)), isFalse);
      // 2026-05-06（水）振替休日
      expect(school.occursOn(DateTime(2026, 5, 6)), isFalse);
      // 七五三（11-16 は月曜）は休みではない
      expect(school.occursOn(DateTime(2026, 11, 16)), isTrue);
      final work = Routine(id: 'r2', title: '出勤', weekdays: {DateTime.tuesday});
      expect(work.occursOn(DateTime(2026, 11, 3)), isTrue);
    });

    test('「この日だけ休み」にした日には出ない', () {
      final r = school.copyWith(skipDates: {'2026-10-21'});
      expect(r.occursOn(DateTime(2026, 10, 21)), isFalse);
      expect(r.occursOn(DateTime(2026, 10, 22)), isTrue);
    });

    test('その日の時刻で予定になり、ルーティーンとわかる', () {
      final e = school.occurrenceOn(DateTime(2026, 10, 19, 23, 59));
      expect(e.start, DateTime(2026, 10, 19, 8, 15));
      expect(e.end, DateTime(2026, 10, 19, 15));
      expect(e.isRoutine, isTrue);
      expect(e.routineId, 'r1');
      expect(e.id, 'r1_2026-10-19');
    });

    test('終日のルーティーンは翌日 0:00 まで', () {
      final r = Routine(
        id: 'r3',
        title: '給食なし',
        weekdays: {DateTime.wednesday},
        allDay: true,
      );
      final e = r.occurrenceOn(DateTime(2026, 10, 21));
      expect(e.start, DateTime(2026, 10, 21));
      expect(e.end, DateTime(2026, 10, 22));
      expect(e.occursOn(DateTime(2026, 10, 22)), isFalse);
    });

    test('期間内の日ごとに表示する予定をまとめて作る', () {
      final list = routineOccurrences(
        [school],
        DateTime(2026, 11, 1), // 日曜
        DateTime(2026, 11, 8),
      );
      // 11/2〜11/6 の平日 5 日のうち、11/3 は文化の日
      expect(list.map((e) => e.start.day), [2, 4, 5, 6]);
    });

    test('保存用の形と読み込みが一致する', () {
      final r = Routine.fromMap('x', school.toMap(), kind: CalendarKind.work);
      expect(r.title, '学校');
      expect(r.weekdays, school.weekdays);
      expect(r.startMinutes, 8 * 60 + 15);
      expect(r.skipHolidays, isTrue);
      expect(r.kind, CalendarKind.work);
    });
  });

  group('今週の TODO', () {
    test('週は日曜日から始まる', () {
      expect(weekKeyOf(DateTime(2026, 10, 18)), '2026-10-18'); // 日
      expect(weekKeyOf(DateTime(2026, 10, 19)), '2026-10-18'); // 月
      expect(weekKeyOf(DateTime(2026, 10, 24, 23)), '2026-10-18'); // 土
      expect(weekKeyOf(DateTime(2026, 10, 25)), '2026-10-25'); // 次の日
      expect(weekKeyOf(DateTime(2027, 1, 1)), '2026-12-27'); // 年をまたぐ
    });

    test('今週のものと、前の週から持ち越した未完了のものを表示する', () {
      final todos = [
        Todo(id: 'a', title: '今週', weekKey: '2026-10-18'),
        Todo(id: 'b', title: '今週・済', weekKey: '2026-10-18', done: true),
        Todo(id: 'c', title: '先週・未', weekKey: '2026-10-11'),
        Todo(id: 'd', title: '先週・済', weekKey: '2026-10-11', done: true),
        Todo(id: 'e', title: '来週', weekKey: '2026-10-25'),
        // 同じものが 2 回届いても 1 回だけ
        Todo(id: 'c', title: '先週・未', weekKey: '2026-10-11'),
      ];
      final r = todosForWeek(todos, '2026-10-18');
      expect(r.carried.map((t) => t.title), ['先週・未']);
      expect(r.thisWeek.map((t) => t.title), ['今週', '今週・済']);
    });

    test('家庭と仕事で同じ ID でも別のものとして扱う', () {
      final r = todosForWeek([
        Todo(id: 'a', title: '家庭', weekKey: '2026-10-18'),
        Todo(
          id: 'a',
          title: '仕事',
          weekKey: '2026-10-18',
          kind: CalendarKind.work,
        ),
      ], '2026-10-18');
      expect(r.thisWeek, hasLength(2));
    });
  });
}
