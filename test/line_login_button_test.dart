import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karen_san/l10n.dart';

import 'package:karen_san/line_login_button.dart';

Future<void> _pump(
  WidgetTester tester,
  VoidCallback? onPressed, {
  double width = 320,
}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Center(
        child: SizedBox(
          width: width,
          child: LineLoginButton(onPressed: onPressed),
        ),
      ),
    ),
  );
}

String _iconAsset(WidgetTester tester) =>
    ((tester.widget<Image>(find.byType(Image)).image) as AssetImage).assetName;

void main() {
  testWidgets('公式アイコンと「LINEでログイン」を表示し、押すと呼ばれる', (tester) async {
    var tapped = 0;
    await _pump(tester, () => tapped++);
    expect(find.text('LINEでログイン'), findsOneWidget);
    expect(_iconAsset(tester), 'assets/line/btn_base.png');
    await tester.tap(find.byType(LineLoginButton));
    expect(tapped, 1);
  });

  testWidgets('押している間は押下用のアイコンになる', (tester) async {
    await _pump(tester, () {});
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LineLoginButton)),
    );
    await tester.pump();
    expect(_iconAsset(tester), 'assets/line/btn_press.png');
    await gesture.up();
    await tester.pump();
    expect(_iconAsset(tester), 'assets/line/btn_base.png');
  });

  testWidgets('無効のときは無効用のアイコンで、押しても何も起きない', (tester) async {
    await _pump(tester, null);
    expect(_iconAsset(tester), 'assets/line/btn_disable.png');
    await tester.tap(find.byType(LineLoginButton));
    expect(tester.takeException(), isNull);
  });

  testWidgets('スマホの狭い幅でもはみ出さない', (tester) async {
    await _pump(tester, () {}, width: 240);
    expect(tester.takeException(), isNull);
  });
}
