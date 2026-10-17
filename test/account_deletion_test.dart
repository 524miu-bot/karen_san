import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karen_san/l10n.dart';

import 'package:karen_san/account_deletion.dart';

void main() {
  testWidgets('「削除」と入力するまで削除ボタンは押せない', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmAndDeleteAccount(context),
            child: const Text('開く'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();

    FilledButton deleteButton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, '削除する'));

    expect(find.text('アカウントを削除しますか？'), findsOneWidget);
    expect(deleteButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'さくじょ');
    await tester.pump();
    expect(deleteButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), '削除');
    await tester.pump();
    expect(deleteButton().onPressed, isNotNull);

    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(find.text('アカウントを削除しますか？'), findsNothing);
  });
}
