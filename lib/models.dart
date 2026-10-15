import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// メンバーが選べる色。色を選んでいないメンバーには参加順に割り当てる。
/// 予定の帯に白い文字を載せるので、濃いめの色にしている。
const memberPalette = <Color>[
  Color(0xFFE53935), // 赤
  Color(0xFF1E88E5), // 青
  Color(0xFF43A047), // 緑
  Color(0xFFF57C00), // オレンジ
  Color(0xFF8E24AA), // 紫
  Color(0xFF00897B), // 青緑
  Color(0xFFD81B60), // ピンク
  Color(0xFF6D4C41), // 茶
];

/// 「みんなの予定」の色。
const everyoneColor = Color(0xFF546E7A);

/// 予定を共有するグループ（家族など）。
class Family {
  Family({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.memberIds,
    required this.memberNames,
    this.memberColors = const {},
  });

  final String id;
  final String name;
  final String inviteCode;
  final List<String> memberIds;
  final Map<String, String> memberNames;

  /// メンバーが自分で選んだ色（ARGB の数値）。
  final Map<String, int> memberColors;

  factory Family.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Family(
      id: doc.id,
      name: d['name'] as String? ?? '',
      inviteCode: d['inviteCode'] as String? ?? '',
      memberIds: List<String>.from(d['memberIds'] as List? ?? const []),
      memberNames: Map<String, String>.from(d['memberNames'] as Map? ?? const {}),
      memberColors: (d['memberColors'] as Map? ?? const {})
          .map((k, v) => MapEntry(k as String, (v as num).toInt())),
    );
  }

  String nameOf(String ownerId) {
    if (ownerId == CalendarEvent.everyone) return 'みんな';
    return memberNames[ownerId] ?? '（退出したメンバー）';
  }

  Color colorOf(String ownerId) {
    if (ownerId == CalendarEvent.everyone) return everyoneColor;
    final chosen = memberColors[ownerId];
    if (chosen != null) return Color(chosen);
    final index = memberIds.indexOf(ownerId);
    if (index < 0) return everyoneColor;
    return memberPalette[index % memberPalette.length];
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
    this.ownerId = '',
  });

  /// [ownerId] がこの値なら「みんなの予定」。
  static const everyone = 'everyone';

  final String? id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String note;
  final String createdBy;
  final String createdByName;

  /// 誰の予定か（メンバーの uid か [everyone]）。
  final String ownerId;

  /// 誰の予定か。古い予定（[ownerId] なし）は登録した人の予定とみなす。
  String get owner => ownerId.isNotEmpty ? ownerId : createdBy;

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
      ownerId: d['ownerId'] as String? ?? '',
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
        'ownerId': ownerId,
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
