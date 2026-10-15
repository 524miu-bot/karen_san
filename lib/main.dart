import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'calendar_page.dart';
import 'family_setup_page.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('ja');
  runApp(const KarenSanApp());
}

class KarenSanApp extends StatelessWidget {
  const KarenSanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'カレンさん',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AuthGate(),
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
                  child: Text('読み込めませんでした：${familySnap.error}'),
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
                : CalendarPage(
                    key: ValueKey(familyId), user: user, familyId: familyId);
          },
        );
      },
    );
  }
}
