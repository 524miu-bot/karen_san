import 'package:flutter/material.dart';

import 'oshi.dart';
import 'repository.dart';

/// 推し（X で投稿を見たい人）を登録する画面。
class OshiPage extends StatelessWidget {
  const OshiPage({super.key, required this.uid});

  final String uid;

  Future<void> _edit(
    BuildContext context,
    List<Oshi> list, [
    int? index,
  ]) async {
    final result = await showDialog<Oshi>(
      context: context,
      builder: (_) => _OshiDialog(initial: index == null ? null : list[index]),
    );
    if (result == null) return;
    final next = [...list];
    if (index == null) {
      next.add(result);
    } else {
      next[index] = result;
    }
    await Repository.instance.setOshi(uid, next);
  }

  Future<void> _remove(List<Oshi> list, int index) =>
      Repository.instance.setOshi(uid, [...list]..removeAt(index));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Oshi>>(
      stream: Repository.instance.watchOshi(uid),
      builder: (context, snap) {
        final list = snap.data ?? const <Oshi>[];
        return Scaffold(
          appBar: AppBar(title: const Text('推しの X')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context, list),
            icon: const Icon(Icons.add),
            label: const Text('推しを追加'),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '登録した人ごとに、カレンダーの日付を押したとき「この日の投稿を X で見る」'
                      'ボタンが出ます。押すと X が開き、その人がその日に投稿したものだけが表示されます。\n'
                      '・登録した内容はあなただけが見られます。\n'
                      '・X にログインしていないと、検索結果が見られないことがあります。',
                    ),
                  ),
                  if (snap.hasData && list.isEmpty)
                    const ListTile(title: Text('まだ登録されていません')),
                  for (var i = 0; i < list.length; i++)
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        child: Text('𝕏'),
                      ),
                      title: Text(
                        list[i].name.isEmpty
                            ? '@${list[i].handle}'
                            : list[i].name,
                      ),
                      subtitle: list[i].name.isEmpty
                          ? null
                          : Text('@${list[i].handle}'),
                      onTap: () => _edit(context, list, i),
                      trailing: IconButton(
                        tooltip: '削除',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _remove(list, i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OshiDialog extends StatefulWidget {
  const _OshiDialog({this.initial});
  final Oshi? initial;

  @override
  State<_OshiDialog> createState() => _OshiDialogState();
}

class _OshiDialogState extends State<_OshiDialog> {
  late final _handle = TextEditingController(
    text: widget.initial?.handle ?? '',
  );
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  String? _error;

  @override
  void dispose() {
    _handle.dispose();
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final handle = Oshi.parseHandle(_handle.text);
    if (handle == null) {
      setState(() => _error = 'X のユーザー名（@ のあとの英数字）か、プロフィールの URL を入れてください');
      return;
    }
    Navigator.pop(context, Oshi(handle: handle, name: _name.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? '推しを追加' : '推しを編集'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _handle,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'X のユーザー名',
              hintText: '@username または URL',
              errorText: _error,
              errorMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: '表示名（なくても OK）',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}
