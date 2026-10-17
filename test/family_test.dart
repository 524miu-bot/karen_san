import 'package:flutter_test/flutter_test.dart';

import 'package:karen_san/models.dart';

Family _family({Map<String, Person> people = const {}}) => Family(
  id: 'f',
  name: 'わが家',
  inviteCode: 'ABCDEFGH',
  memberIds: const ['mom'],
  memberNames: const {'mom': 'ママ'},
  people: people,
);

void main() {
  test('予定者はメンバーのあと、追加した順に並び、最後が「みんな」', () {
    final f = _family(
      people: {
        'p_b': Person(id: 'p_b', name: '弟', order: 2),
        'p_a': Person(id: 'p_a', name: 'カレン', order: 1),
      },
    );
    expect(f.ownerIds, ['mom', 'p_a', 'p_b', CalendarEvent.everyone]);
    expect(f.nameOf('p_a'), 'カレン');
    expect(f.nameOf(CalendarEvent.everyone), 'みんな');
  });

  test('予定者の色は選んだ色、選んでいなければメンバーと重ならない色', () {
    final f = _family(
      people: {
        'p_a': Person(id: 'p_a', name: 'カレン', order: 1),
        'p_b': Person(id: 'p_b', name: '弟', order: 2, color: 0xFF000000),
      },
    );
    expect(f.colorOf('p_a'), isNot(f.colorOf('mom')));
    expect(f.colorOf('p_a'), memberPalette[1]);
    expect(f.colorOf('p_b').toARGB32(), 0xFF000000);
  });

  test('削除された人の予定は「（いなくなった人）」で灰色', () {
    final f = _family();
    expect(f.nameOf('p_gone'), '（いなくなった人）');
    expect(f.colorOf('p_gone'), everyoneColor);
  });
}
