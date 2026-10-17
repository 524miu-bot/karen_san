import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karen_san/x_archive/file_pick_io.dart';
import 'package:karen_san/x_archive/x_archive.dart';

void main() {
  test('端末のファイルから ZIP の一部だけを読んで投稿を取り込める', () async {
    const js =
        'window.YTD.tweets.part0 = [ { "tweet" : { "id_str" : "1846000000000000000", '
        '"created_at" : "Wed Oct 15 15:30:00 +0000 2025", "full_text" : "こんにちは", "entities" : { } } } ]';
    final archive = Archive()
      ..addFile(ArchiveFile.bytes('data/tweets.js', utf8.encode(js)));
    final dir = await Directory.systemTemp.createTemp('karen_x');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/twitter.zip')
      ..writeAsBytesSync(ZipEncoder().encode(archive));

    final raf = await file.open();
    addTearDown(raf.close);
    final reader = XArchiveReader();
    expect(await reader.addZip(IoFileSource(raf, await file.length())), 1);
    expect(reader.posts.single.text, 'こんにちは');
  });
}
