// ファイル選択（Web 以外・テスト用の代わり）。
import 'zip_reader.dart';

class PickedFile {
  PickedFile(this.name, this.source);
  final String name;
  final RandomAccessSource source;
}

Future<List<PickedFile>> pickArchiveFiles() async =>
    throw UnsupportedError('ファイルの取り込みは Web 版でのみ使えます');
