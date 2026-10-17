// ファイル選択（Web 版）。選んだファイルは必要な部分だけを読む。
import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'zip_reader.dart';

class PickedFile {
  PickedFile(this.name, this.source);
  final String name;
  final RandomAccessSource source;
}

class WebFileSource implements RandomAccessSource {
  WebFileSource(this._file);
  final web.File _file;

  @override
  int get length => _file.size;

  @override
  Future<Uint8List> read(int start, int end) async {
    final buffer = await _file.slice(start, end).arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }
}

/// ZIP または .js ファイルを選んでもらう。キャンセルなら空のリスト。
Future<List<PickedFile>> pickArchiveFiles() {
  final completer = Completer<List<PickedFile>>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = true
    ..accept = '.zip,.js,application/zip,text/javascript';
  input.onchange = (web.Event _) {
    final files = input.files;
    final picked = <PickedFile>[];
    if (files != null) {
      for (var i = 0; i < files.length; i++) {
        final f = files.item(i)!;
        picked.add(PickedFile(f.name, WebFileSource(f)));
      }
    }
    if (!completer.isCompleted) completer.complete(picked);
  }.toJS;
  input.addEventListener(
      'cancel',
      (web.Event _) {
        if (!completer.isCompleted) completer.complete(const []);
      }.toJS);
  input.click();
  return completer.future;
}
