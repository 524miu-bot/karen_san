// LINE ログインで使うブラウザ機能（Web 版）。
import 'package:web/web.dart' as web;

// iPhone の Safari では、LINE アプリで認証したあと新しいタブで戻ってくることがあり、
// タブごとの sessionStorage だと確認用の値が消えてしまう。
// そのためブラウザ全体で共有される localStorage を使う（使ったらすぐ消す）。

String? sessionGet(String key) => web.window.localStorage.getItem(key);

void sessionSet(String key, String value) =>
    web.window.localStorage.setItem(key, value);

void sessionRemove(String key) => web.window.localStorage.removeItem(key);

void navigateTo(String url) => web.window.location.href = url;

void replaceAddress(String url) =>
    web.window.history.replaceState(null, '', url);
