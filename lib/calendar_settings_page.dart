import 'package:flutter/material.dart';

import 'categories.dart';
import 'color_picker.dart';
import 'l10n.dart';
import 'models.dart';
import 'repository.dart';
import 'streams.dart';

/// 家族の種類と自分の種類をまとめて受け取る（最初からある家庭・仕事を含む）。
Stream<({List<Category> categories, List<CalendarViewDef>? views})>
watchAllCategories(BuildContext context, String familyId, String uid) {
  final familyName = context.l10n.family;
  final workName = context.l10n.work;
  final repo = Repository.instance;
  late Family family;
  late ({Map<String, Category> categories, List<CalendarViewDef>? views}) mine;
  // 2 つの流れを 1 つにまとめる（どちらかが変わるたびに作り直す）
  return combineLatestLists<Object>([
    repo.watchFamily(familyId).map((f) => [f]),
    repo.watchMyCalendarSettings(uid).map((s) => [s]),
  ]).map((list) {
    family = list[0] as Family;
    mine =
        list[1]
            as ({
              Map<String, Category> categories,
              List<CalendarViewDef>? views,
            });
    return (
      categories: mergeCategories(
        familyName: familyName,
        workName: workName,
        shared: family.categories,
        private: mine.categories,
      ),
      views: mine.views,
    );
  });
}

/// 予定・ルーティーンの「種類」を選ぶチップの並び。
/// [onlyKind] を指定すると、その保存場所（共有／自分だけ）の種類だけを出す
/// （作ったあとの予定は保存場所を移せないため）。
class CategoryPicker extends StatefulWidget {
  const CategoryPicker({
    super.key,
    required this.familyId,
    required this.uid,
    required this.selectedId,
    required this.onChanged,
    this.onlyKind,
  });

  final String familyId;
  final String uid;
  final String selectedId;
  final ValueChanged<Category> onChanged;
  final CalendarKind? onlyKind;

  @override
  State<CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<CategoryPicker> {
  Stream<({List<Category> categories, List<CalendarViewDef>? views})>? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= watchAllCategories(context, widget.familyId, widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _stream,
      builder: (context, snap) {
        final all = snap.data?.categories ?? const <Category>[];
        final list = widget.onlyKind == null
            ? all
            : all.where((c) => c.kind == widget.onlyKind).toList();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in list)
              ChoiceChip(
                avatar: Icon(
                  c.shared ? Icons.groups_outlined : Icons.lock_outline,
                  size: 16,
                ),
                label: Text(c.name),
                selected: c.id == widget.selectedId,
                showCheckmark: false,
                onSelected: (_) => widget.onChanged(c),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: Text(context.l10n.addCategory),
              onPressed: () async {
                final c = await editCategory(
                  context,
                  Place(familyId: widget.familyId, uid: widget.uid),
                  shared: widget.onlyKind != CalendarKind.work,
                  lockShared: widget.onlyKind != null,
                );
                if (c != null) widget.onChanged(c);
              },
            ),
          ],
        );
      },
    );
  }
}

/// 種類を追加・編集するダイアログ。保存した種類を返す（キャンセルなら null）。
Future<Category?> editCategory(
  BuildContext context,
  Place place, {
  Category? existing,
  bool shared = true,
  bool lockShared = false,
}) async {
  final result = await showDialog<Category>(
    context: context,
    builder: (_) => _CategoryDialog(
      existing: existing,
      shared: existing?.shared ?? shared,
      lockShared: lockShared || existing != null,
    ),
  );
  if (result == null) return null;
  await Repository.instance.saveCategory(place, result);
  return result;
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({
    this.existing,
    required this.shared,
    required this.lockShared,
  });

  final Category? existing;
  final bool shared;
  final bool lockShared;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late bool _shared = widget.shared;
  late Color _color = widget.existing?.color != null
      ? Color(widget.existing!.color!)
      : memberPalette[5];
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = context.l10n.nameRequired);
      return;
    }
    Navigator.pop(
      context,
      Category(
        id: widget.existing?.id ?? Repository.newCategoryId(),
        name: name,
        shared: _shared,
        color: _color.toARGB32(),
        order: widget.existing?.order ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        widget.existing == null ? l10n.addCategory : l10n.editCategory,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: l10n.categoryName,
                hintText: l10n.categoryNameHint,
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.groups_outlined),
                  label: Text(l10n.categoryShared),
                ),
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.lock_outline),
                  label: Text(l10n.categoryPrivate),
                ),
              ],
              selected: {_shared},
              onSelectionChanged: widget.lockShared
                  ? null
                  : (s) => setState(() => _shared = s.first),
            ),
            const SizedBox(height: 6),
            Text(
              _shared ? l10n.categorySharedHelp : l10n.categoryPrivateHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(l10n.color),
            const SizedBox(height: 8),
            ColorChoices(
              selected: _color,
              onSelected: (c) => setState(() => _color = c),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}

/// 「カレンダーの種類」と「表示するカレンダー（組み合わせ）」の設定画面。
class CalendarSettingsPage extends StatefulWidget {
  const CalendarSettingsPage({
    super.key,
    required this.familyId,
    required this.uid,
  });

  final String familyId;
  final String uid;

  @override
  State<CalendarSettingsPage> createState() => _CalendarSettingsPageState();
}

class _CalendarSettingsPageState extends State<CalendarSettingsPage> {
  Stream<({List<Category> categories, List<CalendarViewDef>? views})>? _stream;
  late final Place _place = Place(familyId: widget.familyId, uid: widget.uid);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= watchAllCategories(context, widget.familyId, widget.uid);
  }

  List<CalendarViewDef> _viewsOrDefault(List<CalendarViewDef>? saved) {
    final l10n = context.l10n;
    return saved == null
        ? defaultViews(
            allName: l10n.viewAll,
            familyName: l10n.family,
            workName: l10n.work,
          )
        : withAllFirst(saved, allName: l10n.viewAll);
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.saveFailed('$e'))));
    }
  }

  Future<void> _deleteCategory(Category c) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteCategoryTitle(c.name)),
        content: Text(l10n.deleteCategoryBody),
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
    if (ok == true) {
      await _run(() => Repository.instance.deleteCategory(_place, c));
    }
  }

  Future<void> _editView(
    List<Category> categories,
    List<CalendarViewDef> views, [
    CalendarViewDef? existing,
  ]) async {
    final result = await showDialog<CalendarViewDef>(
      context: context,
      builder: (_) => _ViewDialog(categories: categories, existing: existing),
    );
    if (result == null) return;
    final next = [
      for (final v in views)
        if (!v.isAll) v.id == result.id ? result : v,
      if (existing == null) result,
    ];
    await _run(() => Repository.instance.saveViews(widget.uid, next));
  }

  Future<void> _deleteView(List<CalendarViewDef> views, CalendarViewDef view) =>
      _run(
        () => Repository.instance.saveViews(widget.uid, [
          for (final v in views)
            if (!v.isAll && v.id != view.id) v,
        ]),
      );

  Future<void> _moveView(List<CalendarViewDef> views, int index, int delta) {
    final list = views.where((v) => !v.isAll).toList();
    final i = index - 1; // 先頭の「すべて」を除いた位置
    final j = i + delta;
    if (j < 0 || j >= list.length) return Future.value();
    final v = list.removeAt(i);
    list.insert(j, v);
    return _run(() => Repository.instance.saveViews(widget.uid, list));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.calendarSettingsTitle)),
      body: StreamBuilder(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(l10n.loadFailed('${snap.error}')));
          }
          final data = snap.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final categories = data.categories;
          final views = _viewsOrDefault(data.views);
          final names = {for (final c in categories) c.id: c.name};
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  _header(context, l10n.viewsSection),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(l10n.viewsHelp),
                  ),
                  for (var i = 0; i < views.length; i++)
                    ListTile(
                      leading: const Icon(Icons.calendar_view_month_outlined),
                      title: Text(views[i].name),
                      subtitle: Text(
                        views[i].isAll
                            ? l10n.viewAllHelp
                            : views[i].categoryIds!
                                  .map((id) => names[id] ?? '—')
                                  .join(' ＋ '),
                      ),
                      onTap: views[i].isAll
                          ? null
                          : () => _editView(categories, views, views[i]),
                      trailing: views[i].isAll
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: l10n.moveUp,
                                  icon: const Icon(Icons.arrow_upward),
                                  onPressed: i <= 1
                                      ? null
                                      : () => _moveView(views, i, -1),
                                ),
                                IconButton(
                                  tooltip: l10n.delete,
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deleteView(views, views[i]),
                                ),
                              ],
                            ),
                    ),
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.add)),
                    title: Text(l10n.addView),
                    onTap: () => _editView(categories, views),
                  ),
                  const Divider(),
                  _header(context, l10n.categoriesSection),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(l10n.categoriesHelp),
                  ),
                  for (final c in categories)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: c.displayColor,
                        foregroundColor: Colors.white,
                        child: Icon(
                          c.shared ? Icons.groups_outlined : Icons.lock_outline,
                          size: 18,
                        ),
                      ),
                      title: Text(c.name),
                      subtitle: Text(
                        c.shared ? l10n.categoryShared : l10n.categoryPrivate,
                      ),
                      onTap: c.isBuiltIn
                          ? null
                          : () => editCategory(context, _place, existing: c),
                      trailing: c.isBuiltIn
                          ? null
                          : IconButton(
                              tooltip: l10n.delete,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteCategory(c),
                            ),
                    ),
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.add)),
                    title: Text(l10n.addCategory),
                    onTap: () => editCategory(context, _place),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

/// 表示カレンダー（種類の組み合わせ）を作る・直すダイアログ。
class _ViewDialog extends StatefulWidget {
  const _ViewDialog({required this.categories, this.existing});

  final List<Category> categories;
  final CalendarViewDef? existing;

  @override
  State<_ViewDialog> createState() => _ViewDialogState();
}

class _ViewDialogState extends State<_ViewDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late Set<String> _selected = {...?widget.existing?.categoryIds};
  bool _nameEdited = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameEdited = widget.existing != null;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// 名前を自分で入れていなければ、選んだ種類から「バスケ＋空手」のように作る。
  void _autoName() {
    if (_nameEdited) return;
    _name.text = [
      for (final c in widget.categories)
        if (_selected.contains(c.id)) c.name,
    ].join('＋');
  }

  void _submit() {
    final l10n = context.l10n;
    final name = _name.text.trim();
    if (_selected.isEmpty) {
      setState(() => _error = l10n.viewNeedsCategory);
      return;
    }
    if (name.isEmpty) {
      setState(() => _error = l10n.nameRequired);
      return;
    }
    Navigator.pop(
      context,
      CalendarViewDef(
        id: widget.existing?.id ?? Repository.newViewId(),
        name: name,
        categoryIds: _selected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.existing == null ? l10n.addView : l10n.editView),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.viewPickCategories),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in widget.categories)
                  FilterChip(
                    label: Text(c.name),
                    selected: _selected.contains(c.id),
                    onSelected: (on) => setState(() {
                      _selected = {..._selected};
                      on ? _selected.add(c.id) : _selected.remove(c.id);
                      _autoName();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: l10n.viewName,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _nameEdited = true,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
