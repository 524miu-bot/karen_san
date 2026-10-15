import 'package:flutter_test/flutter_test.dart';

import 'package:karen_san/line_login.dart';

void main() {
  test('LINE の認可画面の URL に必要な項目がそろっている', () {
    final url = lineAuthorizeUrl(
      channelId: '1234567890',
      redirectUri: 'http://localhost:5000/',
      state: 'STATE',
      nonce: 'NONCE',
    );
    expect(url.origin, 'https://access.line.me');
    expect(url.path, '/oauth2/v2.1/authorize');
    expect(url.queryParameters, {
      'response_type': 'code',
      'client_id': '1234567890',
      'redirect_uri': 'http://localhost:5000/',
      'state': 'STATE',
      'scope': 'profile openid',
      'nonce': 'NONCE',
    });
  });
}
