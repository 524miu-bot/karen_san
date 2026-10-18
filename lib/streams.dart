import 'dart:async';

/// いくつかのリストのストリームを、どれかが変わるたびに 1 つにまとめて流す。
/// すべてのストリームが最初の値を出すまでは何も流さない。
Stream<List<T>> combineLatestLists<T>(List<Stream<List<T>>> streams) {
  late final StreamController<List<T>> controller;
  final latest = List<List<T>?>.filled(streams.length, null);
  final subs = <StreamSubscription<List<T>>>[];

  void emit() {
    if (latest.any((l) => l == null)) return;
    controller.add([for (final l in latest) ...l!]);
  }

  controller = StreamController<List<T>>(
    onListen: () {
      for (var i = 0; i < streams.length; i++) {
        subs.add(
          streams[i].listen((v) {
            latest[i] = v;
            emit();
          }, onError: controller.addError),
        );
      }
    },
    onPause: () {
      for (final s in subs) {
        s.pause();
      }
    },
    onResume: () {
      for (final s in subs) {
        s.resume();
      }
    },
    onCancel: () async {
      for (final s in subs) {
        await s.cancel();
      }
    },
  );
  return controller.stream;
}
