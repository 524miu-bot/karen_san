import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'family_settings_page.dart';
import 'l10n.dart';
import 'models.dart';
import 'repository.dart';

/// 予定の追加・編集画面。[event] が null なら新規作成。
class EventEditorPage extends StatefulWidget {
  const EventEditorPage({
    super.key,
    required this.family,
    required this.initialDay,
    this.event,
    this.initialKind = CalendarKind.family,
  });

  final Family family;
  final DateTime initialDay;
  final CalendarEvent? event;

  /// 新しい予定のときに最初に選んでおくカレンダー（家庭か仕事か）。
  final CalendarKind initialKind;

  @override
  State<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends State<EventEditorPage> {
  late final _titleController = TextEditingController(
    text: widget.event?.title ?? '',
  );
  late final _noteController = TextEditingController(
    text: widget.event?.note ?? '',
  );
  late bool _allDay;
  late DateTime _start;
  late DateTime _end;
  late String _ownerId;
  bool _busy = false;
  String? _error;

  final _uid = FirebaseAuth.instance.currentUser!.uid;

  bool get _isNew => widget.event == null;

  late CalendarKind _kind = widget.event?.kind ?? widget.initialKind;

  late final Place _place = Place(familyId: widget.family.id, uid: _uid);

  late final Stream<Family> _familyStream = Repository.instance.watchFamily(
    widget.family.id,
  );

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _ownerId = e?.owner ?? _uid;
    if (e != null) {
      _allDay = e.allDay;
      _start = e.start;
      // 終日の予定は終了を「翌日 0:00」で保存しているので、画面では最終日にする。
      _end = e.allDay ? e.end.subtract(const Duration(days: 1)) : e.end;
    } else {
      final d = widget.initialDay;
      _allDay = false;
      _start = DateTime(d.year, d.month, d.day, 10);
      _end = _start.add(const Duration(hours: 1));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime current) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    if (_allDay) return DateTime(date.year, date.month, date.day);
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStart() async {
    final picked = await _pick(_start);
    if (picked == null) return;
    setState(() {
      final length = _end.difference(_start);
      _start = picked;
      _end = picked.add(length);
    });
  }

  Future<void> _pickEnd() async {
    final picked = await _pick(_end);
    if (picked == null) return;
    setState(() => _end = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = context.l10n.titleRequired);
      return;
    }
    // 終日の予定は「開始日 0:00 〜 終了日の翌日 0:00」で保存する。
    final start = _allDay
        ? DateTime(_start.year, _start.month, _start.day)
        : _start;
    final end = _allDay
        ? DateTime(_end.year, _end.month, _end.day).add(const Duration(days: 1))
        : _end;
    if (!end.isAfter(start)) {
      setState(() => _error = context.l10n.endBeforeStart);
      return;
    }
    final event = CalendarEvent(
      id: widget.event?.id,
      title: title,
      start: start,
      end: end,
      allDay: _allDay,
      note: _noteController.text.trim(),
      createdBy: widget.event?.createdBy ?? _uid,
      createdByName: widget.event?.createdByName ?? widget.family.nameOf(_uid),
      // 仕事の予定は本人だけのものなので、誰の予定かは持たない
      ownerId: _kind == CalendarKind.work ? '' : _ownerId,
      kind: _kind,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Repository.instance.saveEvent(_place, event);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _busy = false;
        _error = context.l10n.saveFailed('$e');
      });
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteEventTitle),
        content: Text(context.l10n.deleteEventBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await Repository.instance.deleteEvent(_place, widget.event!);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _busy = false;
        _error = context.l10n.deleteFailed('$e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = _allDay
        ? DateFormat.yMMMEd(context.localeName)
        : DateFormat.yMMMEd(context.localeName).add_Hm();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? context.l10n.addEvent : context.l10n.editEvent),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: context.l10n.delete,
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
              // 家庭と仕事は保存場所が違うので、選べるのは新しく作るときだけ
              if (_isNew) ...[
                SegmentedButton<CalendarKind>(
                  segments: [
                    ButtonSegment(
                      value: CalendarKind.family,
                      icon: const Icon(Icons.home_outlined),
                      label: Text(context.l10n.family),
                    ),
                    ButtonSegment(
                      value: CalendarKind.work,
                      icon: const Icon(Icons.work_outline),
                      label: Text(context.l10n.work),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
                const SizedBox(height: 16),
              ] else if (_kind == CalendarKind.work)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.work_outline, size: 18),
                      const SizedBox(width: 6),
                      Text(context.l10n.workOnlyYou),
                    ],
                  ),
                ),
              TextField(
                controller: _titleController,
                autofocus: _isNew,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: context.l10n.eventTitle,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_kind == CalendarKind.family) ...[
                Text(
                  context.l10n.whoseEvent,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                // 予定者を追加・変更したらすぐ選択肢に出るよう、家族の変更を受け取る。
                StreamBuilder<Family>(
                  stream: _familyStream,
                  initialData: widget.family,
                  builder: (context, snap) {
                    final family = snap.data!;
                    final ids = family.ownerIds;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final id in [
                          ...ids,
                          // いなくなった人の予定を編集するときも選択肢に残す
                          if (!ids.contains(_ownerId)) _ownerId,
                        ])
                          ChoiceChip(
                            avatar: CircleAvatar(
                              backgroundColor: family.colorOf(id),
                            ),
                            label: Text(ownerName(context, family, id)),
                            selected: _ownerId == id,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _ownerId = id),
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: Text(context.l10n.addPerson),
                          onPressed: () async {
                            final id = await addPersonFlow(context, family);
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
                title: Text(context.l10n.allDay),
                value: _allDay,
                onChanged: (v) => setState(() {
                  _allDay = v;
                  if (!v && !_end.isAfter(_start)) {
                    _end = _start.add(const Duration(hours: 1));
                  }
                }),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(context.l10n.start),
                trailing: Text(fmt.format(_start)),
                onTap: _pickStart,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: Text(context.l10n.end),
                trailing: Text(fmt.format(_end)),
                onTap: _pickEnd,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.l10n.memo,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (!_isNew && widget.event!.createdByName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  context.l10n.addedBy(
                    widget.family.memberNames[widget.event!.createdBy] ??
                        widget.event!.createdByName,
                  ),
                ),
              ],
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
                child: Text(context.l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
