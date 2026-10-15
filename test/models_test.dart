import 'package:flutter_test/flutter_test.dart';

import 'package:karen_san/models.dart';

CalendarEvent _event(DateTime start, DateTime end, {bool allDay = false}) =>
    CalendarEvent(title: 't', start: start, end: end, allDay: allDay);

void main() {
  group('CalendarEvent.occursOn', () {
    test('時間指定の予定はその日だけに表示される', () {
      final e = _event(DateTime(2026, 10, 15, 10), DateTime(2026, 10, 15, 11));
      expect(e.occursOn(DateTime(2026, 10, 15)), isTrue);
      expect(e.occursOn(DateTime(2026, 10, 14)), isFalse);
      expect(e.occursOn(DateTime(2026, 10, 16)), isFalse);
    });

    test('終日の予定は翌日 0:00 終了でも翌日には表示されない', () {
      final e = _event(DateTime(2026, 10, 15), DateTime(2026, 10, 16),
          allDay: true);
      expect(e.occursOn(DateTime(2026, 10, 15)), isTrue);
      expect(e.occursOn(DateTime(2026, 10, 16)), isFalse);
    });

    test('複数日の予定は期間中の毎日に表示される', () {
      final e = _event(DateTime(2026, 10, 30), DateTime(2026, 11, 2),
          allDay: true);
      expect(e.occursOn(DateTime(2026, 10, 29)), isFalse);
      expect(e.occursOn(DateTime(2026, 10, 30)), isTrue);
      expect(e.occursOn(DateTime(2026, 10, 31)), isTrue);
      expect(e.occursOn(DateTime(2026, 11, 1)), isTrue);
      expect(e.occursOn(DateTime(2026, 11, 2)), isFalse);
    });

    test('日をまたぐ夜の予定は両方の日に表示される', () {
      final e = _event(DateTime(2026, 10, 15, 22), DateTime(2026, 10, 16, 1));
      expect(e.occursOn(DateTime(2026, 10, 15)), isTrue);
      expect(e.occursOn(DateTime(2026, 10, 16)), isTrue);
    });
  });
}
