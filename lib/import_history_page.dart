import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'l10n.dart';
import 'models.dart';
import 'repository.dart';

/// 「まとめて追加」の履歴。思っていたのと違ったら、1 回分をまとめて取り消せる。
class ImportHistoryPage extends StatefulWidget {
  const ImportHistoryPage({super.key, required this.place});

  final Place place;

  @override
  State<ImportHistoryPage> createState() => _ImportHistoryPageState();
}

class _ImportHistoryPageState extends State<ImportHistoryPage> {
  late final Stream<List<ImportRecord>> _stream = Repository.instance
      .watchImports(widget.place.uid);
  final Set<String> _busy = {};

  Future<void> _undo(ImportRecord r) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.importUndoTitle(r.count)),
        content: Text(l10n.importUndoBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l10n.importUndo),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy.add(r.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Repository.instance.undoImport(widget.place, r.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.importUndone)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.importUndoFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final day = DateFormat.MMMd(locale);
    final when = DateFormat.MMMd(locale).add_Hm();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.importHistoryTitle)),
      body: StreamBuilder<List<ImportRecord>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(l10n.loadFailed('${snap.error}')));
          }
          final list = snap.data;
          if (list == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.importHistoryHelp),
              const SizedBox(height: 12),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Center(child: Text(l10n.importHistoryEmpty)),
                ),
              for (final r in list)
                Card(
                  child: ListTile(
                    leading: Icon(
                      r.source == 'photo'
                          ? Icons.photo_camera_outlined
                          : Icons.notes,
                    ),
                    title: Text(
                      [
                        l10n.importCount(r.count),
                        if (r.from != null && r.to != null)
                          r.from!.month == r.to!.month &&
                                  r.from!.day == r.to!.day
                              ? day.format(r.from!)
                              : '${day.format(r.from!)}${l10n.rangeSeparator}${day.format(r.to!)}',
                      ].join('  '),
                    ),
                    subtitle: Text(
                      [
                        if (r.createdAt != null)
                          l10n.importAddedAt(when.format(r.createdAt!)),
                        if (r.titles.isNotEmpty)
                          r.titles.join('、') +
                              (r.count > r.titles.length ? '…' : ''),
                      ].join('\n'),
                    ),
                    isThreeLine: r.titles.isNotEmpty && r.createdAt != null,
                    trailing: _busy.contains(r.id)
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: () => _undo(r),
                            child: Text(l10n.importUndo),
                          ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
