// ファイル選択（iPhone などのアプリ版）。選んだファイルは必要な部分だけを読む。
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp;

import 'zip_reader.dart';

class PickedFile {
  PickedFile(this.name, this.source);
  final String name;
  final RandomAccessSource source;
}

class IoFileSource implements RandomAccessSource {
  IoFileSource(this._file, this.length);

  final RandomAccessFile _file;

  @override
  final int length;

  @override
  Future<Uint8List> read(int start, int end) async {
    await _file.setPosition(start);
    return _file.read(end - start);
  }
}

/// ZIP または .js ファイルを選んでもらう。キャンセルなら空のリスト。
Future<List<PickedFile>> pickArchiveFiles() async {
  final files = await fp.FilePicker.pickFiles();
  final picked = <PickedFile>[];
  for (final f in files) {
    final path = f.path;
    if (path == null) continue;
    final file = File(path);
    picked.add(
      PickedFile(f.name, IoFileSource(await file.open(), await file.length())),
    );
  }
  return picked;
}
