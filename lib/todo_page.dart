import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'l10n.dart';
import 'models.dart';
import 'planner.dart';
import 'repository.dart';
import 'streams.dart';

/// 今週中にやること。家庭の TODO はグループで共有し、仕事の TODO は本人だけ。
class TodoPage extends StatefulWidget {
  const TodoPage({super.key, required this.family, required this.place});

  final Family family;
  final Place place;

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final _input = TextEditingController();
  CalendarKind _kind = CalendarKind.family;
  late final String _weekKey = weekKeyOf(DateTime.now());
  late final Stream<List<Todo>> _todos = combineLatestLists([
    Repository.instance.watchTodos(widget.place, CalendarKind.family, _weekKey),
    Repository.instance.watchTodos(widget.place, CalendarKind.work, _weekKey),
  ]);

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _input.text.trim();
    if (title.isEmpty) return;
    _input.clear();
    try {
      await Repository.instance.saveTodo(
        widget.place,
        Todo(title: title, weekKey: _weekKey, kind: _kind),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.saveFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final start = weekStartOf(DateTime.now());
    final end = DateTime(start.year, start.month, start.day + 6);
    final md = DateFormat.MMMd(l10n.localeName);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.todoTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${md.format(start)}${l10n.rangeSeparator}${md.format(end)}',
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    SegmentedButton<CalendarKind>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: CalendarKind.family,
                          icon: const Icon(Icons.home_outlined),
                          tooltip: l10n.family,
                        ),
                        ButtonSegment(
                          value: CalendarKind.work,
                          icon: const Icon(Icons.work_outline),
                          tooltip: l10n.work,
                        ),
                      ],
                      selected: {_kind},
                      onSelectionChanged: (s) =>
                          setState(() => _kind = s.first),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _input,
                        maxLength: 200,
                        decoration: InputDecoration(
                          hintText: _kind == CalendarKind.work
                              ? l10n.todoHintWork
                              : l10n.todoHintFamily,
                          counterText: '',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _add(),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: l10n.add,
                      onPressed: _add,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Todo>>(
                  stream: _todos,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Text(l10n.loadFailed('${snap.error}')),
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final r = todosForWeek(snap.data!, _weekKey);
                    if (r.carried.isEmpty && r.thisWeek.isEmpty) {
                      return Center(child: Text(l10n.todoEmpty));
                    }
                    return ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        if (r.carried.isNotEmpty) ...[
                          _header(context, l10n.todoCarried),
                          for (final t in r.carried) _tile(t, carried: true),
                        ],
                        if (r.thisWeek.isNotEmpty) ...[
                          _header(context, l10n.todoThisWeek),
                          for (final t in r.thisWeek) _tile(t),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _tile(Todo t, {bool carried = false}) {
    final l10n = context.l10n;
    return Dismissible(
      key: ValueKey('${t.kind.name}/${t.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) => Repository.instance.deleteTodo(widget.place, t),
      child: CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        value: t.done,
        onChanged: (v) =>
            Repository.instance.setTodoDone(widget.place, t, v ?? false),
        title: Text(
          t.title,
          style: t.done
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: Theme.of(context).disabledColor,
                )
              : null,
        ),
        secondary: Icon(
          t.kind == CalendarKind.work
              ? Icons.work_outline
              : Icons.home_outlined,
          size: 18,
          color: t.kind == CalendarKind.work ? workColor : null,
          semanticLabel: t.kind == CalendarKind.work ? l10n.work : l10n.family,
        ),
        subtitle: carried
            ? Text(l10n.todoFromWeek(_weekLabel(t.weekKey)))
            : null,
      ),
    );
  }

  String _weekLabel(String key) {
    final d = DateTime.tryParse(key);
    if (d == null) return key;
    return DateFormat.MMMd(context.localeName).format(d);
  }
}
