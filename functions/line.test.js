const test = require("node:test");
const assert = require("node:assert/strict");

const {exchangeCode, verifyIdToken, firebaseUidFor, isAllowedRedirect} =
  require("./line");

/** 呼ばれた内容を記録し、決まった応答を返す偽の fetch。 */
function fakeFetch(status, body) {
  const calls = [];
  const impl = async (url, init) => {
    calls.push({url, params: Object.fromEntries(new URLSearchParams(init.body))});
    return {ok: status >= 200 && status < 300, status, json: async () => body};
  };
  return {impl, calls};
}

test("認可コードを交換するときにチャネル ID・シークレット・戻り先を送る", async () => {
  const f = fakeFetch(200, {id_token: "ID_TOKEN"});
  const token = await exchangeCode({
    code: "CODE", redirectUri: "http://localhost:5000/",
    channelId: "123", channelSecret: "SECRET",
  }, f.impl);
  assert.equal(token, "ID_TOKEN");
  assert.equal(f.calls[0].url, "https://api.line.me/oauth2/v2.1/token");
  assert.deepEqual(f.calls[0].params, {
    grant_type: "authorization_code", code: "CODE",
    redirect_uri: "http://localhost:5000/", client_id: "123",
    client_secret: "SECRET",
  });
});

test("交換に失敗したらエラー", async () => {
  const f = fakeFetch(400, {error: "invalid_grant"});
  await assert.rejects(exchangeCode({
    code: "x", redirectUri: "r", channelId: "1", channelSecret: "s",
  }, f.impl), /invalid_grant/);
});

test("ID トークンの検証で nonce とチャネル ID を送り、プロフィールを返す", async () => {
  const f = fakeFetch(200, {
    iss: "https://access.line.me", aud: "123", sub: "U1",
    name: "カレン", picture: "https://example/p.png",
  });
  const p = await verifyIdToken({idToken: "T", channelId: "123", nonce: "N"},
      f.impl);
  assert.deepEqual(p, {sub: "U1", name: "カレン", picture: "https://example/p.png"});
  assert.deepEqual(f.calls[0].params, {id_token: "T", client_id: "123", nonce: "N"});
});

test("別のチャネル宛ての ID トークンは受け付けない", async () => {
  const f = fakeFetch(200, {iss: "https://access.line.me", aud: "999", sub: "U1"});
  await assert.rejects(
      verifyIdToken({idToken: "T", channelId: "123", nonce: "N"}, f.impl),
      /unexpected claims/);
});

test("LINE が検証を拒否したらエラー", async () => {
  const f = fakeFetch(400, {error: "invalid_request", error_description: "Invalid nonce"});
  await assert.rejects(
      verifyIdToken({idToken: "T", channelId: "123", nonce: "N"}, f.impl),
      /Invalid nonce/);
});

test("戻り先 URL は完全一致のものだけ許可する", () => {
  const allowed = "http://localhost:5000/, https://karen-san-app-f5025.web.app/";
  assert.ok(isAllowedRedirect("http://localhost:5000/", allowed));
  assert.ok(isAllowedRedirect("https://karen-san-app-f5025.web.app/", allowed));
  assert.ok(!isAllowedRedirect("https://evil.example/", allowed));
  assert.ok(!isAllowedRedirect("http://localhost:5000/x", allowed));
  assert.ok(!isAllowedRedirect("http://localhost:5000/", ""));
});

test("Firebase の uid は line: で始まる", () => {
  assert.equal(firebaseUidFor("U1234"), "line:U1234");
});
