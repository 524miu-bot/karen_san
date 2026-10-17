import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'repository.dart';

/// 家族に未所属のときに表示する。新しく作るか、招待コードで参加する。
class FamilySetupPage extends StatefulWidget {
  const FamilySetupPage({super.key, required this.user});

  final User user;

  @override
  State<FamilySetupPage> createState() => _FamilySetupPageState();
}

class _FamilySetupPageState extends State<FamilySetupPage> {
  late final _myNameController = TextEditingController(
    text: Repository.defaultName(widget.user),
  );
  final _familyNameController = TextEditingController(text: 'わが家');
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _myNameController.dispose();
    _familyNameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String? _myName() {
    final name = _myNameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'あなたの表示名を入力してください。');
      return null;
    }
    return name;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      setState(() => _error = 'エラーが発生しました：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final myName = _myName();
    if (myName == null) return;
    final familyName = _familyNameController.text.trim();
    if (familyName.isEmpty) {
      setState(() => _error = 'グループ名を入力してください。');
      return;
    }
    await _run(
      () => Repository.instance.createFamily(
        user: widget.user,
        familyName: familyName,
        myName: myName,
      ),
    );
  }

  Future<void> _join() async {
    final myName = _myName();
    if (myName == null) return;
    await _run(() async {
      final ok = await Repository.instance.joinFamily(
        user: widget.user,
        inviteCode: _codeController.text,
        myName: myName,
      );
      if (!ok) setState(() => _error = '招待コードが見つかりません。');
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('カレンさん'),
        actions: [
          TextButton.icon(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('ログアウト'),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('はじめに', style: textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('予定を共有するグループを作るか、家族から届いた招待コードで参加してください。'),
                const SizedBox(height: 24),
                TextField(
                  controller: _myNameController,
                  decoration: const InputDecoration(
                    labelText: 'あなたの表示名',
                    helperText: '予定に「誰が登録したか」として表示されます',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),
                Text('新しく作る', style: textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _familyNameController,
                  decoration: const InputDecoration(
                    labelText: 'グループ名',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _create,
                  child: const Text('グループを作る'),
                ),
                const SizedBox(height: 32),
                Text('招待コードで参加する', style: textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: '招待コード（8 文字）',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _join(),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy ? null : _join,
                  child: const Text('参加する'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
