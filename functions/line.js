// LINE ログイン（LINE Login v2.1）とのやりとり。
// https://developers.line.biz/ja/docs/line-login/integrate-line-login/

const TOKEN_URL = "https://api.line.me/oauth2/v2.1/token";
const VERIFY_URL = "https://api.line.me/oauth2/v2.1/verify";

/** 認可コードを ID トークンに交換する。 */
async function exchangeCode({code, redirectUri, channelId, channelSecret},
    fetchImpl = fetch) {
  const res = await fetchImpl(TOKEN_URL, {
    method: "POST",
    headers: {"Content-Type": "application/x-www-form-urlencoded"},
    body: new URLSearchParams({
      grant_type: "authorization_code",
      code,
      redirect_uri: redirectUri,
      client_id: channelId,
      client_secret: channelSecret,
    }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || typeof body.id_token !== "string") {
    throw new Error(`token: ${res.status} ${body.error || ""} ${body.error_description || ""}`);
  }
  return body.id_token;
}

/**
 * ID トークンを LINE のサーバーで検証する。
 * 署名・有効期限・発行者・宛先（チャネル ID）・nonce を LINE 側で確認してくれる。
 */
async function verifyIdToken({idToken, channelId, nonce}, fetchImpl = fetch) {
  const res = await fetchImpl(VERIFY_URL, {
    method: "POST",
    headers: {"Content-Type": "application/x-www-form-urlencoded"},
    body: new URLSearchParams({id_token: idToken, client_id: channelId, nonce}),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(`verify: ${res.status} ${body.error || ""} ${body.error_description || ""}`);
  }
  // 念のためこちらでも宛先と発行者を確認する。
  if (body.aud !== channelId || body.iss !== "https://access.line.me" ||
      typeof body.sub !== "string" || body.sub.length === 0) {
    throw new Error("verify: unexpected claims");
  }
  return {sub: body.sub, name: body.name, picture: body.picture};
}

/** LINE のユーザー ID から Firebase の uid を作る（Google ログインの uid と区別する）。 */
function firebaseUidFor(lineUserId) {
  return `line:${lineUserId}`;
}

/** redirectUri が設定で許可されたものと完全に一致するか。 */
function isAllowedRedirect(redirectUri, allowedCsv) {
  return (allowedCsv || "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean)
      .includes(redirectUri);
}

module.exports = {exchangeCode, verifyIdToken, firebaseUidFor, isAllowedRedirect};
