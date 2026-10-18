import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karen_san/l10n.dart';

import 'package:karen_san/login_page.dart';

void main() {
  testWidgets('ログイン画面に Google とメールのログイン手段が表示される', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoginPage(),
      ),
    );

    expect(find.text('Google でログイン'), findsOneWidget);
    expect(find.text('メールアドレス'), findsOneWidget);
    expect(find.text('パスワード'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ログイン'), findsOneWidget);

    await tester.tap(find.text('はじめての方はこちら（新規登録）'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, '新規登録'), findsOneWidget);
  });
}
