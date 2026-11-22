import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karen_san/models.dart';

void main() {
  test('まとめて追加の記録を読む（おかしな行は飛ばす）', () {
    final r = ImportRecord.fromMap('imp1', {
      'createdAt': Timestamp.fromDate(DateTime(2026, 11, 22, 14, 5)),
      'source': 'photo',
      'events': [
        {'k': 'family', 'id': 'a'},
        {'k': 'work', 'id': 'b'},
        {'k': 'family'},
        'おかしな値',
      ],
      'titles': ['練習', '試合'],
      'from': Timestamp.fromDate(DateTime(2026, 11, 1)),
      'to': Timestamp.fromDate(DateTime(2026, 11, 29)),
    });
    expect(r.count, 2);
    expect(r.events[0].kind, CalendarKind.family);
    expect(r.events[1].kind, CalendarKind.work);
    expect(r.events[1].id, 'b');
    expect(r.source, 'photo');
    expect(r.titles, ['練習', '試合']);
    expect(r.createdAt, DateTime(2026, 11, 22, 14, 5));
    expect(r.to, DateTime(2026, 11, 29));
  });

  test('記録が空でも読める', () {
    final r = ImportRecord.fromMap('x', {});
    expect(r.count, 0);
    expect(r.source, 'text');
    expect(r.createdAt, isNull);
  });
}
