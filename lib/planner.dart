import 'package:intl/intl.dart';

import 'holidays.dart';
import 'models.dart';

/// 日付キー（例: 2026-10-19）。端末の時刻で数える。
String dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// ---------------------------------------------------------------------------
// 1 週間のルーティーン
// ---------------------------------------------------------------------------

/// 毎週決まった曜日にある予定。カレンダーには自動で表示され、予定としては保存しない。
class Routine {
  Routine({
    this.id,
    required this.title,
    required this.weekdays,
    this.allDay = false,
    this.startMinutes = 9 * 60,
    this.endMinutes = 10 * 60,
    this.ownerId = '',
    this.note = '',
    this.skipHolidays = false,
    this.skipDates = const {},
    this.kind = CalendarKind.family,
  });

  final String? id;
  final String title;

  /// 曜日（DateTime.monday = 1 〜 DateTime.sunday = 7）。
  final Set<int> weekdays;
  final bool allDay;

  /// 開始・終了の時刻（0:00 からの分）。終了は開始より後。
  final int startMinutes;
  final int endMinutes;

  final String ownerId;
  final String note;

  /// 祝日・休日はお休みにする（学校の予定など）。
  final bool skipHolidays;

  /// 「この日だけ休み」にした日（dateKey の形）。
  final Set<String> skipDates;

  final CalendarKind kind;

  factory Routine.fromMap(
    String id,
    Map<String, dynamic> m, {
    CalendarKind kind = CalendarKind.family,
  }) {
    return Routine(
      id: id,
      title: m['title'] as String? ?? '',
      weekdays: {
        for (final w in (m['weekdays'] as List? ?? const []))
          (w as num).toInt(),
      },
      allDay: m['allDay'] as bool? ?? false,
      startMinutes: (m['startMinutes'] as num?)?.toInt() ?? 9 * 60,
      endMinutes: (m['endMinutes'] as num?)?.toInt() ?? 10 * 60,
      ownerId: m['ownerId'] as String? ?? '',
      note: m['note'] as String? ?? '',
      skipHolidays: m['skipHolidays'] as bool? ?? false,
      skipDates: {
        for (final s in (m['skipDates'] as List? ?? const [])) s as String,
      },
      kind: kind,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'weekdays': weekdays.toList()..sort(),
    'allDay': allDay,
    'startMinutes': startMinutes,
    'endMinutes': endMinutes,
    'ownerId': ownerId,
    'note': note,
    'skipHolidays': skipHolidays,
    'skipDates': skipDates.toList()..sort(),
  };

  Routine copyWith({Set<String>? skipDates}) => Routine(
    id: id,
    title: title,
    weekdays: weekdays,
    allDay: allDay,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
    ownerId: ownerId,
    note: note,
    skipHolidays: skipHolidays,
    skipDates: skipDates ?? this.skipDates,
    kind: kind,
  );

  /// [day] にこのルーティーンがあるか。祝日の判定は日本の祝日を使う。
  bool occursOn(DateTime day) {
    if (!weekdays.contains(day.weekday)) return false;
    if (skipDates.contains(dateKey(day))) return false;
    if (skipHolidays && holidayName(day) != null) return false;
    return true;
  }

  /// [day] の分の予定（カレンダーに出すためのもの）。
  CalendarEvent occurrenceOn(DateTime day) {
    final d = _dayOnly(day);
    return CalendarEvent(
      id: '${id}_${dateKey(d)}',
      title: title,
      start: allDay ? d : d.add(Duration(minutes: startMinutes)),
      end: allDay
          ? DateTime(d.year, d.month, d.day + 1)
          : d.add(Duration(minutes: endMinutes)),
      allDay: allDay,
      note: note,
      ownerId: ownerId,
      kind: kind,
      routineId: id,
    );
  }
}

/// [from] の日から [to] の日の手前までに表示するルーティーンの予定。
List<CalendarEvent> routineOccurrences(
  Iterable<Routine> routines,
  DateTime from,
  DateTime to,
) {
  final result = <CalendarEvent>[];
  for (
    var d = _dayOnly(from);
    d.isBefore(_dayOnly(to));
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    for (final r in routines) {
      if (r.occursOn(d)) result.add(r.occurrenceOn(d));
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// 今週の TODO
// ---------------------------------------------------------------------------

/// 週の始まり（日曜日。カレンダーの並びに合わせる）。
DateTime weekStartOf(DateTime d) {
  final day = _dayOnly(d);
  return DateTime(day.year, day.month, day.day - day.weekday % 7);
}

String weekKeyOf(DateTime d) => dateKey(weekStartOf(d));

/// 今週中にやること。
class Todo {
  Todo({
    this.id,
    required this.title,
    required this.weekKey,
    this.done = false,
    this.ownerId = '',
    this.kind = CalendarKind.family,
  });

  final String? id;
  final String title;

  /// どの週の TODO か（その週の日曜日の dateKey）。
  final String weekKey;
  final bool done;
  final String ownerId;
  final CalendarKind kind;

  factory Todo.fromMap(
    String id,
    Map<String, dynamic> m, {
    CalendarKind kind = CalendarKind.family,
  }) => Todo(
    id: id,
    title: m['title'] as String? ?? '',
    weekKey: m['weekKey'] as String? ?? '',
    done: m['done'] as bool? ?? false,
    ownerId: m['ownerId'] as String? ?? '',
    kind: kind,
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'weekKey': weekKey,
    'done': done,
    'ownerId': ownerId,
  };
}

/// [weekKey] の週に表示する TODO。
/// その週のもの（終わったものも含む）と、前の週から持ち越した終わっていないもの。
/// 持ち越しを先に、終わったものを最後に並べる。
({List<Todo> carried, List<Todo> thisWeek}) todosForWeek(
  Iterable<Todo> todos,
  String weekKey,
) {
  final carried = <Todo>[];
  final thisWeek = <Todo>[];
  final seen = <String>{};
  for (final t in todos) {
    if (t.id != null && !seen.add('${t.kind.name}/${t.id}')) continue;
    if (t.weekKey == weekKey) {
      thisWeek.add(t);
    } else if (!t.done && t.weekKey.compareTo(weekKey) < 0) {
      carried.add(t);
    }
  }
  carried.sort((a, b) => a.weekKey.compareTo(b.weekKey));
  thisWeek.sort((a, b) => (a.done ? 1 : 0).compareTo(b.done ? 1 : 0));
  return (carried: carried, thisWeek: thisWeek);
}
