import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karen_san/color_picker.dart';
import 'package:karen_san/l10n.dart';
import 'package:karen_san/models.dart';

void main() {
  testWidgets('8 色のほかに 9 つ目で好きな色を作って選べる', (tester) async {
    Color? picked;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ColorChoices(
            selected: memberPalette.first,
            onSelected: (c) => picked = c,
          ),
        ),
      ),
    );
    // 用意した 8 色 + 好きな色の 1 つ
    expect(find.byType(CircleAvatar), findsNWidgets(8));
    expect(find.byIcon(Icons.add), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('好きな色'), findsWidgets);
    expect(find.text('予定の見え方'), findsOneWidget);

    // 色合いを動かしてから決定
    await tester.drag(find.byType(Slider).first, const Offset(80, 0));
    await tester.pump();
    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(
      memberPalette.map((c) => c.toARGB32()),
      isNot(contains(picked!.toARGB32())),
    );
    // 白い文字が読めるよう、明るすぎない色になる
    expect(HSLColor.fromColor(picked!).lightness, lessThanOrEqualTo(0.56));
  });

  testWidgets('好きな色を選んでいるときは 9 つ目がその色になる', (tester) async {
    const custom = Color(0xFF117755);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ColorChoices(selected: custom, onSelected: (_) {}),
        ),
      ),
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
    final box = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.check),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((box.decoration as BoxDecoration).color, custom);
  });
}
