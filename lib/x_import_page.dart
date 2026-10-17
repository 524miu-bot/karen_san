import 'dart:convert';

import 'package:flutter/material.dart';

import 'l10n.dart';
import 'repository.dart';
import 'x_archive/file_pick_stub.dart'
    if (dart.library.io) 'x_archive/file_pick_io.dart'
    if (dart.library.js_interop) 'x_archive/file_pick_web.dart';
import 'x_archive/x_archive.dart';

/// X のアーカイブを取り込み、カレンダーで日記のように読めるようにする画面。
class XImportPage extends StatefulWidget {
  const XImportPage({super.key, required this.uid});

  final String uid;

  @override
  State<XImportPage> createState() => _XImportPageState();
}

class _XImportPageState extends State<XImportPage> {
  bool _busy = false;
  String? _status;
  String? _error;
  int? _days;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    try {
      final n = await Repository.instance.countXDays(widget.uid);
      if (mounted) setState(() => _days = n);
    } catch (_) {
      // 件数が出せなくても取り込みはできる
    }
  }

  Future<void> _import() async {
    final files = await pickArchiveFiles();
    if (files.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = context.l10n.xImportReading;
    });
    try {
      final reader = XArchiveReader();
      var found = 0;
      for (final f in files) {
        if (f.name.toLowerCase().endsWith('.zip')) {
          found += await reader.addZip(f.source);
        } else if (archiveFileKind(f.name) != null) {
          final bytes = await f.source.read(0, f.source.length);
          reader.addJs(f.name, utf8.decode(bytes, allowMalformed: true));
          found++;
        }
      }
      if (found == 0) {
        setState(() => _error = context.l10n.xImportNotFound);
        return;
      }
      setState(() => _status = context.l10n.xImportSaving);
      await Repository.instance.importXPosts(
        widget.uid,
        reader.posts,
        onProgress: (done, total) {
          if (mounted) {
            setState(
              () => _status = context.l10n.xImportSavingProgress(done, total),
            );
          }
        },
      );
      setState(
        () => _status = context.l10n.xImportDone(reader.tweets, reader.likes),
      );
      await _refreshCount();
    } catch (e) {
      setState(() => _error = context.l10n.xImportFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.xDeleteAllTitle),
        content: Text(context.l10n.xDeleteAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = context.l10n.deleting;
    });
    try {
      await Repository.instance.deleteAllXPosts(widget.uid);
      setState(() => _status = context.l10n.deleted);
      await _refreshCount();
    } catch (e) {
      setState(() => _error = context.l10n.deleteFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.xImportTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(context.l10n.xImportIntro),
              const SizedBox(height: 8),
              Text(context.l10n.xImportNotes),
              const SizedBox(height: 24),
              Text(context.l10n.xImportStep1, style: text.titleMedium),
              const SizedBox(height: 8),
              Text(context.l10n.xImportStep1Body),
              const SizedBox(height: 16),
              Text(context.l10n.xImportStep2, style: text.titleMedium),
              const SizedBox(height: 8),
              Text(context.l10n.xImportStep2Body),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _import,
                icon: const Icon(Icons.upload_file),
                label: Text(context.l10n.xImportPick),
              ),
              const SizedBox(height: 16),
              if (_busy) const LinearProgressIndicator(),
              if (_status != null) ...[
                const SizedBox(height: 8),
                Text(_status!),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _days == null
                      ? context.l10n.xImportedCounting
                      : context.l10n.xImportedDays(_days!),
                ),
                trailing: TextButton(
                  onPressed: _busy || (_days ?? 0) == 0 ? null : _deleteAll,
                  child: Text(context.l10n.deleteAll),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
