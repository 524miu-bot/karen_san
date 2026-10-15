import 'package:cloud_firestore/cloud_firestore.dart';

/// 予定を共有するグループ（家族など）。
class Family {
  Family({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.memberIds,
    required this.memberNames,
  });

  final String id;
  final String name;
  final String inviteCode;
  final List<String> memberIds;
  final Map<String, String> memberNames;

  factory Family.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Family(
      id: doc.id,
      name: d['name'] as String? ?? '',
      inviteCode: d['inviteCode'] as String? ?? '',
      memberIds: List<String>.from(d['memberIds'] as List? ?? const []),
      memberNames: Map<String, String>.from(d['memberNames'] as Map? ?? const {}),
    );
  }
}

/// カレンダーの予定。
class CalendarEvent {
  CalendarEvent({
    this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    this.note = '',
    this.createdBy = '',
    this.createdByName = '',
  });

  final String? id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String note;
  final String createdBy;
  final String createdByName;

  factory CalendarEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return CalendarEvent(
      id: doc.id,
      title: d['title'] as String? ?? '',
      start: (d['start'] as Timestamp).toDate(),
      end: (d['end'] as Timestamp).toDate(),
      allDay: d['allDay'] as bool? ?? false,
      note: d['note'] as String? ?? '',
      createdBy: d['createdBy'] as String? ?? '',
      createdByName: d['createdByName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'start': Timestamp.fromDate(start),
        'end': Timestamp.fromDate(end),
        'allDay': allDay,
        'note': note,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// この予定が [day] の日にかかっているか。
  bool occursOn(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final startDay = DateTime(start.year, start.month, start.day);
    if (startDay == dayStart) return true;
    return start.isBefore(dayEnd) && end.isAfter(dayStart);
  }
}
