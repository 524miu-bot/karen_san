import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'calendar_page.dart';
import 'family_settings_page.dart';
import 'l10n.dart';
import 'models.dart';
import 'repository.dart';
import 'routine_page.dart';
import 'todo_page.dart';

/// ログイン後の画面。下のタブでカレンダー・ルーティーン・TODO・設定を切り替える。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.user, required this.familyId});

  final User user;
  final String familyId;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  late final Stream<Family> _family = Repository.instance.watchFamily(
    widget.familyId,
  );
  late final Place _place = Place(
    familyId: widget.familyId,
    uid: widget.user.uid,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StreamBuilder<Family>(
      stream: _family,
      builder: (context, snap) {
        final family = snap.data;
        final Widget body;
        if (snap.hasError) {
          body = Scaffold(
            body: Center(child: Text(l10n.loadFailed('${snap.error}'))),
          );
        } else if (family == null) {
          body = const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else {
          // タブを切り替えても表示中の月などを保つため、IndexedStack で残しておく
          body = IndexedStack(
            index: _tab,
            children: [
              CalendarPage(user: widget.user, familyId: widget.familyId),
              RoutinePage(family: family, place: _place),
              TodoPage(family: family, place: _place),
              FamilySettingsPage(
                familyId: widget.familyId,
                uid: widget.user.uid,
              ),
            ],
          );
        }
        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.calendar_month_outlined),
                selectedIcon: const Icon(Icons.calendar_month),
                label: l10n.tabCalendar,
              ),
              NavigationDestination(
                icon: const Icon(Icons.repeat),
                label: l10n.tabRoutine,
              ),
              NavigationDestination(
                icon: const Icon(Icons.checklist_outlined),
                selectedIcon: const Icon(Icons.checklist),
                label: l10n.tabTodo,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: l10n.tabSettings,
              ),
            ],
          ),
        );
      },
    );
  }
}
