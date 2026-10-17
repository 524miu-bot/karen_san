import 'dart:convert';

import 'package:flutter/material.dart';

import 'repository.dart';
import 'x_archive/file_pick_stub.dart'
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
      _status = 'ファイルを読んでいます…';
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
        setState(() => _error =
            '投稿のファイルが見つかりませんでした。X からダウンロードした ZIP ファイル、'
            'または中の data フォルダにある tweets.js・like.js を選んでください。');
        return;
      }
      setState(() => _status = '保存しています…');
      await Repository.instance.importXPosts(
        widget.uid,
        reader.posts,
        onProgress: (done, total) {
          if (mounted) setState(() => _status = '保存しています…（$done / $total 日）');
        },
      );
      setState(() => _status =
          '取り込みました：投稿 ${reader.tweets} 件、いいね ${reader.likes} 件');
      await _refreshCount();
    } catch (e) {
      setState(() => _error = '取り込めませんでした：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取り込んだ X の投稿をすべて削除しますか？'),
        content: const Text('カレンさんに保存した分だけが消えます。X の投稿そのものは消えません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = '削除しています…';
    });
    try {
      await Repository.instance.deleteAllXPosts(widget.uid);
      setState(() => _status = '削除しました');
      await _refreshCount();
    } catch (e) {
      setState(() => _error = '削除できませんでした：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('X の投稿を取り込む')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '自分の投稿と「いいね」した投稿を取り込むと、カレンダーの日付を押したときに'
                'その日の投稿を日記のように読めます。',
              ),
              const SizedBox(height: 8),
              const Text(
                '・取り込んだ投稿は、あなただけが見られます（家族には見えません）。\n'
                '・「いいね」した投稿は、いいねした日ではなく元の投稿の日付に表示されます。\n'
                '・同じアーカイブを何度取り込んでも重複しません。新しい投稿は、'
                'ときどきアーカイブを取り直して取り込んでください。',
              ),
              const SizedBox(height: 24),
              Text('1. X でアーカイブを依頼する', style: text.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'X のアプリかサイトで「設定とプライバシー」→「アカウント」→'
                '「データのアーカイブをダウンロード」を開き、パスワードを入れて依頼します。'
                '準備ができるまで 1 日以上かかることがあり、できたら X から通知が届きます。',
              ),
              const SizedBox(height: 16),
              Text('2. ダウンロードした ZIP を選ぶ', style: text.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'iPhone では「ファイル」アプリに保存された ZIP をそのまま選べます。'
                'うまくいかないときは、ファイルアプリで ZIP を開いて展開し、'
                '中の data フォルダにある tweets.js と like.js を選んでください。',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _import,
                icon: const Icon(Icons.upload_file),
                label: const Text('ファイルを選んで取り込む'),
              ),
              const SizedBox(height: 16),
              if (_busy) const LinearProgressIndicator(),
              if (_status != null) ...[
                const SizedBox(height: 8),
                Text(_status!),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_days == null ? '取り込み済み：確認中…' : '取り込み済み：$_days 日分'),
                trailing: TextButton(
                  onPressed: _busy || (_days ?? 0) == 0 ? null : _deleteAll,
                  child: const Text('すべて削除'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
