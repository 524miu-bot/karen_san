import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karen_san/calendar_page.dart';
import 'package:karen_san/models.dart';

final _family = Family(
  id: 'f',
  name: 'わが家',
  inviteCode: 'ABCDEFGH',
  memberIds: const ['mom', 'kid'],
  memberNames: const {'mom': 'ママ', 'kid': 'カレン'},
);

final _day = DateTime(2026, 10, 15);

List<CalendarEvent> _events(int n, {DateTime? on}) => [
      for (var i = 0; i < n; i++)
        CalendarEvent(
          id: '$i',
          title: '予定$i',
          start: (on ?? _day).add(Duration(hours: 9 + i)),
          end: (on ?? _day).add(Duration(hours: 10 + i)),
          allDay: false,
          ownerId: i.isEven ? 'mom' : 'kid',
        ),
    ];

Future<void> _pumpCell(WidgetTester tester, Size size, int eventCount) {
  return tester.pumpWidget(MaterialApp(
    home: Center(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: DayCell(
          day: _day,
          events: _events(eventCount),
          family: _family,
          isToday: false,
          isSelected: false,
          isOutside: false,
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('入りきる数の予定はすべて帯で表示される', (tester) async {
    await _pumpCell(tester, const Size(56, 110), 3);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('予定0'), findsOneWidget);
    expect(find.text('予定2'), findsOneWidget);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('入りきらない予定は「+n」にまとめ、はみ出さない', (tester) async {
    // 高さ 80 なら帯は 3 行分 → 2 件＋「+4」。
    await _pumpCell(tester, const Size(56, 80), 6);
    expect(find.text('予定0'), findsOneWidget);
    expect(find.text('予定1'), findsOneWidget);
    expect(find.text('予定2'), findsNothing);
    expect(find.text('+4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('とても小さいマスでもレイアウトが崩れない', (tester) async {
    await _pumpCell(tester, const Size(40, 30), 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('祝日名は日付の横に出し、予定の行数は減らない', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 56,
          height: 80,
          child: DayCell(
            day: DateTime(2026, 11, 23),
            events: _events(6, on: DateTime(2026, 11, 23)),
            holiday: '勤労感謝の日',
            family: _family,
            isToday: false,
            isSelected: false,
            isOutside: false,
          ),
        ),
      ),
    ));
    expect(find.text('勤労感謝の日'), findsOneWidget);
    // 祝日でない日と同じく、高さ 80 なら帯 2 件＋「+4」。
    expect(find.text('予定0'), findsOneWidget);
    expect(find.text('予定1'), findsOneWidget);
    expect(find.text('予定2'), findsNothing);
    expect(find.text('+4'), findsOneWidget);
    // 祝日名は日付と同じ行にある。
    expect(tester.getCenter(find.text('勤労感謝の日')).dy,
        moreOrLessEquals(tester.getCenter(find.text('23')).dy, epsilon: 2));
    expect(tester.takeException(), isNull);
  });

  test('メンバーごとに違う色、みんなの予定は共通の色', () {
    expect(_family.colorOf('mom'), isNot(_family.colorOf('kid')));
    expect(_family.colorOf(CalendarEvent.everyone), everyoneColor);
  });
}
