import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'l10n.dart';

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
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(dialogContext.l10n.deleting)),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.deleteFailed('$message'))),
    );
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
    final ready =
        _controller.text.trim().toUpperCase() == context.l10n.deleteConfirmWord;
    return AlertDialog(
      title: Text(context.l10n.deleteAccountTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.deleteAccountBody),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: context.l10n.deleteConfirmLabel,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: ready ? () => Navigator.pop(context, true) : null,
          child: Text(context.l10n.deleteAccountButton),
        ),
      ],
    );
  }
}
