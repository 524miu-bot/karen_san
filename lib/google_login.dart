import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';

Future<void>? _initialized;

/// Google でログインする。Web はポップアップ、iPhone などのアプリ版は端末の Google ログイン画面。
/// キャンセルされたときは何もせずに戻る。
Future<void> signInWithGoogle() async {
  if (kIsWeb) {
    await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    return;
  }
  final google = GoogleSignIn.instance;
  await (_initialized ??= google.initialize(
    clientId: DefaultFirebaseOptions.currentPlatform.iosClientId,
  ));
  final GoogleSignInAccount account;
  try {
    account = await google.authenticate();
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) return;
    rethrow;
  }
  final idToken = account.authentication.idToken;
  await FirebaseAuth.instance.signInWithCredential(
    GoogleAuthProvider.credential(idToken: idToken),
  );
}
