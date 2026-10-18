import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import 'event_editor_page.dart';
import 'planner.dart';
import 'routine_page.dart';
import 'streams.dart';
import 'holidays.dart';
import 'l10n.dart';
import 'models.dart';
import 'oshi.dart';
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
Color? _dayColor(DateTime day, {required bool isHoliday}) =>
    isHoliday ? _sundayColor : _weekdayColor(day);

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

/// カレンダーに表示する範囲。
enum CalendarView { all, family, work }

/// 予定の色。仕事の予定は仕事の色、家庭の予定は誰の予定かで色分けする。
Color eventColor(Family family, CalendarEvent e) =>
    e.kind == CalendarKind.work ? workColor : family.colorOf(e.owner);

/// 家庭（家族で共有）と仕事（本人だけ）をまとめて表示するカレンダー。
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
  CalendarView _view = CalendarView.all;

  late final Place _place = Place(
    familyId: widget.familyId,
    uid: widget.user.uid,
  );

  bool _isVisible(CalendarEvent e) => switch (_view) {
    CalendarView.all => true,
    CalendarView.family => e.kind == CalendarKind.family,
    CalendarView.work => e.kind == CalendarKind.work,
  };

  /// 取り込んだ X の投稿（本人のものだけ）。
  late Stream<Map<String, List<XPost>>> _xStream = _xStreamFor(
    DateTime(_focusedDay.year, _focusedDay.month - 1, 1),
    days: 100,
  );
  Map<String, List<XPost>> _xPosts = const {};
  bool _showX = true;

  /// 推し（本人だけの設定）。日付を押したときに X 検索のボタンを出す。
  late final StreamSubscription<List<Oshi>> _oshiSub = Repository.instance
      .watchOshi(widget.user.uid)
      .listen((list) => setState(() => _oshi = list), onError: (_) {});
  List<Oshi> _oshi = const [];

  @override
  void initState() {
    super.initState();
    _oshiSub; // 読み込みを始める
  }

  @override
  void dispose() {
    _oshiSub.cancel();
    super.dispose();
  }

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
  /// 家庭・仕事の予定と、家庭・仕事のルーティーンをまとめる。
  Stream<List<CalendarEvent>> _streamFor(DateTime month) {
    final from = DateTime(month.year, month.month - 1, 1);
    final to = DateTime(month.year, month.month + 2, 1);
    final repo = Repository.instance;
    Stream<List<CalendarEvent>> routines(CalendarKind kind) => repo
        .watchRoutines(_place, kind)
        .map((rs) => routineOccurrences(rs, from, to));
    return combineLatestLists([
      repo.watchEvents(_place, CalendarKind.family, from: from, to: to),
      repo.watchEvents(_place, CalendarKind.work, from: from, to: to),
      routines(CalendarKind.family),
      routines(CalendarKind.work),
    ]);
  }

  List<CalendarEvent> _eventsOn(DateTime day) =>
      _events.where((e) => _isVisible(e) && e.occursOn(day)).toList()
        ..sort(_compareEvents);

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
    if (event != null && event.isRoutine) {
      _showRoutineActions(family, event);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventEditorPage(
          family: family,
          initialDay: day ?? _selectedDay,
          event: event,
          // 「仕事」だけを表示しているときは、新しい予定も仕事にする
          initialKind: _view == CalendarView.work
              ? CalendarKind.work
              : CalendarKind.family,
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
                  .where((e) => _isVisible(e) && e.occursOn(day))
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
                              DateFormat.MMMEd(context.localeName).format(day),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: _dayColor(
                                      day,
                                      isHoliday:
                                          localizedHolidayName(context, day) !=
                                          null,
                                    ),
                                  ),
                            ),
                            if (localizedHolidayName(context, day)
                                case final name?)
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
                        label: Text(context.l10n.addEvent),
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
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                20,
                                24,
                              ),
                              child: Text(context.l10n.noEvents),
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
                                context.l10n.xPostsOfDay(posts.length),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            for (final p in posts) _XPostTile(post: p),
                          ],
                          if (_oshi.isNotEmpty) ...[
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                              child: Text(
                                context.l10n.oshiPostsOfDay,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            for (final o in _oshi)
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                leading: const Icon(Icons.favorite_outline),
                                title: Text(o.label),
                                subtitle: Text(context.l10n.viewOnX),
                                trailing: const Icon(
                                  Icons.open_in_new,
                                  size: 16,
                                ),
                                onTap: () => launchUrl(
                                  o.searchUrl(day),
                                  mode: LaunchMode.externalApplication,
                                ),
                              ),
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

  /// ルーティーンの予定を押したとき：その日だけ休みにするか、ルーティーンを編集する。
  Future<void> _showRoutineActions(Family family, CalendarEvent event) async {
    final routine = await Repository.instance.getRoutine(
      _place,
      event.kind,
      event.routineId!,
    );
    if (routine == null || !mounted) return;
    final day = DateTime(event.start.year, event.start.month, event.start.day);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.repeat),
              title: Text(routine.title),
              subtitle: Text(context.l10n.routineLabel),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.event_busy_outlined),
              title: Text(
                context.l10n.skipThisDay(
                  DateFormat.MMMEd(context.localeName).format(day),
                ),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                await Repository.instance.skipRoutineOn(_place, routine, day);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(context.l10n.editRoutine),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RoutineEditorPage(
                      family: family,
                      place: _place,
                      routine: routine,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
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
        title: Text(family?.name ?? context.l10n.appTitle),
        actions: [
          if (_xPosts.isNotEmpty)
            IconButton(
              tooltip: _showX
                  ? context.l10n.hideXPosts
                  : context.l10n.showXPosts,
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
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SegmentedButton<CalendarView>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: CalendarView.all,
                  label: Text(context.l10n.viewAll),
                ),
                ButtonSegment(
                  value: CalendarView.family,
                  icon: const Icon(Icons.home_outlined, size: 18),
                  label: Text(context.l10n.family),
                ),
                ButtonSegment(
                  value: CalendarView.work,
                  icon: const Icon(Icons.work_outline, size: 18),
                  label: Text(context.l10n.work),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
          ),
        ),
      ),
      floatingActionButton: family == null
          ? null
          : FloatingActionButton(
              tooltip: context.l10n.addEvent,
              onPressed: () => _openEditor(family),
              child: const Icon(Icons.add),
            ),
      body: familySnap.hasError
          ? Center(child: Text(context.l10n.loadFailed('${familySnap.error}')))
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
                    child: Text(context.l10n.eventsLoadFailed('${snap.error}')),
                  ),
                Expanded(
                  child: TableCalendar<CalendarEvent>(
                    locale: context.localeName,
                    firstDay: DateTime(2000),
                    lastDay: DateTime(holidayLastYear, 12, 31),
                    focusedDay: _focusedDay,
                    shouldFillViewport: true,
                    sixWeekMonthsEnforced: true,
                    startingDayOfWeek: StartingDayOfWeek.sunday,
                    availableCalendarFormats: const {CalendarFormat.month: ''},
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      titleTextFormatter: (date, locale) =>
                          DateFormat.yMMMM(context.localeName).format(date),
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
                          DateFormat.E(context.localeName).format(day),
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
                          holiday: localizedHolidayName(context, d),
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
    final color = eventColor(family, event);
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

  String _timeText(BuildContext context) {
    final l10n = context.l10n;
    final md = DateFormat.Md(l10n.localeName);
    final sep = l10n.rangeSeparator;
    if (event.allDay) {
      final lastDay = event.end.subtract(const Duration(days: 1));
      if (isSameDay(event.start, lastDay)) return l10n.allDay;
      return '${md.format(event.start)}$sep${md.format(lastDay)}';
    }
    final sameDay = isSameDay(event.start, event.end);
    final hm = DateFormat('H:mm');
    final end = sameDay
        ? hm.format(event.end)
        : '${md.format(event.end)} ${hm.format(event.end)}';
    return '${hm.format(event.start)}$sep$end';
  }

  @override
  Widget build(BuildContext context) {
    final color = eventColor(family, event);
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
                    [
                      _timeText(context),
                      if (event.kind == CalendarKind.work)
                        context.l10n.work
                      else
                        ownerName(context, family, event.owner),
                      if (event.isRoutine) context.l10n.routineLabel,
                    ].join('   '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(event.isRoutine ? Icons.repeat : Icons.chevron_right),
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
                  Text(post.text.isEmpty ? context.l10n.noText : post.text),
                  const SizedBox(height: 2),
                  Text(
                    [
                      xKindLabel(context, post.kind),
                      if (post.hasMedia) context.l10n.hasImage,
                    ].join(' · '),
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
