import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// アカウント削除の確認画面を出し、同意されたら削除してログアウトする。
Future<void> confirmAndDeleteAccount(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => const _ConfirmDeleteDialog(),
  );
  if (ok != true || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('削除しています…')),
          ],
        ),
      ),
    ),
  );
  try {
    await FirebaseFunctions.instanceFor(region: 'asia-northeast1')
        .httpsCallable('deleteAccount')
        .call<void>();
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    final message = e is FirebaseFunctionsException ? e.message : '$e';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('削除できませんでした：$message')));
    return;
  }
  if (context.mounted) {
    // 進行中の表示と設定画面を閉じてから、ログイン画面に戻る
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
  }
  if (!kIsWeb) {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
  await FirebaseAuth.instance.signOut();
}

class _ConfirmDeleteDialog extends StatefulWidget {
  const _ConfirmDeleteDialog();

  @override
  State<_ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<_ConfirmDeleteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller.text.trim() == '削除';
    return AlertDialog(
      title: const Text('アカウントを削除しますか？'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '次のものが削除され、元に戻せません。\n'
              '・あなたのアカウント\n'
              '・取り込んだ X の投稿と、推しの登録\n'
              '・グループのメンバーからあなたの名前と色\n'
              '\n'
              'グループにほかのメンバーがいる場合、予定は家族のために残り、'
              '「登録した人」からあなたの名前が消えます。'
              'あなたが最後の 1 人なら、グループと予定もすべて削除されます。\n'
              '\n'
              'LINE でログインしていた場合、LINE アプリの「設定 → アカウント → 連動アプリ」'
              'からカレンさんとの連動も解除できます。',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: '確認のため「削除」と入力してください',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: ready ? () => Navigator.pop(context, true) : null,
          child: const Text('削除する'),
        ),
      ],
    );
  }
}
