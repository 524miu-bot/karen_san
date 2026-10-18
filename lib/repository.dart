import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/painting.dart';

import 'models.dart';
import 'oshi.dart';
import 'planner.dart';
import 'streams.dart';
import 'x_archive/x_archive.dart';

/// 予定などを保存する場所を決める情報（所属グループと本人）。
class Place {
  const Place({required this.familyId, required this.uid});
  final String familyId;
  final String uid;
}

/// Firestore の読み書きをまとめたもの。
///
/// データ構成:
/// - users/{uid}               … { familyId }
/// - families/{familyId}       … { name, inviteCode, memberIds, memberNames,
///                                  memberColors, people（ログインしない予定者） }
/// - families/{id}/events/{id} … 予定
/// - invites/{inviteCode}      … { familyId }（招待コードから家族を探す）
class Repository {
  Repository._();
  static final instance = Repository._();

  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> _familyDoc(String familyId) =>
      _db.collection('families').doc(familyId);

  /// ログイン中のユーザーが所属する家族 ID（未所属なら null）。
  Stream<String?> watchFamilyId(String uid) =>
      _userDoc(uid).snapshots().map((s) => s.data()?['familyId'] as String?);

  Stream<Family> watchFamily(String familyId) =>
      _familyDoc(familyId).snapshots().map(Family.fromDoc);

  static String defaultName(User user, {String fallback = 'メンバー'}) {
    final name = user.displayName;
    if (name != null && name.isNotEmpty) return name;
    return user.email?.split('@').first ?? fallback;
  }

  static String _newInviteCode() {
    // 見間違えやすい 0/O/1/I は除く。
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> createFamily({
    required User user,
    required String familyName,
    required String myName,
  }) async {
    final family = _db.collection('families').doc();
    final code = _newInviteCode();
    final batch = _db.batch()
      ..set(family, {
        'name': familyName,
        'inviteCode': code,
        'memberIds': [user.uid],
        'memberNames': {user.uid: myName},
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(_db.collection('invites').doc(code), {'familyId': family.id})
      ..set(_userDoc(user.uid), {'familyId': family.id});
    await batch.commit();
  }

  /// 招待コードで家族に参加する。コードが見つからなければ false。
  Future<bool> joinFamily({
    required User user,
    required String inviteCode,
    required String myName,
  }) async {
    final code = inviteCode.trim().toUpperCase();
    if (code.isEmpty) return false;
    final invite = await _db.collection('invites').doc(code).get();
    final familyId = invite.data()?['familyId'] as String?;
    if (familyId == null) return false;

    final batch = _db.batch()
      ..update(_familyDoc(familyId), {
        'memberIds': FieldValue.arrayUnion([user.uid]),
        'memberNames.${user.uid}': myName,
        'joinCode': code,
      })
      ..set(_userDoc(user.uid), {'familyId': familyId});
    await batch.commit();
    return true;
  }

  Future<void> setMyColor(String familyId, String uid, Color color) =>
      _familyDoc(familyId).update({'memberColors.$uid': color.toARGB32()});

  Future<void> setMyName(String familyId, String uid, String name) =>
      _familyDoc(familyId).update({'memberNames.$uid': name});

  /// ログインしない予定者を追加し、その ID を返す。
  Future<String> addPerson(String familyId, String name, {Color? color}) async {
    final id = 'p_${_db.collection('_').doc().id}';
    await _familyDoc(familyId).update({
      'people.$id': {
        'name': name,
        if (color != null) 'color': color.toARGB32(),
        'order': DateTime.now().millisecondsSinceEpoch,
      },
    });
    return id;
  }

  Future<void> updatePerson(
    String familyId,
    String personId, {
    String? name,
    Color? color,
  }) {
    return _familyDoc(familyId).update({
      'people.$personId.name': ?name,
      if (color != null) 'people.$personId.color': color.toARGB32(),
    });
  }

  /// 予定者を削除する。その人の予定は残り、「（いなくなった人）」として表示される。
  Future<void> removePerson(String familyId, String personId) =>
      _familyDoc(familyId).update({'people.$personId': FieldValue.delete()});

  /// 予定・ルーティーン・TODO の保存場所。
  /// 家庭はグループ（families/{familyId}/…）、仕事は本人だけ（users/{uid}/work_…）。
  CollectionReference<Map<String, dynamic>> _planner(
    Place place,
    CalendarKind kind,
    String name,
  ) => kind == CalendarKind.family
      ? _familyDoc(place.familyId).collection(name)
      : _userDoc(place.uid).collection('work_$name');

  /// [from] 以降・[to] より前に始まる予定。
  Stream<List<CalendarEvent>> watchEvents(
    Place place,
    CalendarKind kind, {
    required DateTime from,
    required DateTime to,
  }) {
    return _planner(place, kind, 'events')
        .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('start', isLessThan: Timestamp.fromDate(to))
        .orderBy('start')
        .snapshots()
        .map(
          (q) => [for (final d in q.docs) CalendarEvent.fromDoc(d, kind: kind)],
        );
  }

  Future<void> saveEvent(Place place, CalendarEvent event) {
    final col = _planner(place, event.kind, 'events');
    if (event.id == null) {
      return col.add({
        ...event.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return col.doc(event.id).update(event.toMap());
  }

  Future<void> deleteEvent(Place place, CalendarEvent event) =>
      _planner(place, event.kind, 'events').doc(event.id).delete();

  // ---- 1 週間のルーティーン ----

  Stream<List<Routine>> watchRoutines(Place place, CalendarKind kind) =>
      _planner(place, kind, 'routines').snapshots().map(
        (q) => [
          for (final d in q.docs) Routine.fromMap(d.id, d.data(), kind: kind),
        ]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes)),
      );

  Future<Routine?> getRoutine(Place place, CalendarKind kind, String id) async {
    final doc = await _planner(place, kind, 'routines').doc(id).get();
    final data = doc.data();
    return data == null ? null : Routine.fromMap(doc.id, data, kind: kind);
  }

  Future<void> saveRoutine(Place place, Routine routine) {
    final col = _planner(place, routine.kind, 'routines');
    return routine.id == null
        ? col.add(routine.toMap())
        : col.doc(routine.id).set(routine.toMap());
  }

  Future<void> deleteRoutine(Place place, Routine routine) =>
      _planner(place, routine.kind, 'routines').doc(routine.id).delete();

  /// その日だけルーティーンをお休みにする。
  Future<void> skipRoutineOn(Place place, Routine routine, DateTime day) =>
      _planner(place, routine.kind, 'routines').doc(routine.id).update({
        'skipDates': FieldValue.arrayUnion([dateKey(day)]),
      });

  // ---- 今週の TODO ----

  /// [weekKey] の週の TODO と、終わっていない TODO（持ち越し用）。
  Stream<List<Todo>> watchTodos(
    Place place,
    CalendarKind kind,
    String weekKey,
  ) {
    final col = _planner(place, kind, 'todos');
    List<Todo> parse(QuerySnapshot<Map<String, dynamic>> q) => [
      for (final d in q.docs) Todo.fromMap(d.id, d.data(), kind: kind),
    ];
    return combineLatestLists([
      col.where('weekKey', isEqualTo: weekKey).snapshots().map(parse),
      col.where('done', isEqualTo: false).snapshots().map(parse),
    ]);
  }

  Future<void> saveTodo(Place place, Todo todo) {
    final col = _planner(place, todo.kind, 'todos');
    return todo.id == null
        ? col.add({...todo.toMap(), 'createdAt': FieldValue.serverTimestamp()})
        : col.doc(todo.id).update(todo.toMap());
  }

  Future<void> setTodoDone(Place place, Todo todo, bool done) =>
      _planner(place, todo.kind, 'todos').doc(todo.id).update({
        'done': done,
        // 持ち越した TODO を終えたら、終えた週の TODO として残す
        if (done) 'weekKey': weekKeyOf(DateTime.now()),
      });

  Future<void> deleteTodo(Place place, Todo todo) =>
      _planner(place, todo.kind, 'todos').doc(todo.id).delete();

  // ---- X の投稿（本人だけが見られる日記） ----
  // users/{uid}/xdays/{yyyy-MM-dd} … { date, posts: { 投稿ID: { t, at, k, m } } }

  CollectionReference<Map<String, dynamic>> _xDays(String uid) =>
      _userDoc(uid).collection('xdays');

  /// 投稿を日ごとにまとめて保存する。同じ投稿を取り込み直しても重複しない。
  Future<void> importXPosts(
    String uid,
    List<XPost> posts, {
    void Function(int done, int total)? onProgress,
  }) async {
    final byDay = <String, Map<String, dynamic>>{};
    for (final p in posts) {
      (byDay[dayKey(p.postedAt)] ??= {})[p.id] = {
        't': p.text,
        'at': Timestamp.fromDate(p.postedAt),
        'k': p.kind.name,
        'm': p.hasMedia,
      };
    }
    final days = byDay.keys.toList()..sort();
    const perBatch = 200;
    for (var i = 0; i < days.length; i += perBatch) {
      final batch = _db.batch();
      for (final day in days.skip(i).take(perBatch)) {
        batch.set(_xDays(uid).doc(day), {
          'date': day,
          'posts': byDay[day],
        }, SetOptions(merge: true));
      }
      await batch.commit();
      onProgress?.call((i + perBatch).clamp(0, days.length), days.length);
    }
  }

  /// [from] の日から [to] の日の手前までの投稿（日付キー → 投稿）。
  Stream<Map<String, List<XPost>>> watchXPosts(
    String uid, {
    required DateTime from,
    required DateTime to,
  }) {
    return _xDays(uid)
        .where('date', isGreaterThanOrEqualTo: dayKey(from))
        .where('date', isLessThan: dayKey(to))
        .snapshots()
        .map((q) => {for (final doc in q.docs) doc.id: _xPostsOf(doc.data())});
  }

  static List<XPost> _xPostsOf(Map<String, dynamic> data) {
    final posts = <XPost>[];
    (data['posts'] as Map? ?? const {}).forEach((id, v) {
      final m = v as Map;
      posts.add(
        XPost(
          id: id as String,
          text: m['t'] as String? ?? '',
          postedAt: (m['at'] as Timestamp).toDate(),
          kind: XPostKind.fromCode(m['k'] as String?),
          hasMedia: m['m'] as bool? ?? false,
        ),
      );
    });
    return posts..sort((a, b) => a.postedAt.compareTo(b.postedAt));
  }

  /// 取り込み済みの日数。
  Future<int> countXDays(String uid) async =>
      (await _xDays(uid).count().get()).count ?? 0;

  /// 取り込んだ X の投稿をすべて削除する。
  Future<void> deleteAllXPosts(String uid) async {
    while (true) {
      final q = await _xDays(uid).limit(400).get();
      if (q.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in q.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  // ---- 推し（X で投稿を見たい人）。本人だけの設定 ----

  Stream<List<Oshi>> watchOshi(String uid) => _userDoc(uid).snapshots().map(
    (s) => [
      for (final m in (s.data()?['oshi'] as List? ?? const []))
        Oshi.fromMap(Map<String, dynamic>.from(m as Map)),
    ],
  );

  Future<void> setOshi(String uid, List<Oshi> list) => _userDoc(uid).set({
    'oshi': [for (final o in list) o.toMap()],
  }, SetOptions(merge: true));
}
