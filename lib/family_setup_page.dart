import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'account_deletion.dart';
import 'l10n.dart';
import 'repository.dart';

/// 家族に未所属のときに表示する。新しく作るか、招待コードで参加する。
class FamilySetupPage extends StatefulWidget {
  const FamilySetupPage({super.key, required this.user});

  final User user;

  @override
  State<FamilySetupPage> createState() => _FamilySetupPageState();
}

class _FamilySetupPageState extends State<FamilySetupPage> {
  final _myNameController = TextEditingController();
  final _familyNameController = TextEditingController();
  bool _defaultsSet = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 初期値は言語に合わせる（最初の 1 回だけ）
    if (!_defaultsSet) {
      _defaultsSet = true;
      _familyNameController.text = context.l10n.defaultGroupName;
      _myNameController.text = Repository.defaultName(
        widget.user,
        fallback: context.l10n.defaultMemberName,
      );
    }
  }

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
      setState(() => _error = context.l10n.yourNameRequired);
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
      setState(() => _error = context.l10n.errorGeneric('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final myName = _myName();
    if (myName == null) return;
    final familyName = _familyNameController.text.trim();
    if (familyName.isEmpty) {
      setState(() => _error = context.l10n.groupNameRequired);
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
      if (!ok) setState(() => _error = context.l10n.inviteNotFound);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.appTitle),
        actions: [
          TextButton.icon(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            label: Text(context.l10n.logout),
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
                Text(context.l10n.setupTitle, style: textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(context.l10n.setupIntro),
                const SizedBox(height: 24),
                TextField(
                  controller: _myNameController,
                  decoration: InputDecoration(
                    labelText: context.l10n.yourName,
                    helperText: context.l10n.yourNameHelp,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),
                Text(context.l10n.createNew, style: textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _familyNameController,
                  decoration: InputDecoration(
                    labelText: context.l10n.groupName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _create,
                  child: Text(context.l10n.createGroup),
                ),
                const SizedBox(height: 32),
                Text(context.l10n.joinWithCode, style: textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: context.l10n.inviteCodeField,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _join(),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy ? null : _join,
                  child: Text(context.l10n.join),
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
                const SizedBox(height: 40),
                Center(
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => confirmAndDeleteAccount(context),
                    child: Text(
                      context.l10n.deleteAccount,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
