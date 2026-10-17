import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import 'event_editor_page.dart';
import 'family_settings_page.dart';
import 'holidays.dart';
import 'models.dart';
import 'repository.dart';
import 'x_archive/x_archive.dart';

const _sundayColor = Color(0xFFD32F2F);
const _saturdayColor = Color(0xFF1976D2);

/// 曜日の見出し用（日曜は赤、土曜は青）。
Color? _weekdayColor(DateTime day) => switch (day.weekday) {
  DateTime.sunday => _sundayColor,
  DateTime.saturday => _saturdayColor,
  _ => null,
};

/// 日付の色。祝日・休日は曜日にかかわらず赤。
Color? _dayColor(DateTime day) =>
    holidayName(day) != null ? _sundayColor : _weekdayColor(day);

/// 1 日の中での並び順：複数日・終日の予定を上に、時間指定は開始順。
int _compareEvents(CalendarEvent a, CalendarEvent b) {
  int rank(CalendarEvent e) =>
      e.end.difference(e.start) > const Duration(days: 1)
      ? 0
      : (e.allDay ? 1 : 2);
  final r = rank(a).compareTo(rank(b));
  if (r != 0) return r;
  final s = a.start.compareTo(b.start);
  if (s != 0) return s;
  return (a.id ?? '').compareTo(b.id ?? '');
}

/// 家族で共有するカレンダー（ログイン後のホーム画面）。
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.user, required this.familyId});

  final User user;
  final String familyId;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _focusedDay = _today();
  late DateTime _selectedDay = _today();
  late Stream<List<CalendarEvent>> _eventsStream = _streamFor(_focusedDay);
  late final Stream<Family> _familyStream = Repository.instance.watchFamily(
    widget.familyId,
  );
  List<CalendarEvent> _events = const [];

  /// 取り込んだ X の投稿（本人のものだけ）。
  late Stream<Map<String, List<XPost>>> _xStream = _xStreamFor(
    DateTime(_focusedDay.year, _focusedDay.month - 1, 1),
    days: 100,
  );
  Map<String, List<XPost>> _xPosts = const {};
  bool _showX = true;

  Stream<Map<String, List<XPost>>> _xStreamFor(
    DateTime from, {
    required int days,
  }) {
    return Repository.instance.watchXPosts(
      widget.user.uid,
      from: from,
      to: DateTime(from.year, from.month, from.day + days),
    );
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 表示月の前後 1 か月分を読み込む（月をまたぐ予定も表示するため）。
  Stream<List<CalendarEvent>> _streamFor(DateTime month) {
    return Repository.instance.watchEvents(
      widget.familyId,
      from: DateTime(month.year, month.month - 1, 1),
      to: DateTime(month.year, month.month + 2, 1),
    );
  }

  List<CalendarEvent> _eventsOn(DateTime day) =>
      _events.where((e) => e.occursOn(day)).toList()..sort(_compareEvents);

  void _onPageChanged(DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      _eventsStream = _streamFor(focusedDay);
      _xStream = _xStreamFor(
        DateTime(focusedDay.year, focusedDay.month - 1, 1),
        days: 100,
      );
    });
  }

  void _openEditor(Family family, {CalendarEvent? event, DateTime? day}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventEditorPage(
          family: family,
          initialDay: day ?? _selectedDay,
          event: event,
        ),
      ),
    );
  }

  /// 日付をタップしたときに、その日の予定を下から表示する。
  void _showDay(Family family, DateTime day) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (sheetContext) => StreamBuilder<List<CalendarEvent>>(
        stream: _streamFor(day),
        initialData: _events,
        builder: (context, snap) {
          final dayEvents =
              (snap.data ?? const <CalendarEvent>[])
                  .where((e) => e.occursOn(day))
                  .toList()
                ..sort(_compareEvents);
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('M月d日(E)', 'ja').format(day),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: _dayColor(day)),
                            ),
                            if (holidayName(day) case final name?)
                              Text(
                                name,
                                style: const TextStyle(color: _sundayColor),
                              ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _openEditor(family, day: day);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('予定を追加'),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: StreamBuilder<Map<String, List<XPost>>>(
                    stream: _xStreamFor(day, days: 1),
                    initialData: {
                      dayKey(day): _xPosts[dayKey(day)] ?? const [],
                    },
                    builder: (context, xSnap) {
                      final dayPosts = xSnap.data?[dayKey(day)];
                      final posts = _showX && dayPosts != null
                          ? dayPosts
                          : const <XPost>[];
                      return ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          if (dayEvents.isEmpty)
                            const Padding(
                              padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
                              child: Text('予定はありません'),
                            ),
                          for (final e in dayEvents)
                            _EventTile(
                              event: e,
                              family: family,
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _openEditor(family, event: e);
                              },
                            ),
                          if (posts.isNotEmpty) ...[
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                              child: Text(
                                '𝕏 この日の投稿（${posts.length}）',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            for (final p in posts) _XPostTile(post: p),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFamily(Family family) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            FamilySettingsPage(familyId: family.id, uid: widget.user.uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Family>(
      stream: _familyStream,
      builder: (context, familySnap) {
        final family = familySnap.data;
        return StreamBuilder<Map<String, List<XPost>>>(
          stream: _xStream,
          builder: (context, xSnap) {
            // 取り込みがない・読めないときは空として扱う（予定の表示には影響させない）
            _xPosts = xSnap.data ?? const {};
            return _buildScaffold(family, familySnap);
          },
        );
      },
    );
  }

  Widget _buildScaffold(Family? family, AsyncSnapshot<Family> familySnap) {
    return Scaffold(
      appBar: AppBar(
        title: Text(family?.name ?? 'カレンさん'),
        actions: [
          if (_xPosts.isNotEmpty)
            IconButton(
              tooltip: _showX ? 'X の投稿を隠す' : 'X の投稿を表示',
              isSelected: _showX,
              onPressed: () => setState(() => _showX = !_showX),
              icon: Text(
                '𝕏',
                style: TextStyle(
                  fontSize: 18,
                  color: _showX ? null : Theme.of(context).disabledColor,
                ),
              ),
            ),
          if (family != null)
            IconButton(
              tooltip: 'メンバー・予定者',
              icon: const Icon(Icons.group_add_outlined),
              onPressed: () => _showFamily(family),
            ),
          IconButton(
            tooltip: 'ログアウト',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      floatingActionButton: family == null
          ? null
          : FloatingActionButton(
              tooltip: '予定を追加',
              onPressed: () => _openEditor(family),
              child: const Icon(Icons.add),
            ),
      body: familySnap.hasError
          ? Center(child: Text('読み込めませんでした：${familySnap.error}'))
          : family == null
          ? const Center(child: CircularProgressIndicator())
          : _buildCalendar(family),
    );
  }

  Widget _buildCalendar(Family family) {
    return StreamBuilder<List<CalendarEvent>>(
      stream: _eventsStream,
      builder: (context, snap) {
        _events = snap.data ?? const <CalendarEvent>[];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                if (snap.hasError)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('予定を読み込めませんでした：${snap.error}'),
                  ),
                Expanded(
                  child: TableCalendar<CalendarEvent>(
                    locale: 'ja_JP',
                    firstDay: DateTime(2000),
                    lastDay: DateTime(holidayLastYear, 12, 31),
                    focusedDay: _focusedDay,
                    shouldFillViewport: true,
                    sixWeekMonthsEnforced: true,
                    startingDayOfWeek: StartingDayOfWeek.sunday,
                    availableCalendarFormats: const {CalendarFormat.month: '月'},
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      titleTextFormatter: (date, locale) =>
                          DateFormat('y年M月', 'ja').format(date),
                      titleTextStyle: Theme.of(context).textTheme.titleLarge!,
                    ),
                    daysOfWeekHeight: 24,
                    selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                    onDaySelected: (selected, focused) {
                      final day = DateTime(
                        selected.year,
                        selected.month,
                        selected.day,
                      );
                      setState(() {
                        _selectedDay = day;
                        _focusedDay = focused;
                      });
                      _showDay(family, day);
                    },
                    onDayLongPressed: (selected, _) => _openEditor(
                      family,
                      day: DateTime(
                        selected.year,
                        selected.month,
                        selected.day,
                      ),
                    ),
                    onPageChanged: _onPageChanged,
                    calendarBuilders: CalendarBuilders(
                      dowBuilder: (context, day) => Center(
                        child: Text(
                          DateFormat.E('ja').format(day),
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                _weekdayColor(day) ??
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      prioritizedBuilder: (context, day, focusedDay) {
                        final d = DateTime(day.year, day.month, day.day);
                        return DayCell(
                          day: d,
                          events: _eventsOn(d),
                          holiday: holidayName(d),
                          xCount: _showX ? _xPosts[dayKey(d)]?.length ?? 0 : 0,
                          family: family,
                          isToday: isSameDay(d, DateTime.now()),
                          isSelected: isSameDay(d, _selectedDay),
                          isOutside: d.month != focusedDay.month,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// カレンダーの 1 マス。日付の下に、その日の予定を色付きの帯で並べる。
class DayCell extends StatelessWidget {
  const DayCell({
    super.key,
    required this.day,
    required this.events,
    required this.family,
    required this.isToday,
    required this.isSelected,
    required this.isOutside,
    this.holiday,
    this.xCount = 0,
  });

  final DateTime day;
  final List<CalendarEvent> events;

  /// 祝日・休日の名前（なければ null）。
  final String? holiday;

  /// その日の X の投稿数（取り込んだ人だけに表示）。
  final int xCount;
  final Family family;
  final bool isToday;
  final bool isSelected;
  final bool isOutside;

  static const _chipHeight = 16.0;
  static const _chipGap = 2.0;
  static const _headerHeight = 22.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final numberColor = holiday != null
        ? _sundayColor
        : _weekdayColor(day) ?? scheme.onSurface;
    return Opacity(
      opacity: isOutside ? 0.45 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primaryContainer.withValues(alpha: 0.4)
              : null,
          border: Border(
            top: BorderSide(color: scheme.outlineVariant, width: 0.5),
            left: BorderSide(color: scheme.outlineVariant, width: 0.5),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 祝日名は日付の横に小さく出すので、予定の行数は減らさない。
            final room = constraints.maxHeight - _headerHeight;
            final fit = room <= 0
                ? 0
                : ((room + _chipGap) / (_chipHeight + _chipGap)).floor();
            // 入りきらないときは最後の 1 行を「+n」にする。
            final shown = events.length <= fit
                ? events.length
                : (fit - 1).clamp(0, fit);
            // 帯を 1 行も置けないほど小さいマスでは「+n」も出さない。
            final hidden = fit == 0 ? 0 : events.length - shown;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _headerHeight,
                  child: Row(
                    children: [
                      const SizedBox(width: 1),
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: isToday
                            ? BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday ? FontWeight.bold : null,
                            color: isToday ? scheme.onPrimary : numberColor,
                          ),
                        ),
                      ),
                      if (holiday != null)
                        Expanded(
                          child: Text(
                            holiday!,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            softWrap: false,
                            style: const TextStyle(
                              fontSize: 8,
                              height: 1.1,
                              color: _sundayColor,
                            ),
                          ),
                        ),
                      if (holiday == null && xCount > 0) const Spacer(),
                      if (xCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Text(
                            '𝕏$xCount',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 8,
                              height: 1.1,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                for (final e in events.take(shown))
                  Padding(
                    padding: const EdgeInsets.only(bottom: _chipGap),
                    child: _EventChip(event: e, day: day, family: family),
                  ),
                if (hidden > 0)
                  SizedBox(
                    height: _chipHeight,
                    child: Center(
                      child: Text(
                        '+$hidden',
                        style: TextStyle(
                          fontSize: 10,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// マスの中の予定 1 件分の帯。複数日の予定はマスをまたいでつながって見えるようにする。
class _EventChip extends StatelessWidget {
  const _EventChip({
    required this.event,
    required this.day,
    required this.family,
  });

  final CalendarEvent event;
  final DateTime day;
  final Family family;

  @override
  Widget build(BuildContext context) {
    final color = family.colorOf(event.owner);
    final isFirstDay = isSameDay(event.start, day);
    final nextDay = DateTime(day.year, day.month, day.day + 1);
    final isLastDay = !event.end.isAfter(nextDay);
    // 帯が続いている日は、週の始め（日曜）だけタイトルを出し直す。
    final showTitle = isFirstDay || day.weekday == DateTime.sunday;
    const radius = Radius.circular(3);
    return Container(
      height: DayCell._chipHeight,
      margin: EdgeInsets.only(
        left: isFirstDay ? 2 : 0,
        right: isLastDay ? 2 : 0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.horizontal(
          left: isFirstDay ? radius : Radius.zero,
          right: isLastDay ? radius : Radius.zero,
        ),
      ),
      child: showTitle
          ? Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: const TextStyle(
                fontSize: 10,
                height: 1.2,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            )
          : null,
    );
  }
}

/// 日付をタップしたときの一覧の 1 行。
class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.family,
    required this.onTap,
  });

  final CalendarEvent event;
  final Family family;
  final VoidCallback onTap;

  String _timeText() {
    if (event.allDay) {
      final lastDay = event.end.subtract(const Duration(days: 1));
      if (isSameDay(event.start, lastDay)) return '終日';
      return '${DateFormat('M/d').format(event.start)}〜${DateFormat('M/d').format(lastDay)}';
    }
    final sameDay = isSameDay(event.start, event.end);
    final endFmt = sameDay ? DateFormat('H:mm') : DateFormat('M/d H:mm');
    return '${DateFormat('H:mm').format(event.start)}〜${endFmt.format(event.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final color = family.colorOf(event.owner);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_timeText()}   ${family.nameOf(event.owner)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

/// 日付をタップしたときの一覧に出す X の投稿 1 件。押すと X で開く。
class _XPostTile extends StatelessWidget {
  const _XPostTile({required this.post});

  final XPost post;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall;
    return InkWell(
      onTap: () => launchUrl(post.url, mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Text(
                DateFormat('H:mm').format(post.postedAt.toLocal()),
                style: muted,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.text.isEmpty ? '（本文なし）' : post.text),
                  const SizedBox(height: 2),
                  Text(
                    [post.kind.label, if (post.hasMedia) '画像あり'].join('・'),
                    style: muted,
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, size: 16),
          ],
        ),
      ),
    );
  }
}
