import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';

/// Face ID / Touch ID（または端末のパスコード）でのロック。
/// 設定は端末ごとに保存し、iPhone などのアプリ版だけで使える（Web 版では出さない）。
class AppLock {
  AppLock._();

  static const _key = 'app_lock_enabled';

  static bool get isAvailableOnPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// この端末で使えるか（生体認証かパスコードが設定されているか）。
  static Future<bool> isSupported() async {
    if (!isAvailableOnPlatform) return false;
    try {
      return await LocalAuthentication().isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    if (!isAvailableOnPlatform) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }

  /// 本人確認を行う。成功すれば true。顔・指紋が使えないときは端末のパスコードでも解除できる。
  static Future<bool> authenticate(String reason) async {
    try {
      return await LocalAuthentication().authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}

/// ロックが有効なら、起動時とアプリに戻ってきたときに本人確認を求める。
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _locked = AppLock.isAvailableOnPlatform; // 設定を読むまでは中身を見せない
  bool _authenticating = false;
  DateTime? _backgroundedAt;

  /// 少しの間ほかのアプリに切り替えただけなら、ロックし直さない。
  static const _grace = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOnStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkOnStart() async {
    final enabled = await AppLock.isEnabled();
    if (!mounted) return;
    setState(() => _locked = enabled);
    if (enabled) _unlock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _backgroundedAt != null) {
      final away = DateTime.now().difference(_backgroundedAt!);
      _backgroundedAt = null;
      if (away >= _grace) _lockIfEnabled();
    }
  }

  Future<void> _lockIfEnabled() async {
    if (!await AppLock.isEnabled() || !mounted) return;
    setState(() => _locked = true);
    _unlock();
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    _authenticating = true;
    final reason = context.l10n.unlockReason;
    final ok = await AppLock.authenticate(reason);
    _authenticating = false;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundImage: AssetImage('assets/branding/karen.png'),
            ),
            const SizedBox(height: 16),
            const Icon(Icons.lock_outline, size: 32),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _unlock,
              icon: const Icon(Icons.face),
              label: Text(context.l10n.unlock),
            ),
          ],
        ),
      ),
    );
  }
}

/// 設定画面に置く「Face ID でロック」のスイッチ。使えない環境では何も表示しない。
class AppLockSwitch extends StatefulWidget {
  const AppLockSwitch({super.key});

  @override
  State<AppLockSwitch> createState() => _AppLockSwitchState();
}

class _AppLockSwitchState extends State<AppLockSwitch> {
  bool? _supported;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final supported = await AppLock.isSupported();
    final enabled = await AppLock.isEnabled();
    if (mounted) {
      setState(() {
        _supported = supported;
        _enabled = enabled;
      });
    }
  }

  Future<void> _toggle(bool value) async {
    // オンにするときも、本人だと確かめてから（使えることの確認も兼ねる）
    final ok = await AppLock.authenticate(context.l10n.unlockReason);
    if (!ok) return;
    await AppLock.setEnabled(value);
    if (mounted) setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    if (_supported != true) return const SizedBox.shrink();
    return SwitchListTile(
      secondary: const Icon(Icons.face),
      title: Text(context.l10n.appLock),
      subtitle: Text(context.l10n.appLockHelp),
      value: _enabled,
      onChanged: _toggle,
    );
  }
}
