import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'event_editor_page.dart';
import 'models.dart';
import 'repository.dart';

/// 家族で共有するカレンダー（ログイン後のホーム画面）。
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.user, required this.familyId});

  final User user;
  final String familyId;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _focusedDay = _today();
  late DateTime _selectedDay = _today();
  late Stream<List<CalendarEvent>> _eventsStream = _streamFor(_focusedDay);
  late final Stream<Family> _familyStream =
      Repository.instance.watchFamily(widget.familyId);

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 表示月の前後 1 か月分を読み込む（月をまたぐ予定も表示するため）。
  Stream<List<CalendarEvent>> _streamFor(DateTime month) {
    return Repository.instance.watchEvents(
      widget.familyId,
      from: DateTime(month.year, month.month - 1, 1),
      to: DateTime(month.year, month.month + 2, 1),
    );
  }

  void _onPageChanged(DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      _eventsStream = _streamFor(focusedDay);
    });
  }

  void _openEditor(Family family, {CalendarEvent? event}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EventEditorPage(
        familyId: widget.familyId,
        myName: family.memberNames[widget.user.uid] ??
            Repository.defaultName(widget.user),
        initialDay: _selectedDay,
        event: event,
      ),
    ));
  }

  void _showFamily(Family family) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(family.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('招待コード'),
            const SizedBox(height: 4),
            Row(
              children: [
                SelectableText(
                  family.inviteCode,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                IconButton(
                  tooltip: 'コピー',
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: family.inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('招待コードをコピーしました')),
                    );
                  },
                ),
              ],
            ),
            const Text('家族にこのコードを伝えると、同じカレンダーに参加できます。'),
            const SizedBox(height: 16),
            const Text('メンバー'),
            for (final id in family.memberIds)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('・${family.memberNames[id] ?? '（名前なし）'}'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Family>(
      stream: _familyStream,
      builder: (context, familySnap) {
        final family = familySnap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(family?.name ?? 'カレンさん'),
            actions: [
              if (family != null)
                IconButton(
                  tooltip: 'メンバーと招待',
                  icon: const Icon(Icons.group_add_outlined),
                  onPressed: () => _showFamily(family),
                ),
              IconButton(
                tooltip: 'ログアウト',
                icon: const Icon(Icons.logout),
                onPressed: () => FirebaseAuth.instance.signOut(),
              ),
            ],
          ),
          floatingActionButton: family == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _openEditor(family),
                  icon: const Icon(Icons.add),
                  label: const Text('予定を追加'),
                ),
          body: familySnap.hasError
              ? Center(child: Text('読み込めませんでした：${familySnap.error}'))
              : family == null
                  ? const Center(child: CircularProgressIndicator())
                  : _buildCalendar(family),
        );
      },
    );
  }

  Widget _buildCalendar(Family family) {
    return StreamBuilder<List<CalendarEvent>>(
      stream: _eventsStream,
      builder: (context, snap) {
        final events = snap.data ?? const <CalendarEvent>[];
        List<CalendarEvent> eventsOn(DateTime day) =>
            events.where((e) => e.occursOn(day)).toList();
        final dayEvents = eventsOn(_selectedDay);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                TableCalendar<CalendarEvent>(
                  locale: 'ja_JP',
                  firstDay: DateTime(2000),
                  lastDay: DateTime(2100, 12, 31),
                  focusedDay: _focusedDay,
                  startingDayOfWeek: StartingDayOfWeek.sunday,
                  availableCalendarFormats: const {CalendarFormat.month: '月'},
                  headerStyle: const HeaderStyle(titleCentered: true),
                  selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                  eventLoader: eventsOn,
                  onDaySelected: (selected, focused) => setState(() {
                    _selectedDay =
                        DateTime(selected.year, selected.month, selected.day);
                    _focusedDay = focused;
                  }),
                  onPageChanged: _onPageChanged,
                ),
                const Divider(height: 1),
                if (snap.hasError)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('予定を読み込めませんでした：${snap.error}'),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      DateFormat('M月d日(E)', 'ja').format(_selectedDay),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                Expanded(
                  child: dayEvents.isEmpty
                      ? const Center(child: Text('予定はありません'))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: dayEvents.length,
                          itemBuilder: (context, i) {
                            final e = dayEvents[i];
                            return ListTile(
                              leading: SizedBox(
                                width: 56,
                                child: Text(
                                  e.allDay
                                      ? '終日'
                                      : DateFormat('H:mm').format(e.start),
                                ),
                              ),
                              title: Text(e.title),
                              subtitle: Text([
                                if (!e.allDay)
                                  '〜${DateFormat('M/d H:mm').format(e.end)}',
                                if (e.createdByName.isNotEmpty) e.createdByName,
                              ].join('  ')),
                              onTap: () => _openEditor(family, event: e),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
