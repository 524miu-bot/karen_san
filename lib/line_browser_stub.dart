// LINE ログインで使うブラウザ機能（Web 以外・テスト用の代わり）。
final _session = <String, String>{};

String? sessionGet(String key) => _session[key];

void sessionSet(String key, String value) => _session[key] = value;

void sessionRemove(String key) => _session.remove(key);

void navigateTo(String url) =>
    throw UnsupportedError('LINE ログインは Web 版でのみ使えます');

void replaceAddress(String url) {}
