import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show Inflate;

/// 一部分だけを読み出せるファイル（ブラウザの File など）。
///
/// X のアーカイブは画像込みで数百 MB になることがあるので、
/// 全体をメモリに読み込まず、必要な部分だけを読む。
abstract class RandomAccessSource {
  int get length;

  /// [start] から [end] の手前までを読む。
  Future<Uint8List> read(int start, int end);
}

/// メモリ上のバイト列（テスト用）。
class BytesSource implements RandomAccessSource {
  BytesSource(this.bytes);
  final Uint8List bytes;

  @override
  int get length => bytes.length;

  @override
  Future<Uint8List> read(int start, int end) async =>
      Uint8List.sublistView(bytes, start, end);
}

class ZipEntry {
  ZipEntry({
    required this.name,
    required this.method,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localHeaderOffset,
  });

  final String name;

  /// 0 = 無圧縮, 8 = deflate
  final int method;
  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;
}

class ZipFormatException implements Exception {
  ZipFormatException(this.message);
  final String message;
  @override
  String toString() => 'ZipFormatException: $message';
}

/// ZIP の目次（セントラルディレクトリ）だけを読み、指定したファイルだけを取り出す。
class ZipReader {
  ZipReader._(this._source, this.entries);

  final RandomAccessSource _source;
  final List<ZipEntry> entries;

  static Future<ZipReader> open(RandomAccessSource source) async {
    final len = source.length;
    // 末尾のコメントは最大 64KB なので、末尾 64KB + 22 バイトから目次の終わりを探す。
    final tailStart = len - 22 - 0xFFFF < 0 ? 0 : len - 22 - 0xFFFF;
    final tail = await source.read(tailStart, len);
    final tailData = ByteData.sublistView(tail);
    var eocd = -1;
    for (var i = tail.length - 22; i >= 0; i--) {
      if (tailData.getUint32(i, Endian.little) == 0x06054b50) {
        eocd = i;
        break;
      }
    }
    if (eocd < 0) throw ZipFormatException('not a ZIP file');

    var count = tailData.getUint16(eocd + 10, Endian.little);
    var dirSize = tailData.getUint32(eocd + 12, Endian.little);
    var dirOffset = tailData.getUint32(eocd + 16, Endian.little);

    // 4GB を超えるなどの大きな ZIP（ZIP64）
    if (count == 0xFFFF || dirSize == 0xFFFFFFFF || dirOffset == 0xFFFFFFFF) {
      final locator = eocd - 20;
      if (locator < 0 ||
          tailData.getUint32(locator, Endian.little) != 0x07064b50) {
        throw ZipFormatException('ZIP64 locator not found');
      }
      final recordOffset = _u64(tailData, locator + 8);
      final record = ByteData.sublistView(
        await source.read(recordOffset, recordOffset + 56),
      );
      if (record.getUint32(0, Endian.little) != 0x06064b50) {
        throw ZipFormatException('broken ZIP64 directory');
      }
      count = _u64(record, 32);
      dirSize = _u64(record, 40);
      dirOffset = _u64(record, 48);
    }

    final dir = await source.read(dirOffset, dirOffset + dirSize);
    final d = ByteData.sublistView(dir);
    final entries = <ZipEntry>[];
    var p = 0;
    for (var i = 0; i < count; i++) {
      if (d.getUint32(p, Endian.little) != 0x02014b50) {
        throw ZipFormatException('broken ZIP directory');
      }
      final method = d.getUint16(p + 10, Endian.little);
      var compressed = d.getUint32(p + 20, Endian.little);
      var uncompressed = d.getUint32(p + 24, Endian.little);
      final nameLen = d.getUint16(p + 28, Endian.little);
      final extraLen = d.getUint16(p + 30, Endian.little);
      final commentLen = d.getUint16(p + 32, Endian.little);
      var offset = d.getUint32(p + 42, Endian.little);
      final name = utf8.decode(
        dir.sublist(p + 46, p + 46 + nameLen),
        allowMalformed: true,
      );

      // ZIP64 の拡張フィールドに本当の大きさ・位置が入っていることがある
      var e = p + 46 + nameLen;
      final extraEnd = e + extraLen;
      while (e + 4 <= extraEnd) {
        final id = d.getUint16(e, Endian.little);
        final size = d.getUint16(e + 2, Endian.little);
        if (id == 0x0001) {
          var q = e + 4;
          if (uncompressed == 0xFFFFFFFF) {
            uncompressed = _u64(d, q);
            q += 8;
          }
          if (compressed == 0xFFFFFFFF) {
            compressed = _u64(d, q);
            q += 8;
          }
          if (offset == 0xFFFFFFFF) offset = _u64(d, q);
        }
        e += 4 + size;
      }

      entries.add(
        ZipEntry(
          name: name,
          method: method,
          compressedSize: compressed,
          uncompressedSize: uncompressed,
          localHeaderOffset: offset,
        ),
      );
      p = extraEnd + commentLen;
    }
    return ZipReader._(source, entries);
  }

  /// [entry] の中身を取り出す。
  Future<Uint8List> extract(ZipEntry entry) async {
    final header = ByteData.sublistView(
      await _source.read(entry.localHeaderOffset, entry.localHeaderOffset + 30),
    );
    if (header.getUint32(0, Endian.little) != 0x04034b50) {
      throw ZipFormatException('bad offset for ${entry.name}');
    }
    final dataStart =
        entry.localHeaderOffset +
        30 +
        header.getUint16(26, Endian.little) +
        header.getUint16(28, Endian.little);
    final data = await _source.read(
      dataStart,
      dataStart + entry.compressedSize,
    );
    switch (entry.method) {
      case 0:
        return data;
      case 8:
        return Inflate(
          data,
          uncompressedSize: entry.uncompressedSize,
        ).getBytes();
      default:
        throw ZipFormatException(
          'unsupported compression method ${entry.method} for ${entry.name}',
        );
    }
  }

  static int _u64(ByteData d, int offset) =>
      d.getUint32(offset, Endian.little) +
      d.getUint32(offset + 4, Endian.little) * 0x100000000;
}
