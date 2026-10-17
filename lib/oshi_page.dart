import 'package:flutter/material.dart';

import 'l10n.dart';
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
          appBar: AppBar(title: Text(context.l10n.oshiTitle)),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context, list),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.oshiAdd),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(context.l10n.oshiIntro),
                  ),
                  if (snap.hasData && list.isEmpty)
                    ListTile(title: Text(context.l10n.oshiEmpty)),
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
                        tooltip: context.l10n.delete,
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
      setState(() => _error = context.l10n.oshiHandleInvalid);
      return;
    }
    Navigator.pop(context, Oshi(handle: handle, name: _name.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? context.l10n.oshiAdd : context.l10n.oshiEdit,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _handle,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.l10n.oshiHandle,
              hintText: context.l10n.oshiHandleHint,
              errorText: _error,
              errorMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            maxLength: 20,
            decoration: InputDecoration(
              labelText: context.l10n.oshiDisplayName,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(context.l10n.save)),
      ],
    );
  }
}
