import 'dart:ui';

import 'models.dart';

/// 予定の種類（家庭・仕事・バスケ・空手 など）。
///
/// [shared] が true なら家族のグループで共有し（予定は families/{id}/events）、
/// false なら本人だけ（予定は users/{uid}/work_events）。
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.shared,
    this.color,
    this.order = 0,
  });

  /// 最初からある 2 つ。名前は画面で言語に合わせて出す。
  static const familyId = 'family';
  static const workId = 'work';

  final String id;
  final String name;
  final bool shared;

  /// 自分だけの種類の予定の色（ARGB の数値）。共有の種類は「誰の予定か」で色分けする。
  final int? color;
  final int order;

  bool get isBuiltIn => id == familyId || id == workId;

  /// 予定の保存場所（共有か本人だけか）。
  CalendarKind get kind => shared ? CalendarKind.family : CalendarKind.work;

  Color get displayColor =>
      color != null ? Color(color!) : (shared ? everyoneColor : workColor);

  Map<String, dynamic> toMap() => {
    'name': name,
    if (color != null) 'color': color,
    'order': order,
  };

  static Category fromMap(String id, Map m, {required bool shared}) => Category(
    id: id,
    name: m['name'] as String? ?? '',
    shared: shared,
    color: (m['color'] as num?)?.toInt(),
    order: (m['order'] as num?)?.toInt() ?? 0,
  );
}

/// 最初からある種類と、家族の種類・自分の種類をまとめた一覧（並び順つき）。
List<Category> mergeCategories({
  required String familyName,
  required String workName,
  Map<String, Category> shared = const {},
  Map<String, Category> private = const {},
}) {
  int byOrder(Category a, Category b) => a.order.compareTo(b.order);
  return [
    Category(id: Category.familyId, name: familyName, shared: true),
    ...(shared.values.toList()..sort(byOrder)),
    Category(id: Category.workId, name: workName, shared: false),
    ...(private.values.toList()..sort(byOrder)),
  ];
}

/// 予定の種類 ID。古い予定（種類なし）は保存場所で決める。
String categoryOf(CalendarEvent e) => e.categoryId?.isNotEmpty == true
    ? e.categoryId!
    : (e.kind == CalendarKind.work ? Category.workId : Category.familyId);

/// 1 枚のカレンダーとして表示する種類の組み合わせ（「バスケ＋空手」など）。
/// [categoryIds] が null なら「すべて」。
class CalendarViewDef {
  const CalendarViewDef({
    required this.id,
    required this.name,
    this.categoryIds,
  });

  static const allId = 'all';

  final String id;
  final String name;
  final Set<String>? categoryIds;

  bool get isAll => categoryIds == null;

  bool shows(CalendarEvent e) =>
      categoryIds == null || categoryIds!.contains(categoryOf(e));

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'categories': categoryIds?.toList(),
  };

  static CalendarViewDef fromMap(Map m) => CalendarViewDef(
    id: m['id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    categoryIds: m['categories'] == null
        ? null
        : {for (final c in m['categories'] as List) c as String},
  );
}

/// まだ自分で作っていない人のための、最初の表示カレンダー（すべて・家庭・仕事）。
List<CalendarViewDef> defaultViews({
  required String allName,
  required String familyName,
  required String workName,
}) => [
  CalendarViewDef(id: CalendarViewDef.allId, name: allName),
  CalendarViewDef(
    id: 'v_family',
    name: familyName,
    categoryIds: const {Category.familyId},
  ),
  CalendarViewDef(
    id: 'v_work',
    name: workName,
    categoryIds: const {Category.workId},
  ),
];

/// 保存した表示カレンダーに「すべて」を必ず先頭に置く。
List<CalendarViewDef> withAllFirst(
  List<CalendarViewDef> saved, {
  required String allName,
}) => [
  CalendarViewDef(id: CalendarViewDef.allId, name: allName),
  ...saved.where((v) => !v.isAll),
];

// ---------------------------------------------------------------------------
// 月のカレンダーの日付
// ---------------------------------------------------------------------------

/// 基準の月からの月数で月を表す（縦スクロールのページ番号に使う）。
DateTime monthAt(DateTime base, int offset) =>
    DateTime(base.year, base.month + offset, 1);

int monthOffset(DateTime base, DateTime month) =>
    (month.year - base.year) * 12 + month.month - base.month;

/// その月の表示に使う 6 週間分（42 日）の日付。日曜日始まり。
List<DateTime> monthGridDays(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  final start = DateTime(
    first.year,
    first.month,
    first.day - first.weekday % 7,
  );
  return [
    for (var i = 0; i < 42; i++)
      DateTime(start.year, start.month, start.day + i),
  ];
}

/// 同じ日か（時刻は見ない）。
bool isSameDay(DateTime? a, DateTime? b) =>
    a != null &&
    b != null &&
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day;
