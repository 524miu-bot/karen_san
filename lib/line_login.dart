import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'line_browser_stub.dart' if (dart.library.js_interop) 'line_browser_web.dart' as browser;

/// LINE Developers の「LINE Login チャネル」のチャネル ID（公開してよい値）。
/// チャネルシークレットはアプリに書かず、Cloud Functions 側に置く。
const lineChannelId = '2012033968';

bool get isLineLoginConfigured => lineChannelId.isNotEmpty;

const _stateKey = 'karen_san.line.state';
const _nonceKey = 'karen_san.line.nonce';

/// LINE ログインから戻ってくる URL（このアプリのトップページ）。
/// LINE Developers のコールバック URL と Cloud Functions の
/// LINE_REDIRECT_URIS に同じ値を登録しておく。
String lineRedirectUri() {
  final base = Uri.base;
  return Uri(scheme: base.scheme, host: base.host, port: base.port, path: '/')
      .toString();
}

String _randomToken() {
  final rand = Random.secure();
  return List.generate(32, (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0'))
      .join();
}

/// LINE の認可画面の URL。
Uri lineAuthorizeUrl({
  required String channelId,
  required String redirectUri,
  required String state,
  required String nonce,
}) {
  return Uri.https('access.line.me', '/oauth2/v2.1/authorize', {
    'response_type': 'code',
    'client_id': channelId,
    'redirect_uri': redirectUri,
    'state': state,
    'scope': 'profile openid',
    'nonce': nonce,
  });
}

/// LINE の認可画面へ移動する（このページから離れる）。
void startLineLogin() {
  final state = _randomToken();
  final nonce = _randomToken();
  browser.sessionSet(_stateKey, state);
  browser.sessionSet(_nonceKey, nonce);
  browser.navigateTo(lineAuthorizeUrl(
    channelId: lineChannelId,
    redirectUri: lineRedirectUri(),
    state: state,
    nonce: nonce,
  ).toString());
}

/// LINE ログインの戻りを処理した結果。
sealed class LineLoginResult {}

/// LINE から戻ってきたページではなかった。
class LineLoginNone extends LineLoginResult {}

class LineLoginSuccess extends LineLoginResult {}

class LineLoginFailure extends LineLoginResult {
  LineLoginFailure(this.message);
  final String message;
}

/// アドレスに LINE からの戻り（?code=…&state=…）があれば、Firebase にログインする。
Future<LineLoginResult> completeLineLoginIfNeeded() async {
  final params = Uri.base.queryParameters;
  if (!params.containsKey('code') && !params.containsKey('error')) {
    return LineLoginNone();
  }

  final expectedState = browser.sessionGet(_stateKey);
  final nonce = browser.sessionGet(_nonceKey);
  browser.sessionRemove(_stateKey);
  browser.sessionRemove(_nonceKey);
  _clearQueryFromAddressBar();

  if (params['error'] != null) {
    return LineLoginFailure(params['error'] == 'access_denied'
        ? 'LINE ログインがキャンセルされました。'
        : 'LINE ログインに失敗しました（${params['error']}）。');
  }
  final code = params['code']!;
  if (expectedState == null || nonce == null || params['state'] != expectedState) {
    return LineLoginFailure('LINE ログインの確認に失敗しました。もう一度お試しください。');
  }

  try {
    final result = await FirebaseFunctions.instanceFor(region: 'asia-northeast1')
        .httpsCallable('lineLogin')
        .call<Map<String, dynamic>>({
      'code': code,
      'redirectUri': lineRedirectUri(),
      'nonce': nonce,
    });
    final token = result.data['token'] as String;
    await FirebaseAuth.instance.signInWithCustomToken(token);
    return LineLoginSuccess();
  } on FirebaseFunctionsException catch (e) {
    return LineLoginFailure('LINE ログインに失敗しました（${e.code}）。');
  } on FirebaseAuthException catch (e) {
    return LineLoginFailure('LINE ログインに失敗しました（${e.code}）。');
  }
}

/// 使い終わった code を履歴に残さないよう、アドレスから ?… を消す。
void _clearQueryFromAddressBar() {
  final base = Uri.base;
  final clean = Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.port,
    path: base.path,
    fragment: base.fragment.isEmpty ? null : base.fragment,
  );
  browser.replaceAddress(clean.toString());
}
