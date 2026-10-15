// LINE ログインで使うブラウザ機能（Web 版）。
import 'package:web/web.dart' as web;

String? sessionGet(String key) => web.window.sessionStorage.getItem(key);

void sessionSet(String key, String value) =>
    web.window.sessionStorage.setItem(key, value);

void sessionRemove(String key) => web.window.sessionStorage.removeItem(key);

void navigateTo(String url) => web.window.location.href = url;

void replaceAddress(String url) =>
    web.window.history.replaceState(null, '', url);
