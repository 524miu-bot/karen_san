import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calendar_settings_page.dart';
import 'categories.dart';
import 'family_settings_page.dart';
import 'import_history_page.dart';
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

/// AI（サーバーの readSchedule）が返した予定を、確認画面の形にする。おかしなものは飛ばす。
List<DraftEvent> draftsFromAi(List<dynamic> events) {
  final result = <DraftEvent>[];
  final time = RegExp(r'^(\d{1,2}):(\d{2})$');
  for (final raw in events) {
    if (raw is! Map) continue;
    final day = DateTime.tryParse('${raw['date']}');
    final title = '${raw['title'] ?? ''}'.trim();
    if (day == null || title.isEmpty) continue;
    final d = DateTime(day.year, day.month, day.day);
    final s = time.firstMatch('${raw['start'] ?? ''}');
    final e = time.firstMatch('${raw['end'] ?? ''}');
    var start = d;
    var end = DateTime(d.year, d.month, d.day + 1);
    var allDay = true;
    if (raw['allDay'] != true && s != null && e != null) {
      start = d.add(
        Duration(hours: int.parse(s[1]!), minutes: int.parse(s[2]!)),
      );
      end = d.add(Duration(hours: int.parse(e[1]!), minutes: int.parse(e[2]!)));
      // 終わりが前なら 1 時間にしておく（登録後に直せる）
      if (!end.isAfter(start)) end = start.add(const Duration(hours: 1));
      allDay = false;
    }
    result.add(
      DraftEvent(
        start: start,
        end: end,
        allDay: allDay,
        title: title,
        location: '${raw['location'] ?? ''}'.trim(),
        note: '${raw['note'] ?? ''}'.trim(),
      ),
    );
  }
  return result;
}

/// AI 読み取りの今月の回数（サーバーの aiQuota・readSchedule が返す）。
class AiQuota {
  const AiQuota({
    required this.plan,
    required this.normalUsed,
    required this.normalLimit,
    required this.preciseUsed,
    required this.preciseLimit,
  });

  factory AiQuota.fromMap(Map<dynamic, dynamic> m) {
    int n(String k) => (m[k] as num?)?.toInt() ?? 0;
    return AiQuota(
      plan: '${m['plan'] ?? 'free'}',
      normalUsed: n('normalUsed'),
      normalLimit: n('normalLimit'),
      preciseUsed: n('preciseUsed'),
      preciseLimit: n('preciseLimit'),
    );
  }

  final String plan;
  final int normalUsed;
  final int normalLimit;
  final int preciseUsed;
  final int preciseLimit;

  bool get isPremium => plan == 'premium';
  int get normalLeft => (normalLimit - normalUsed).clamp(0, normalLimit);
  int get preciseLeft => (preciseLimit - preciseUsed).clamp(0, preciseLimit);
}

/// ファイル名から種類を決める（写真の部品が種類を教えてくれないとき）。
String scheduleMimeOf(String name, [String? given]) {
  if (given != null && given.isNotEmpty) return given;
  final n = name.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.gif')) return 'image/gif';
  if (n.endsWith('.pdf')) return 'application/pdf';
  return 'image/jpeg';
}

/// 予定をまとめて追加する画面。写真・PDF を AI で読み取るか、文字を貼り付けて、
/// 確認してから登録する。
class BulkImportPage extends StatefulWidget {
  const BulkImportPage({
    super.key,
    required this.family,
    required this.place,
    this.startWithCamera = false,
  });

  final Family family;
  final Place place;

  /// 開いたらすぐカメラを起動する（カレンダーのカメラボタンから）。
  final bool startWithCamera;

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

  /// 確認画面の予定が写真（AI）からか、文字からか
  bool _fromAi = false;

  /// いま登録した 1 回分（取り消し用）
  String? _lastImportId;
  String? _status;

  final _hint = TextEditingController();
  String? _aiComment;
  AiQuota? _quota;
  bool _precise = false;

  HttpsCallable _callable(String name) =>
      FirebaseFunctions.instanceFor(region: 'asia-northeast1').httpsCallable(
        name,
        options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
      );

  Future<void> _loadQuota() async {
    try {
      final res = await _callable('aiQuota').call<Map<String, dynamic>>();
      if (mounted) setState(() => _quota = AiQuota.fromMap(res.data));
    } catch (_) {
      // 回数が見られなくても読み取りはできる（サーバーで確かめる）
    }
  }

  /// 今の設定（普通か正確か）で、まだ読み取れるか。回数が分からないときは true。
  bool get _canRead {
    final q = _quota;
    if (q == null) return true;
    return _precise ? q.preciseLeft > 0 : q.normalLeft > 0;
  }

  @override
  void initState() {
    super.initState();
    _loadQuota();
    // 入れる先を前に選んだことがあれば、すぐカメラを開く。初めてなら先に選んでもらう。
    _loadTarget().then((chosen) {
      if (chosen && widget.startWithCamera && mounted) {
        _pickAndRead(ImageSource.camera);
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _hint.dispose();
    super.dispose();
  }

  /// 写真を撮る・選ぶ（source が null なら PDF などのファイルを選ぶ）。
  Future<void> _pickAndRead(ImageSource? source) async {
    List<int> bytes;
    String mime;
    try {
      if (source != null) {
        final x = await ImagePicker().pickImage(
          source: source,
          maxWidth: 2400,
          maxHeight: 2400,
          imageQuality: 85,
        );
        if (x == null) return;
        bytes = await x.readAsBytes();
        mime = scheduleMimeOf(x.name, x.mimeType);
      } else {
        final f = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        );
        if (f == null) return;
        bytes = await f.readAsBytes();
        mime = scheduleMimeOf(f.name);
      }
    } catch (e) {
      if (mounted) setState(() => _status = '$e');
      return;
    }
    await _readWithAi(bytes, mime);
  }

  Future<void> _readWithAi(List<int> bytes, String mime) async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _status = l10n.aiReading;
      _aiComment = null;
      _drafts = null;
    });
    try {
      final res = await _callable('readSchedule').call<Map<String, dynamic>>({
        'mimeType': mime,
        'data': base64Encode(bytes),
        'today': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'hint': _hint.text.trim(),
        'precise': _precise,
      });
      final drafts = draftsFromAi(res.data['events'] as List? ?? const []);
      final quota = res.data['quota'];
      if (!mounted) return;
      setState(() {
        if (quota is Map) _quota = AiQuota.fromMap(quota);
        _busy = false;
        _drafts = drafts;
        _fromAi = true;
        _lastImportId = null;
        _selected = {for (var i = 0; i < drafts.length; i++) i};
        _errors = [];
        _aiComment = '${res.data['comment'] ?? ''}'.trim();
        _status = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = e is FirebaseFunctionsException && e.message != null
            ? e.message
            : l10n.aiFailed;
      });
      _loadQuota();
    }
  }

  /// 残り回数と「正確に読む」の切り替え。
  List<Widget> _quotaWidgets(BuildContext context) {
    final q = _quota;
    if (q == null) return const [];
    final l10n = context.l10n;
    return [
      const SizedBox(height: 8),
      Text(
        q.isPremium
            ? l10n.aiLeftPremium(q.normalLeft)
            : l10n.aiLeftFree(q.normalLeft, q.normalLimit),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (q.isPremium)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _precise,
          onChanged: _busy ? null : (v) => setState(() => _precise = v),
          title: Text(l10n.aiPrecise),
          subtitle: Text(l10n.aiPreciseHelp(q.preciseLeft)),
        ),
      if (!_canRead)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _precise ? l10n.aiPreciseUsedUp : l10n.aiUsedUp,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ];
  }

  void _read() {
    final errors = <int>[];
    final drafts = parseBulkEvents(_text.text, errors: errors);
    setState(() {
      _drafts = drafts;
      _fromAi = false;
      _lastImportId = null;
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
    final events = [
      for (final i in _selected.toList()..sort())
        CalendarEvent(
          title: drafts[i].title,
          start: drafts[i].start,
          end: drafts[i].end,
          allDay: drafts[i].allDay,
          note: drafts[i].note,
          location: drafts[i].location,
          createdBy: uid,
          createdByName: widget.family.nameOf(uid),
          ownerId: _kind == CalendarKind.work ? '' : _ownerId,
          kind: _kind,
          categoryId: _categoryId,
        ),
    ];
    try {
      final id = await Repository.instance.addEventsAsImport(
        widget.place,
        events,
        source: _fromAi ? 'photo' : 'text',
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = l10n.bulkSaved(events.length);
        _lastImportId = id;
        _drafts = null;
        _text.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = l10n.bulkSaveFailed(0, '$e');
      });
    }
  }

  /// いま登録した分を取り消す。
  Future<void> _undoLast() async {
    final id = _lastImportId;
    if (id == null) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await Repository.instance.undoImport(widget.place, id);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _lastImportId = null;
        _status = l10n.importUndone;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = l10n.importUndoFailed('$e');
      });
    }
  }

  String _when(DraftEvent d) {
    final day = DateFormat.MMMEd(context.localeName).format(d.start);
    if (d.allDay) return '$day  ${context.l10n.allDay}';
    final hm = DateFormat('H:mm');
    return '$day  ${hm.format(d.start)}${context.l10n.rangeSeparator}${hm.format(d.end)}';
  }

  /// どのカレンダー（種類）と、誰の予定として入れるか。写真を撮る前に選ぶ。
  List<Widget> _targetWidgets(BuildContext context) {
    final l10n = context.l10n;
    return [
      Text(l10n.bulkTarget, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      CategoryPicker(
        familyId: widget.place.familyId,
        uid: widget.place.uid,
        selectedId: _categoryId,
        onChanged: (c) {
          setState(() {
            _categoryId = c.id;
            _kind = c.kind;
          });
          _saveTarget();
        },
      ),
      if (_kind == CalendarKind.family) ...[
        const SizedBox(height: 16),
        Text(l10n.whoseEvent, style: Theme.of(context).textTheme.labelLarge),
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
                    avatar: CircleAvatar(backgroundColor: f.colorOf(id)),
                    label: Text(ownerName(context, f, id)),
                    selected: _ownerId == id,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() => _ownerId = id);
                      _saveTarget();
                    },
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(l10n.addPerson),
                  onPressed: () async {
                    final id = await addPersonFlow(context, f);
                    if (id != null && mounted) {
                      setState(() => _ownerId = id);
                      _saveTarget();
                    }
                  },
                ),
              ],
            );
          },
        ),
      ],
    ];
  }

  Stream<({List<Category> categories, List<CalendarViewDef>? views})>?
  _categories;

  /// 登録ボタンの上に出す「入れる先」のまとめ。
  Widget _targetSummary(BuildContext context) {
    final l10n = context.l10n;
    _categories ??= watchAllCategories(
      context,
      widget.place.familyId,
      widget.place.uid,
    );
    return StreamBuilder(
      stream: _categories,
      builder: (context, snap) {
        final name = (snap.data?.categories ?? const <Category>[])
            .where((c) => c.id == _categoryId)
            .map((c) => c.name)
            .firstOrNull;
        final parts = [
          ?name,
          if (_kind == CalendarKind.family)
            ownerName(context, widget.family, _ownerId),
        ];
        return Row(
          children: [
            const Icon(Icons.event_note_outlined, size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text(l10n.bulkTargetSummary(parts.join(' ・ ')))),
          ],
        );
      },
    );
  }

  static const _prefCategory = 'bulk_target_category';
  static const _prefKind = 'bulk_target_kind';
  static const _prefOwner = 'bulk_target_owner';

  /// 前回選んだ入れる先を思い出す。選んだことがあれば true。
  Future<bool> _loadTarget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_prefCategory);
      if (id == null) return false;
      final kind = CalendarKind.values.asNameMap()[prefs.getString(_prefKind)];
      final owner = prefs.getString(_prefOwner);
      if (!mounted) return false;
      setState(() {
        _categoryId = id;
        if (kind != null) _kind = kind;
        if (owner != null && widget.family.ownerIds.contains(owner)) {
          _ownerId = owner;
        }
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveTarget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCategory, _categoryId);
      await prefs.setString(_prefKind, _kind.name);
      await prefs.setString(_prefOwner, _ownerId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final drafts = _drafts;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bulkTitle),
        actions: [
          IconButton(
            tooltip: l10n.importHistoryTitle,
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ImportHistoryPage(place: widget.place),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ..._targetWidgets(context),
              const Divider(height: 32),
              Text(
                l10n.aiTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(l10n.aiHelp),
              const SizedBox(height: 12),
              TextField(
                controller: _hint,
                minLines: 1,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: l10n.aiHintLabel,
                  hintText: l10n.aiHintExample,
                  border: const OutlineInputBorder(),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy || !_canRead
                        ? null
                        : () => _pickAndRead(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: Text(l10n.aiCamera),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || !_canRead
                        ? null
                        : () => _pickAndRead(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(l10n.aiGallery),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || !_canRead
                        ? null
                        : () => _pickAndRead(null),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(l10n.aiFile),
                  ),
                ],
              ),
              ..._quotaWidgets(context),
              if (drafts == null && _busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (drafts == null && _status != null) ...[
                const SizedBox(height: 8),
                Text(_status!),
              ],
              if (drafts == null && _lastImportId != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _undoLast,
                      icon: const Icon(Icons.undo),
                      label: Text(l10n.importUndoNow),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(l10n.importBackToCalendar),
                    ),
                  ],
                ),
              ],
              if (_aiComment != null && _aiComment!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(l10n.aiComment),
                    subtitle: Text(_aiComment!),
                  ),
                ),
              ],
              const Divider(height: 32),
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
                _targetSummary(context),
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
              if (drafts != null && _busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (drafts != null && _status != null) ...[
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
