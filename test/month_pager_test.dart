import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:karen_san/calendar_page.dart';
import 'package:karen_san/categories.dart';
import 'package:karen_san/l10n.dart';

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('ja'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  setUpAll(() => initializeDateFormatting());
  final thisMonth = DateTime(2026, 11);

  testWidgets('上下のスクロールで月が変わり、「今日」で今月に戻る', (tester) async {
    final changed = <DateTime>[];
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 400,
          height: 700,
          child: MonthPager(
            initialPage: monthPagerCenter,
            thisMonth: thisMonth,
            onMonthChanged: changed.add,
            buildMonth: (m) => Center(child: Text('page ${m.year}-${m.month}')),
          ),
        ),
      ),
    );
    expect(find.text('2026年11月'), findsOneWidget);
    expect(find.text('page 2026-11'), findsOneWidget);

    // 上にスワイプ → 次の月
    await tester.fling(find.text('page 2026-11'), const Offset(0, -400), 1500);
    await tester.pumpAndSettle();
    expect(find.text('2026年12月'), findsOneWidget);
    expect(changed.last, DateTime(2026, 12));

    // もう一度 → 年をまたいで 1 月
    await tester.fling(find.text('page 2026-12'), const Offset(0, -400), 1500);
    await tester.pumpAndSettle();
    expect(find.text('2027年1月'), findsOneWidget);

    // 「今日」ボタンで今月へ
    await tester.tap(find.byTooltip('今日'));
    await tester.pumpAndSettle();
    expect(find.text('2026年11月'), findsOneWidget);
    expect(changed.last, DateTime(2026, 11));
  });

  testWidgets('左右のスワイプで表示カレンダーが切り替わり、ボタンも連動する', (tester) async {
    const views = [
      CalendarViewDef(id: 'all', name: 'すべて'),
      CalendarViewDef(id: 'v1', name: '家庭', categoryIds: {'family'}),
      CalendarViewDef(id: 'v2', name: 'バスケ＋空手', categoryIds: {'b', 'k'}),
    ];
    final controller = PageController();
    var selected = 0;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 400,
            height: 700,
            child: Column(
              children: [
                ViewChips(
                  views: views,
                  selected: selected,
                  onSelected: (i) => controller.jumpToPage(i),
                  onEdit: () {},
                ),
                Expanded(
                  child: PageView.builder(
                    controller: controller,
                    itemCount: views.length,
                    onPageChanged: (i) => setState(() => selected = i),
                    itemBuilder: (context, i) => MonthPager(
                      key: ValueKey(views[i].id),
                      initialPage: monthPagerCenter,
                      thisMonth: thisMonth,
                      onMonthChanged: (_) {},
                      buildMonth: (m) =>
                          Center(child: Text('view ${views[i].name}')),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    bool isSelected(String name) => tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, name))
        .selected;

    expect(find.text('view すべて'), findsOneWidget);
    expect(isSelected('すべて'), isTrue);

    // 左にスワイプ → 次の表示カレンダー
    await tester.fling(find.text('view すべて'), const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('view 家庭'), findsOneWidget);
    expect(isSelected('家庭'), isTrue);

    // ボタンを押して直接切り替え
    await tester.tap(find.text('バスケ＋空手'));
    await tester.pumpAndSettle();
    expect(find.text('view バスケ＋空手'), findsOneWidget);
    expect(isSelected('バスケ＋空手'), isTrue);
  });

  testWidgets('ボタンの並びの最後に「＋ 追加」があり、押すと追加の処理を呼ぶ', (tester) async {
    var added = 0;
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 400,
          child: ViewChips(
            views: const [CalendarViewDef(id: 'all', name: 'すべて')],
            selected: 0,
            onSelected: (_) {},
            onEdit: () {},
            onAdd: () => added++,
          ),
        ),
      ),
    );
    expect(find.widgetWithText(ActionChip, '追加'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, '追加'));
    expect(added, 1);
  });
}
