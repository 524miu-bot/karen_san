import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'google_login.dart';
import 'l10n.dart';
import 'line_login.dart';
import 'line_login_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (kIsWeb && isLineLoginConfigured && isReturningFromLine) {
      _finishLineLogin();
    }
  }

  /// LINE の認可画面から戻ってきたときの続き。
  Future<void> _finishLineLogin() async {
    setState(() => _busy = true);
    final result = await completeLineLoginIfNeeded();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result is LineLoginFailure) {
        _error = switch (result.error) {
          LineLoginError.cancelled => context.l10n.lineCancelled,
          LineLoginError.stateMismatch => context.l10n.lineStateMismatch,
          LineLoginError.failed => context.l10n.lineFailed(result.code),
        };
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _messageFor(e));
    } catch (e) {
      // 端末の Google ログインのエラーなど
      if (mounted) setState(() => _error = context.l10n.loginFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final auth = FirebaseAuth.instance;
    await _run(() async {
      if (_isSignUp) {
        await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }
    });
  }

  Future<void> _signInWithGoogle() async {
    await _run(() async {
      await signInWithGoogle();
    });
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = context.l10n.emailRequired);
      return;
    }
    await _run(() async {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.passwordResetSent)));
    });
  }

  String _messageFor(FirebaseAuthException e) {
    final l10n = context.l10n;
    switch (e.code) {
      case 'invalid-email':
        return l10n.authInvalidEmail;
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return l10n.authWrongCredentials;
      case 'email-already-in-use':
        return l10n.authEmailInUse;
      case 'weak-password':
        return l10n.authWeakPassword;
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return l10n.authCancelled;
      case 'too-many-requests':
        return l10n.authTooMany;
      default:
        return l10n.authError(e.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: CircleAvatar(
                      radius: 48,
                      backgroundImage: AssetImage('assets/branding/karen.png'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.appTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 32),
                  // iPhone アプリ版の LINE ログインは LINE SDK で別途対応する
                  if (kIsWeb && isLineLoginConfigured) ...[
                    LineLoginButton(onPressed: _busy ? null : startLineLogin),
                    // ボタンの周りに保護エリア（何も置かない余白）を取る
                    const SizedBox(height: 16),
                  ],
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _signInWithGoogle,
                    icon: const Icon(Icons.account_circle),
                    label: Text(context.l10n.loginGoogle),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(context.l10n.loginOr),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: context.l10n.email,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.l10n.emailRequired
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: context.l10n.password,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? context.l10n.passwordMin
                        : null,
                    onFieldSubmitted: (_) => _submitEmail(),
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
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submitEmail,
                    child: Text(
                      _isSignUp ? context.l10n.signUp : context.l10n.logIn,
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _isSignUp = !_isSignUp;
                            _error = null;
                          }),
                    child: Text(
                      _isSignUp
                          ? context.l10n.haveAccount
                          : context.l10n.firstTime,
                    ),
                  ),
                  if (!_isSignUp)
                    TextButton(
                      onPressed: _busy ? null : _resetPassword,
                      child: Text(context.l10n.forgotPassword),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
