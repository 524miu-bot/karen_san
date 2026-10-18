import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:karen_san/streams.dart';

void main() {
  test('すべてが最初の値を出してから、変わるたびにまとめて流す', () async {
    final a = StreamController<List<int>>();
    final b = StreamController<List<int>>();
    final results = <List<int>>[];
    final sub = combineLatestLists([a.stream, b.stream]).listen(results.add);

    a.add([1]);
    await Future<void>.delayed(Duration.zero);
    expect(results, isEmpty);

    b.add([2, 3]);
    await Future<void>.delayed(Duration.zero);
    expect(results.last, [1, 2, 3]);

    a.add([9]);
    await Future<void>.delayed(Duration.zero);
    expect(results.last, [9, 2, 3]);

    await sub.cancel();
    expect(a.hasListener, isFalse);
    expect(b.hasListener, isFalse);
  });
}
