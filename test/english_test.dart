import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:karen_san/account_deletion.dart';
import 'package:karen_san/l10n.dart';
import 'package:karen_san/login_page.dart';
import 'package:karen_san/main.dart' show resolveAppLocale;

Widget _app(Widget home, Locale locale) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  setUpAll(() => initializeDateFormatting());

  test('端末の言語：日本語なら日本語、英語やその他の言語は英語', () {
    expect(resolveAppLocale(const [Locale('ja', 'JP')]), const Locale('ja'));
    expect(resolveAppLocale(const [Locale('en', 'US')]), const Locale('en'));
    expect(
      resolveAppLocale(const [Locale('fr', 'FR'), Locale('ja')]),
      const Locale('ja'),
    );
    expect(resolveAppLocale(const [Locale('th', 'TH')]), const Locale('en'));
    expect(resolveAppLocale(null), const Locale('en'));
  });

  testWidgets('英語ではログイン画面が英語になる', (tester) async {
    await tester.pumpWidget(_app(const LoginPage(), const Locale('en')));
    expect(find.text('Karen-san'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('New here? Sign up'), findsOneWidget);
    expect(find.textContaining('ログイン'), findsNothing);
  });

  testWidgets('英語のアカウント削除は「DELETE」と入力して確認する', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmAndDeleteAccount(context),
            child: const Text('open'),
          ),
        ),
        const Locale('en'),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    FilledButton button() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Delete'),
    );
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(button().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pump();
    expect(button().onPressed, isNotNull);
  });

  test('日付の書式が言語に合う', () {
    final d = DateTime(2026, 10, 18);
    expect(DateFormat.MMMEd('ja').format(d), '10月18日(日)');
    expect(DateFormat.MMMEd('en').format(d), 'Sun, Oct 18');
    expect(DateFormat.yMMMM('ja').format(d), '2026年10月');
    expect(DateFormat.yMMMM('en').format(d), 'October 2026');
  });

  test('日本語と英語で同じ文言がそろっている', () async {
    final ja = await AppLocalizations.delegate.load(const Locale('ja'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(ja.appTitle, 'カレンさん');
    expect(en.appTitle, 'Karen-san');
    expect(ja.xImportDone(3, 2), '取り込みました：投稿 3 件、いいね 2 件');
    expect(en.xImportDone(3, 2), 'Imported 3 posts and 2 likes');
  });
}
