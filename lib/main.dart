import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_lock.dart';
import 'home_shell.dart';
import 'family_setup_page.dart';
import 'firebase_options.dart';
import 'l10n.dart';
import 'login_page.dart';
import 'repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting();
  runApp(const KarenSanApp());
}

/// 端末の言語が日本語なら日本語、それ以外は英語。
Locale resolveAppLocale(List<Locale>? deviceLocales) {
  for (final l in deviceLocales ?? const <Locale>[]) {
    if (l.languageCode == 'ja') return const Locale('ja');
    if (l.languageCode == 'en') return const Locale('en');
  }
  return const Locale('en');
}

class KarenSanApp extends StatelessWidget {
  const KarenSanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeListResolutionCallback: (locales, _) => resolveAppLocale(locales),
      // ロックはアプリ版でオンにした人だけ（Web 版では何もしない）
      home: const AppLockGate(child: AuthGate()),
    );
  }
}

/// ログイン状態と家族の所属状況に応じて画面を切り替える。
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  static const _loading = Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loading;
        }
        final user = snapshot.data;
        if (user == null) return const LoginPage();
        return StreamBuilder<String?>(
          key: ValueKey(user.uid),
          stream: Repository.instance.watchFamilyId(user.uid),
          builder: (context, familySnap) {
            if (familySnap.hasError) {
              return Scaffold(
                body: Center(
                  child: Text(context.l10n.loadFailed('${familySnap.error}')),
                ),
              );
            }
            if (!familySnap.hasData &&
                familySnap.connectionState == ConnectionState.waiting) {
              return _loading;
            }
            final familyId = familySnap.data;
            return familyId == null
                ? FamilySetupPage(user: user)
                : HomeShell(
                    key: ValueKey(familyId),
                    user: user,
                    familyId: familyId,
                  );
          },
        );
      },
    );
  }
}
