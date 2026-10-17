import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karen_san/x_archive/x_archive.dart';
import 'package:karen_san/x_archive/zip_reader.dart';

const _tweetsJs = '''window.YTD.tweets.part0 = [ {
  "tweet" : {
    "id_str" : "1846000000000000000",
    "created_at" : "Wed Oct 15 15:30:00 +0000 2025",
    "full_text" : "推しのライブ最高 &amp; 泣いた https://t.co/abc https://t.co/img",
    "entities" : {
      "urls" : [ { "url" : "https://t.co/abc", "expanded_url" : "https://example.com/live" } ],
      "media" : [ { "url" : "https://t.co/img" } ]
    }
  }
}, {
  "tweet" : {
    "id_str" : "1846000000000000001",
    "created_at" : "Thu Oct 16 01:00:00 +0000 2025",
    "full_text" : "@friend ありがとう",
    "in_reply_to_status_id_str" : "1845999999999999999",
    "entities" : { }
  }
}, {
  "tweet" : {
    "id_str" : "1846000000000000002",
    "created_at" : "Thu Oct 16 02:00:00 +0000 2025",
    "full_text" : "RT @oshi: 新曲公開！",
    "entities" : { }
  }
} ]''';

const _likesJs = '''window.YTD.like.part0 = [ {
  "like" : {
    "tweetId" : "1846000000000000000",
    "fullText" : "推しの投稿",
    "expandedUrl" : "https://twitter.com/i/web/status/1846000000000000000"
  }
}, {
  "like" : { "tweetId" : "12345", "fullText" : "とても古い投稿" }
} ]''';

Uint8List _zip(Map<String, String> files, {bool store = false}) {
  final archive = Archive();
  files.forEach((name, content) {
    final f = ArchiveFile.bytes(name, utf8.encode(content));
    if (store) f.compression = CompressionType.none;
    archive.addFile(f);
  });
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  group('ZipReader', () {
    test('圧縮されたファイルも無圧縮のファイルも取り出せる', () async {
      for (final store in [false, true]) {
        final reader = await ZipReader.open(
          BytesSource(
            _zip({
              'data/tweets.js': _tweetsJs,
              'data/tweets_media/photo.jpg': 'x' * 1000,
            }, store: store),
          ),
        );
        expect(
          reader.entries.map((e) => e.name),
          containsAll(['data/tweets.js', 'data/tweets_media/photo.jpg']),
        );
        final entry = reader.entries.firstWhere(
          (e) => e.name == 'data/tweets.js',
        );
        expect(utf8.decode(await reader.extract(entry)), _tweetsJs);
      }
    });

    test('ZIP でないファイルはエラー', () async {
      expect(
        ZipReader.open(BytesSource(Uint8List.fromList(utf8.encode('hello')))),
        throwsA(isA<ZipFormatException>()),
      );
    });
  });

  group('X アーカイブ', () {
    test('投稿の日時・本文・種類を読み、短縮 URL を戻して画像 URL を消す', () {
      final posts = parseTweets(parseYtd(_tweetsJs));
      expect(posts, hasLength(3));
      expect(posts[0].postedAt, DateTime.utc(2025, 10, 15, 15, 30));
      expect(posts[0].text, '推しのライブ最高 & 泣いた https://example.com/live');
      expect(posts[0].hasMedia, isTrue);
      expect(posts[0].kind, XPostKind.post);
      expect(posts[1].kind, XPostKind.reply);
      expect(posts[2].kind, XPostKind.repost);
    });

    test('いいねは元の投稿の日時（ID から計算）で、古すぎる ID は除く', () {
      final likes = parseLikes(parseYtd(_likesJs));
      expect(likes, hasLength(1));
      expect(likes.single.kind, XPostKind.like);
      // ID 1846000000000000000 は 2024-10-15 ごろの投稿
      expect(likes.single.postedAt.year, 2024);
      expect(likes.single.postedAt.month, 10);
    });

    test('ID から投稿日時を求める（既知の値）', () {
      // 20 は 2006 年の ID なので対象外
      expect(snowflakeTime('20'), isNull);
      // (1846000000000000000 >> 22) + 1288834974657 ミリ秒
      final t = snowflakeTime('1846000000000000000')!;
      expect(
        t.millisecondsSinceEpoch,
        (BigInt.parse('1846000000000000000') >> 22).toInt() + 1288834974657,
      );
    });

    test('日付はタイムゾーンを反映する（UTC 15:30 は日本時間で翌日）', () {
      final posts = parseTweets(parseYtd(_tweetsJs));
      final expected = DateTime.utc(2025, 10, 15, 15, 30).toLocal();
      expect(
        dayKey(posts[0].postedAt),
        '${expected.year}-${expected.month.toString().padLeft(2, '0')}-${expected.day.toString().padLeft(2, '0')}',
      );
    });

    test('読み込むファイルを名前で見分ける', () {
      expect(archiveFileKind('data/tweets.js'), XArchiveFileKind.tweets);
      expect(archiveFileKind('data/tweets-part1.js'), XArchiveFileKind.tweets);
      expect(archiveFileKind('data/tweet.js'), XArchiveFileKind.tweets);
      expect(archiveFileKind('data/like.js'), XArchiveFileKind.likes);
      expect(archiveFileKind('data/deleted-tweets.js'), isNull);
      expect(archiveFileKind('data/tweets_media/a.jpg'), isNull);
      expect(archiveFileKind('data/account.js'), isNull);
    });

    test('ZIP から投稿といいねをまとめて読む', () async {
      final reader = XArchiveReader();
      final found = await reader.addZip(
        BytesSource(
          _zip({
            'data/tweets.js': _tweetsJs,
            'data/like.js': _likesJs,
            'data/deleted-tweets.js': _tweetsJs,
            'Your archive.html': '<html></html>',
          }),
        ),
      );
      expect(found, 2);
      expect(reader.tweets, 3);
      expect(reader.likes, 1);
      expect(reader.posts, hasLength(4));
    });
  });
}
