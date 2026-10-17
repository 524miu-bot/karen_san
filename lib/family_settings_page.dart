import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'account_deletion.dart';
import 'models.dart';
import 'repository.dart';
import 'oshi_page.dart';
import 'x_import_page.dart';

/// 名前と色を入力するダイアログ。キャンセルなら null。
Future<({String name, Color color})?> showNameColorDialog(
  BuildContext context, {
  required String title,
  String initialName = '',
  required Color initialColor,
  String okLabel = '保存',
}) {
  return showDialog<({String name, Color color})>(
    context: context,
    builder: (context) => _NameColorDialog(
      title: title,
      initialName: initialName,
      initialColor: initialColor,
      okLabel: okLabel,
    ),
  );
}

class _NameColorDialog extends StatefulWidget {
  const _NameColorDialog({
    required this.title,
    required this.initialName,
    required this.initialColor,
    required this.okLabel,
  });

  final String title;
  final String initialName;
  final Color initialColor;
  final String okLabel;

  @override
  State<_NameColorDialog> createState() => _NameColorDialogState();
}

class _NameColorDialogState extends State<_NameColorDialog> {
  late final _controller = TextEditingController(text: widget.initialName);
  late Color _color = widget.initialColor;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '名前を入力してください');
      return;
    }
    Navigator.pop(context, (name: name, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 20,
            decoration: InputDecoration(
              labelText: '名前',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          const Text('色'),
          const SizedBox(height: 8),
          ColorChoices(
            selected: _color,
            onSelected: (c) => setState(() => _color = c),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.okLabel)),
      ],
    );
  }
}

/// 色を選ぶ丸いボタンの並び。
class ColorChoices extends StatelessWidget {
  const ColorChoices({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in memberPalette)
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onSelected(c),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: c,
              child: c.toARGB32() == selected.toARGB32()
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// 予定者を追加するダイアログを出し、追加した人の ID を返す（キャンセルなら null）。
Future<String?> addPersonFlow(BuildContext context, Family family) async {
  final nextColor =
      memberPalette[(family.memberIds.length + family.people.length) %
          memberPalette.length];
  final result = await showNameColorDialog(
    context,
    title: '予定者を追加',
    initialColor: nextColor,
    okLabel: '追加',
  );
  if (result == null) return null;
  return Repository.instance.addPerson(
    family.id,
    result.name,
    color: result.color,
  );
}

/// メンバー・予定者・招待コードの設定画面。
class FamilySettingsPage extends StatelessWidget {
  const FamilySettingsPage({
    super.key,
    required this.familyId,
    required this.uid,
  });

  final String familyId;
  final String uid;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存できませんでした：$e')));
    }
  }

  Future<void> _editMe(BuildContext context, Family f) async {
    final result = await showNameColorDialog(
      context,
      title: 'あなたの名前と色',
      initialName: f.memberNames[uid] ?? '',
      initialColor: f.colorOf(uid),
    );
    if (result == null || !context.mounted) return;
    await _run(context, () async {
      await Repository.instance.setMyName(f.id, uid, result.name);
      await Repository.instance.setMyColor(f.id, uid, result.color);
    });
  }

  Future<void> _editPerson(BuildContext context, Family f, Person p) async {
    final result = await showNameColorDialog(
      context,
      title: '予定者を編集',
      initialName: p.name,
      initialColor: f.colorOf(p.id),
    );
    if (result == null || !context.mounted) return;
    await _run(
      context,
      () => Repository.instance.updatePerson(
        f.id,
        p.id,
        name: result.name,
        color: result.color,
      ),
    );
  }

  Future<void> _removePerson(BuildContext context, Family f, Person p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('「${p.name}」を削除しますか？'),
        content: const Text('この人の予定は消えずに残り、「（いなくなった人）」と表示されます。'),
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
    if (ok != true || !context.mounted) return;
    await _run(context, () => Repository.instance.removePerson(f.id, p.id));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Family>(
      stream: Repository.instance.watchFamily(familyId),
      builder: (context, snap) {
        final f = snap.data;
        return Scaffold(
          appBar: AppBar(title: Text(f?.name ?? 'メンバー')),
          body: f == null
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        _header(context, 'ログインしているメンバー'),
                        for (final id in f.memberIds)
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: f.colorOf(id),
                            ),
                            title: Text(f.nameOf(id)),
                            subtitle: id == uid ? const Text('あなた') : null,
                            trailing: id == uid
                                ? const Icon(Icons.edit_outlined)
                                : null,
                            onTap: id == uid ? () => _editMe(context, f) : null,
                          ),
                        const Divider(),
                        _header(context, '予定者（ログインしない人）'),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            'お子さんなど、アプリを使わない人の予定も色分けして登録できます。'
                            'グループの誰でも追加・編集できます。',
                          ),
                        ),
                        for (final id in f.personIds)
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: f.colorOf(id),
                            ),
                            title: Text(f.people[id]!.name),
                            onTap: () => _editPerson(context, f, f.people[id]!),
                            trailing: IconButton(
                              tooltip: '削除',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  _removePerson(context, f, f.people[id]!),
                            ),
                          ),
                        ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.add)),
                          title: const Text('予定者を追加'),
                          onTap: () => addPersonFlow(context, f),
                        ),
                        const Divider(),
                        _header(context, 'あなたの X の投稿（日記）'),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            child: Text('𝕏'),
                          ),
                          title: const Text('X の投稿を取り込む'),
                          subtitle: const Text(
                            '日付を押すと、その日の投稿やいいねを読めます。あなただけが見られます。',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => XImportPage(uid: uid),
                            ),
                          ),
                        ),
                        ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.favorite_outline),
                          ),
                          title: const Text('推しの X を登録'),
                          subtitle: const Text('日付を押すと、推しのその日の投稿を X で開けます。'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => OshiPage(uid: uid),
                            ),
                          ),
                        ),
                        const Divider(),
                        _header(context, '招待コード'),
                        ListTile(
                          title: SelectableText(
                            f.inviteCode,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          subtitle: const Text(
                            '家族にこのコードを伝えると、ログインして同じカレンダーに参加できます。',
                          ),
                          trailing: IconButton(
                            tooltip: 'コピー',
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: f.inviteCode),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('招待コードをコピーしました')),
                              );
                            },
                          ),
                        ),
                        const Divider(),
                        _header(context, 'アカウント'),
                        ListTile(
                          leading: Icon(
                            Icons.person_remove_outlined,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          title: Text(
                            'アカウントを削除',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          subtitle: const Text('あなたのデータを削除して、ログアウトします。'),
                          onTap: () => confirmAndDeleteAccount(context),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}
