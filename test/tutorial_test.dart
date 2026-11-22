import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:karen_san/l10n/app_localizations.dart';
import 'package:karen_san/tutorial_page.dart';

Widget _app() => MaterialApp(
  locale: const Locale('ja'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => TutorialPage.showOnce(context),
        child: const Text('open'),
      ),
    ),
  ),
);

void main() {
  testWidgets('初めてだけ出て、次へで最後まで進み、はじめるで閉じる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('カレンさんへようこそ'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();
    }
    expect(find.text('家族を招待する'), findsOneWidget);
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);

    // 2 回目は出ない
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('カレンさんへようこそ'), findsNothing);
  });
}
