import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'calendar_settings_page.dart';
import 'categories.dart';
import 'family_settings_page.dart';
import 'l10n.dart';
import 'models.dart';
import 'repository.dart';

/// まとめて登録する前の、読み取った予定 1 件。
class DraftEvent {
  DraftEvent({
    required this.start,
    required this.end,
    required this.allDay,
    required this.title,
    this.location = '',
    this.note = '',
  });

  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String title;
  final String location;
  final String note;
}

/// まとめて追加するテキストを読む。1 行 1 件で、項目は「|」で区切る。
///
///   2026-11-01 09:00-12:00 | 練習 | 大谷小体育館 | メモ
///   2026-11-14 終日 | 緑区大会 | 大谷小
///
/// 日付は 2026-11-01 / 2026/11/1 のどちらでもよい。時間の区切りは - 〜 ~ のどれでもよい。
/// 空の行と「#」で始まる行は飛ばす。読めなかった行の番号（1 から）を [errors] に入れる。
List<DraftEvent> parseBulkEvents(String text, {List<int>? errors}) {
  final head = RegExp(
    r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})\s*'
    r'(?:(終日|all\s*day)|(\d{1,2}):(\d{2})\s*[-〜~～]\s*(\d{1,2}):(\d{2}))$',
    caseSensitive: false,
  );
  final result = <DraftEvent>[];
  final lines = text.split(RegExp(r'\r?\n'));
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split('|').map((s) => s.trim()).toList();
    final m = parts.length >= 2 ? head.firstMatch(parts[0]) : null;
    final title = parts.length >= 2 ? parts[1] : '';
    if (m == null || title.isEmpty) {
      errors?.add(i + 1);
      continue;
    }
    final day = DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    // 13 月や 2 月 30 日のような日付は、DateTime が繰り上げてしまうので弾く
    if (day.month != int.parse(m[2]!) || day.day != int.parse(m[3]!)) {
      errors?.add(i + 1);
      continue;
    }
    final allDay = m[4] != null;
    DateTime start;
    DateTime end;
    if (allDay) {
      start = day;
      end = DateTime(day.year, day.month, day.day + 1);
    } else {
      start = day.add(
        Duration(hours: int.parse(m[5]!), minutes: int.parse(m[6]!)),
      );
      end = day.add(
        Duration(hours: int.parse(m[7]!), minutes: int.parse(m[8]!)),
      );
      if (!end.isAfter(start)) {
        errors?.add(i + 1);
        continue;
      }
    }
    result.add(
      DraftEvent(
        start: start,
        end: end,
        allDay: allDay,
        title: title,
        location: parts.length >= 3 ? parts[2] : '',
        note: parts.length >= 4 ? parts.sublist(3).join(' | ') : '',
      ),
    );
  }
  return result;
}

/// 予定をまとめて追加する画面。貼り付けた予定を確認してから登録する。
/// （プリントの AI 読み取りを付けるときも、この確認画面を使う）
class BulkImportPage extends StatefulWidget {
  const BulkImportPage({super.key, required this.family, required this.place});

  final Family family;
  final Place place;

  @override
  State<BulkImportPage> createState() => _BulkImportPageState();
}

class _BulkImportPageState extends State<BulkImportPage> {
  final _text = TextEditingController();
  List<DraftEvent>? _drafts;
  Set<int> _selected = {};
  List<int> _errors = [];
  String _categoryId = Category.familyId;
  CalendarKind _kind = CalendarKind.family;
  late String _ownerId = FirebaseAuth.instance.currentUser!.uid;
  bool _busy = false;
  String? _status;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _read() {
    final errors = <int>[];
    final drafts = parseBulkEvents(_text.text, errors: errors);
    setState(() {
      _drafts = drafts;
      _selected = {for (var i = 0; i < drafts.length; i++) i};
      _errors = errors;
      _status = null;
    });
  }

  Future<void> _save() async {
    final drafts = _drafts;
    if (drafts == null || _selected.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final l10n = context.l10n;
    setState(() => _busy = true);
    var saved = 0;
    try {
      for (final i in _selected.toList()..sort()) {
        final d = drafts[i];
        await Repository.instance.saveEvent(
          widget.place,
          CalendarEvent(
            title: d.title,
            start: d.start,
            end: d.end,
            allDay: d.allDay,
            note: d.note,
            location: d.location,
            createdBy: uid,
            createdByName: widget.family.nameOf(uid),
            ownerId: _kind == CalendarKind.work ? '' : _ownerId,
            kind: _kind,
            categoryId: _categoryId,
          ),
        );
        saved++;
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = l10n.bulkSaved(saved);
        _drafts = null;
        _text.clear();
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _status = l10n.bulkSaveFailed(saved, '$e');
      });
    }
  }

  String _when(DraftEvent d) {
    final day = DateFormat.MMMEd(context.localeName).format(d.start);
    if (d.allDay) return '$day  ${context.l10n.allDay}';
    final hm = DateFormat('H:mm');
    return '$day  ${hm.format(d.start)}${context.l10n.rangeSeparator}${hm.format(d.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final drafts = _drafts;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.bulkTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.bulkHelp),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                minLines: 6,
                maxLines: 14,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: l10n.bulkHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _read,
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(l10n.bulkRead),
              ),
              if (_errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.bulkBadLines(_errors.join(', ')),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (drafts != null && drafts.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  l10n.bulkPreview(drafts.length),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (var i = 0; i < drafts.length; i++)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _selected.contains(i),
                    onChanged: (on) => setState(() {
                      _selected = {..._selected};
                      on == true ? _selected.add(i) : _selected.remove(i);
                    }),
                    title: Text(drafts[i].title),
                    subtitle: Text(
                      [
                        _when(drafts[i]),
                        if (drafts[i].location.isNotEmpty)
                          '📍 ${drafts[i].location}',
                        if (drafts[i].note.isNotEmpty) drafts[i].note,
                      ].join('\n'),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  l10n.categoryLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                CategoryPicker(
                  familyId: widget.place.familyId,
                  uid: widget.place.uid,
                  selectedId: _categoryId,
                  onChanged: (c) => setState(() {
                    _categoryId = c.id;
                    _kind = c.kind;
                  }),
                ),
                if (_kind == CalendarKind.family) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.whoseEvent,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<Family>(
                    stream: Repository.instance.watchFamily(widget.family.id),
                    initialData: widget.family,
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
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy || _selected.isEmpty ? null : _save,
                  icon: const Icon(Icons.event_available),
                  label: Text(l10n.bulkSave(_selected.length)),
                ),
              ],
              if (drafts != null && drafts.isEmpty && _errors.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(l10n.bulkNothing),
                ),
              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_status != null) ...[
                const SizedBox(height: 12),
                Text(_status!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
