import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'calendar_page.dart' show eventColor;
import 'family_settings_page.dart';
import 'l10n.dart';
import 'models.dart';
import 'planner.dart';
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
    return [
      for (final r in list)
        ListTile(
          dense: true,
          leading: Container(
            width: 5,
            height: 32,
            decoration: BoxDecoration(
              color: eventColor(
                family,
                r.occurrenceOn(DateTime(2024, 1, weekday)),
              ),
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
              if (r.skipHolidays) context.l10n.skipHolidaysShort,
            ].join('   '),
          ),
          onTap: () => _openEditor(context, routine: r),
        ),
    ];
  }
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
  late CalendarKind _kind = widget.routine?.kind ?? CalendarKind.family;
  late Set<int> _weekdays = {...?widget.routine?.weekdays};
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
        : _weekdays.isEmpty
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
          weekdays: _weekdays,
          allDay: _allDay,
          startMinutes: _start,
          endMinutes: _end,
          ownerId: _kind == CalendarKind.work ? '' : _ownerId,
          note: _note.text.trim(),
          skipHolidays: _skipHolidays,
          skipDates: _skipDates,
          kind: _kind,
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
              if (_isNew) ...[
                SegmentedButton<CalendarKind>(
                  segments: [
                    ButtonSegment(
                      value: CalendarKind.family,
                      icon: const Icon(Icons.home_outlined),
                      label: Text(l10n.family),
                    ),
                    ButtonSegment(
                      value: CalendarKind.work,
                      icon: const Icon(Icons.work_outline),
                      label: Text(l10n.work),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
                const SizedBox(height: 16),
              ],
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
