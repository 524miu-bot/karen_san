import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models.dart';

/// Firestore の読み書きをまとめたもの。
///
/// データ構成:
/// - users/{uid}               … { familyId }
/// - families/{familyId}       … { name, inviteCode, memberIds, memberNames }
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

  CollectionReference<Map<String, dynamic>> _events(String familyId) =>
      _familyDoc(familyId).collection('events');

  /// ログイン中のユーザーが所属する家族 ID（未所属なら null）。
  Stream<String?> watchFamilyId(String uid) => _userDoc(uid)
      .snapshots()
      .map((s) => s.data()?['familyId'] as String?);

  Stream<Family> watchFamily(String familyId) =>
      _familyDoc(familyId).snapshots().map(Family.fromDoc);

  static String defaultName(User user) {
    final name = user.displayName;
    if (name != null && name.isNotEmpty) return name;
    return user.email?.split('@').first ?? 'メンバー';
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

  /// [from] 以降・[to] より前に始まる予定。
  Stream<List<CalendarEvent>> watchEvents(
    String familyId, {
    required DateTime from,
    required DateTime to,
  }) {
    return _events(familyId)
        .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('start', isLessThan: Timestamp.fromDate(to))
        .orderBy('start')
        .snapshots()
        .map((q) => q.docs.map(CalendarEvent.fromDoc).toList());
  }

  Future<void> saveEvent(String familyId, CalendarEvent event) {
    if (event.id == null) {
      return _events(familyId).add({
        ...event.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return _events(familyId).doc(event.id).update(event.toMap());
  }

  Future<void> deleteEvent(String familyId, String eventId) =>
      _events(familyId).doc(eventId).delete();
}
