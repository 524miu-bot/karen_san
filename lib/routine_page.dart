import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'calendar_page.dart' show eventColor;
import 'calendar_settings_page.dart';
import 'categories.dart';
import 'family_settings_page.dart';
import 'l10n.dart';
import 'models.dart';
import 'planner.dart';
import 'maps.dart';
import 'repository.dart';
import 'streams.dart';

/// 曜日の名前（月曜日〜日曜日）。2024-01-01 は月曜日。
String weekdayName(BuildContext context, int weekday, {bool short = false}) {
  final d = DateTime(2024, 1, weekday);
  return short
      ? DateFormat.E(context.localeName).format(d)
      : DateFormat.EEEE(context.localeName).format(d);
}

String _time(int minutes) =>
    '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

String routineTimeText(BuildContext context, Routine r) => r.allDay
    ? context.l10n.allDay
    : '${_time(r.startMinutes)}${context.l10n.rangeSeparator}${_time(r.endMinutes)}';

/// 1 週間のルーティーン（曜日ごとの決まった予定）の一覧。
class RoutinePage extends StatelessWidget {
  const RoutinePage({super.key, required this.family, required this.place});

  final Family family;
  final Place place;

  void _openEditor(BuildContext context, {Routine? routine}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RoutineEditorPage(family: family, place: place, routine: routine),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = Repository.instance;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.routinesTitle)),
      floatingActionButton: FloatingActionButton(
        tooltip: context.l10n.addRoutine,
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Routine>>(
        stream: combineLatestLists([
          repo.watchRoutines(place, CalendarKind.family),
          repo.watchRoutines(place, CalendarKind.work),
        ]),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(context.l10n.loadFailed('${snap.error}')),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final routines = snap.data!;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(context.l10n.routinesHelp),
                  ),
                  for (var w = DateTime.monday; w <= DateTime.sunday; w++) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        weekdayName(context, w),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    ..._tilesFor(context, routines, w),
                  ],
                  // 毎月のルーティーンは曜日で分けられないので、最後にまとめる
                  if (routines.any((r) => r.repeat.isMonthly)) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        context.l10n.repeatMonthlySection,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    for (final r in routines.where((r) => r.repeat.isMonthly))
                      _tile(context, r),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _tilesFor(BuildContext context, List<Routine> all, int weekday) {
    final list = all.where((r) => r.weekdays.contains(weekday)).toList()
      ..sort((a, b) {
        if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
        return a.startMinutes.compareTo(b.startMinutes);
      });
    if (list.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            '—',
            style: TextStyle(color: Theme.of(context).disabledColor),
          ),
        ),
      ];
    }
    return [for (final r in list) _tile(context, r)];
  }

  Widget _tile(BuildContext context, Routine r) => ListTile(
    dense: true,
    leading: Container(
      width: 5,
      height: 32,
      decoration: BoxDecoration(
        color: eventColor(family, r.occurrenceOn(DateTime(2024, 1, 1))),
        borderRadius: BorderRadius.circular(3),
      ),
    ),
    title: Text(r.title),
    subtitle: Text(
      [
        routineTimeText(context, r),
        if (r.kind == CalendarKind.work)
          context.l10n.work
        else
          ownerName(context, family, r.ownerId),
        if (r.repeat == RepeatRule.biweekly) context.l10n.repeatBiweekly,
        if (r.repeat.isMonthly && r.anchor != null)
          repeatDescription(context, r.repeat, r.anchor!),
        if (r.skipHolidays) context.l10n.skipHolidaysShort,
      ].join('   '),
    ),
    onTap: () => _openEditor(context, routine: r),
  );
}

/// ルーティーンの追加・編集。
class RoutineEditorPage extends StatefulWidget {
  const RoutineEditorPage({
    super.key,
    required this.family,
    required this.place,
    this.routine,
  });

  final Family family;
  final Place place;
  final Routine? routine;

  @override
  State<RoutineEditorPage> createState() => _RoutineEditorPageState();
}

class _RoutineEditorPageState extends State<RoutineEditorPage> {
  late final _title = TextEditingController(text: widget.routine?.title ?? '');
  late final _note = TextEditingController(text: widget.routine?.note ?? '');
  late final _location = TextEditingController(
    text: widget.routine?.location ?? '',
  );
  late CalendarKind _kind = widget.routine?.kind ?? CalendarKind.family;
  late String _categoryId =
      widget.routine?.categoryId ??
      (_kind == CalendarKind.work ? Category.workId : Category.familyId);
  late Set<int> _weekdays = {...?widget.routine?.weekdays};
  late RepeatRule _repeat = widget.routine?.repeat ?? RepeatRule.weekly;

  /// 隔週・毎月の基準日（初めは今日）。
  late DateTime _anchor = widget.routine?.anchor ?? _todayOnly();

  static DateTime _todayOnly() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _pickAnchor() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2000),
      lastDate: DateTime(2099, 12, 31),
    );
    if (d != null) setState(() => _anchor = d);
  }

  late bool _allDay = widget.routine?.allDay ?? false;
  late int _start = widget.routine?.startMinutes ?? 9 * 60;
  late int _end = widget.routine?.endMinutes ?? 10 * 60;
  late String _ownerId =
      widget.routine?.ownerId ?? FirebaseAuth.instance.currentUser!.uid;
  late bool _skipHolidays = widget.routine?.skipHolidays ?? false;
  late Set<String> _skipDates = {...?widget.routine?.skipDates};
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.routine == null;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool start) async {
    final current = start ? _start : _end;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (t == null) return;
    setState(() {
      final m = t.hour * 60 + t.minute;
      if (start) {
        final length = _end - _start;
        _start = m;
        _end = (m + length).clamp(m + 5, 24 * 60 - 1);
      } else {
        _end = m;
      }
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final title = _title.text.trim();
    final problem = title.isEmpty
        ? l10n.titleRequired
        : !_repeat.isMonthly && _weekdays.isEmpty
        ? l10n.weekdaysRequired
        : !_allDay && _end <= _start
        ? l10n.endBeforeStart
        : null;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Repository.instance.saveRoutine(
        widget.place,
        Routine(
          id: widget.routine?.id,
          title: title,
          weekdays: _repeat.isMonthly ? const {} : _weekdays,
          repeat: _repeat,
          anchorDate: _repeat == RepeatRule.weekly ? null : dateKey(_anchor),
          allDay: _allDay,
          startMinutes: _start,
          endMinutes: _end,
          ownerId: _kind == CalendarKind.work ? '' : _ownerId,
          note: _note.text.trim(),
          location: _location.text.trim(),
          skipHolidays: _skipHolidays,
          skipDates: _skipDates,
          kind: _kind,
          categoryId: _categoryId,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = l10n.saveFailed('$e');
      });
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteRoutineTitle),
        content: Text(l10n.deleteRoutineBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await Repository.instance.deleteRoutine(widget.place, widget.routine!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = l10n.deleteFailed('$e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final family = widget.family;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.addRoutine : l10n.editRoutine),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: l10n.delete,
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.categoryLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              CategoryPicker(
                familyId: widget.place.familyId,
                uid: widget.place.uid,
                selectedId: _categoryId,
                onlyKind: _isNew ? null : _kind,
                onChanged: (c) => setState(() {
                  _categoryId = c.id;
                  _kind = c.kind;
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                autofocus: _isNew,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: l10n.eventTitle,
                  border: const OutlineInputBorder(),
                ),
              ),
              Text(
                l10n.repeatHow,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in RepeatRule.values)
                    ChoiceChip(
                      label: Text(repeatRuleName(context, r)),
                      selected: _repeat == r,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _repeat = r),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_repeat != RepeatRule.weekly)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(
                    _repeat.isMonthly
                        ? l10n.repeatMonthlyFrom
                        : l10n.repeatBiweeklyFrom,
                  ),
                  subtitle: _repeat.isMonthly
                      ? Text(repeatDescription(context, _repeat, _anchor))
                      : null,
                  trailing: Text(
                    DateFormat.yMMMEd(context.localeName).format(_anchor),
                  ),
                  onTap: _pickAnchor,
                ),
              if (!_repeat.isMonthly) ...[
                Text(
                  l10n.repeatOn,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var w = DateTime.monday; w <= DateTime.sunday; w++)
                      FilterChip(
                        label: Text(weekdayName(context, w, short: true)),
                        selected: _weekdays.contains(w),
                        showCheckmark: false,
                        onSelected: (on) => setState(() {
                          _weekdays = {..._weekdays};
                          on ? _weekdays.add(w) : _weekdays.remove(w);
                        }),
                      ),
                    ActionChip(
                      label: Text(l10n.weekdaysOnly),
                      onPressed: () =>
                          setState(() => _weekdays = {1, 2, 3, 4, 5}),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              if (_kind == CalendarKind.family) ...[
                Text(
                  l10n.whoseEvent,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                StreamBuilder<Family>(
                  stream: Repository.instance.watchFamily(family.id),
                  initialData: family,
                  builder: (context, snap) {
                    final f = snap.data!;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final id in f.ownerIds)
                          ChoiceChip(
                            avatar: CircleAvatar(
                              backgroundColor: f.colorOf(id),
                            ),
                            label: Text(ownerName(context, f, id)),
                            selected: _ownerId == id,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _ownerId = id),
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: Text(l10n.addPerson),
                          onPressed: () async {
                            final id = await addPersonFlow(context, f);
                            if (id != null && mounted) {
                              setState(() => _ownerId = id);
                            }
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.allDay),
                value: _allDay,
                onChanged: (v) => setState(() => _allDay = v),
              ),
              if (!_allDay) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(l10n.start),
                  trailing: Text(_time(_start)),
                  onTap: () => _pickTime(true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_outlined),
                  title: Text(l10n.end),
                  trailing: Text(_time(_end)),
                  onTap: () => _pickTime(false),
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.skipHolidays),
                subtitle: Text(l10n.skipHolidaysHelp),
                value: _skipHolidays,
                onChanged: (v) => setState(() => _skipHolidays = v),
              ),
              if (_skipDates.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.skippedDays,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final key in (_skipDates.toList()..sort()))
                      InputChip(
                        label: Text(
                          DateFormat.yMMMEd(context.localeName)
                              .format(DateTime.parse(key)),
                        ),
                        onDeleted: () => setState(
                          () => _skipDates = {..._skipDates}..remove(key),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              LocationField(controller: _location),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.memo,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 繰り返し方の名前（毎週・隔週・毎月（日付）・毎月（曜日））。
String repeatRuleName(BuildContext context, RepeatRule r) => switch (r) {
  RepeatRule.weekly => context.l10n.repeatWeekly,
  RepeatRule.biweekly => context.l10n.repeatBiweekly,
  RepeatRule.monthlyDate => context.l10n.repeatMonthlyDate,
  RepeatRule.monthlyWeekday => context.l10n.repeatMonthlyWeekday,
};

/// 「毎月 15 日」「毎月 第 2 土曜日」のような説明。
String repeatDescription(BuildContext context, RepeatRule r, DateTime anchor) =>
    switch (r) {
      RepeatRule.monthlyDate => context.l10n.everyMonthDay(anchor.day),
      RepeatRule.monthlyWeekday => context.l10n.everyMonthNthWeekday(
        nthWeekdayOfMonth(anchor),
        weekdayName(context, anchor.weekday),
      ),
      RepeatRule.biweekly => context.l10n.repeatBiweekly,
      RepeatRule.weekly => context.l10n.repeatWeekly,
    };
