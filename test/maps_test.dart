import 'package:flutter_test/flutter_test.dart';

import 'package:karen_san/maps.dart';
import 'package:karen_san/models.dart';
import 'package:karen_san/planner.dart';

void main() {
  test('地図の URL：日本語の場所や記号も正しく渡る', () {
    final g = googleMapsUrl('〇〇小学校 体育館 & 正門');
    expect(g.host, 'www.google.com');
    expect(g.path, '/maps/search/');
    expect(g.queryParameters['api'], '1');
    expect(g.queryParameters['query'], '〇〇小学校 体育館 & 正門');
    expect(appleMapsUrl('〇〇駅 北口').queryParameters['q'], '〇〇駅 北口');
  });

  test('予定とルーティーンに場所を保存でき、ルーティーンの予定にも引き継ぐ', () {
    final e = CalendarEvent(
      title: '練習試合',
      start: DateTime(2026, 11, 14, 9),
      end: DateTime(2026, 11, 14, 12),
      allDay: false,
      location: '市民体育館',
    );
    expect(e.toMap()['location'], '市民体育館');

    final r = Routine(
      id: 'r',
      title: 'バスケ練習',
      weekdays: {DateTime.saturday},
      location: '〇〇小学校 体育館',
    );
    expect(Routine.fromMap('r', r.toMap()).location, '〇〇小学校 体育館');
    expect(r.occurrenceOn(DateTime(2026, 11, 14)).location, '〇〇小学校 体育館');
  });
}
