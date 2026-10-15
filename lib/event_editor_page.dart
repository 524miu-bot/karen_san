import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'repository.dart';

/// 予定の追加・編集画面。[event] が null なら新規作成。
class EventEditorPage extends StatefulWidget {
  const EventEditorPage({
    super.key,
    required this.familyId,
    required this.myName,
    required this.initialDay,
    this.event,
  });

  final String familyId;
  final String myName;
  final DateTime initialDay;
  final CalendarEvent? event;

  @override
  State<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends State<EventEditorPage> {
  late final _titleController =
      TextEditingController(text: widget.event?.title ?? '');
  late final _noteController =
      TextEditingController(text: widget.event?.note ?? '');
  late bool _allDay;
  late DateTime _start;
  late DateTime _end;
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.event == null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
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
      setState(() => _error = 'タイトルを入力してください。');
      return;
    }
    // 終日の予定は「開始日 0:00 〜 終了日の翌日 0:00」で保存する。
    final start = _allDay ? DateTime(_start.year, _start.month, _start.day) : _start;
    final end = _allDay
        ? DateTime(_end.year, _end.month, _end.day).add(const Duration(days: 1))
        : _end;
    if (!end.isAfter(start)) {
      setState(() => _error = '終了は開始より後にしてください。');
      return;
    }
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final event = CalendarEvent(
      id: widget.event?.id,
      title: title,
      start: start,
      end: end,
      allDay: _allDay,
      note: _noteController.text.trim(),
      createdBy: widget.event?.createdBy ?? uid,
      createdByName: widget.event?.createdByName ?? widget.myName,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Repository.instance.saveEvent(widget.familyId, event);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '保存できませんでした：$e';
      });
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この予定を削除しますか？'),
        content: const Text('家族全員のカレンダーから消えます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await Repository.instance.deleteEvent(widget.familyId, widget.event!.id!);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '削除できませんでした：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = _allDay
        ? DateFormat('y年M月d日(E)', 'ja')
        : DateFormat('y年M月d日(E) H:mm', 'ja');
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '予定を追加' : '予定を編集'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: '削除',
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
              TextField(
                controller: _titleController,
                autofocus: _isNew,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'タイトル',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('終日'),
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
                title: const Text('開始'),
                trailing: Text(fmt.format(_start)),
                onTap: _pickStart,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('終了'),
                trailing: Text(fmt.format(_end)),
                onTap: _pickEnd,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'メモ',
                  border: OutlineInputBorder(),
                ),
              ),
              if (!_isNew && widget.event!.createdByName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('登録した人：${widget.event!.createdByName}'),
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
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
