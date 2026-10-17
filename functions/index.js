// カレンさんの Cloud Functions
//
// lineLogin: LINE ログインの中継。
//   1. アプリが LINE の認可画面へ移動し、戻ってきたときの code を送ってくる
//   2. code を LINE の ID トークンに交換し、LINE のサーバーで検証する
//   3. LINE のユーザー ID から Firebase のカスタムトークンを作って返す
//   チャネルシークレットはアプリに置けないので、ここ（サーバー側）で扱う。

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret, defineString} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");

initializeApp();

// functions/.env で設定する（公開してよい値）
const LINE_CHANNEL_ID = defineString("LINE_CHANNEL_ID");
// LINE ログインから戻ってくる URL。カンマ区切りで複数指定できる。
const LINE_REDIRECT_URIS = defineString("LINE_REDIRECT_URIS");
// Secret Manager に保存する（firebase functions:secrets:set LINE_CHANNEL_SECRET）
const LINE_CHANNEL_SECRET = defineSecret("LINE_CHANNEL_SECRET");

const {exchangeCode, verifyIdToken, firebaseUidFor, isAllowedRedirect} =
  require("./line");

exports.lineLogin = onCall(
    {region: "asia-northeast1", secrets: [LINE_CHANNEL_SECRET]},
    async (request) => {
      const {code, redirectUri, nonce} = request.data || {};
      for (const [name, value] of Object.entries({code, redirectUri, nonce})) {
        if (typeof value !== "string" || value.length === 0 ||
            value.length > 2048) {
          throw new HttpsError("invalid-argument", `${name} が正しくありません`);
        }
      }
      if (!isAllowedRedirect(redirectUri, LINE_REDIRECT_URIS.value())) {
        throw new HttpsError("invalid-argument", "redirectUri が許可されていません");
      }

      const channelId = LINE_CHANNEL_ID.value();
      let profile;
      try {
        const idToken = await exchangeCode({
          code,
          redirectUri,
          channelId,
          channelSecret: LINE_CHANNEL_SECRET.value(),
        });
        profile = await verifyIdToken({idToken, channelId, nonce});
      } catch (e) {
        logger.warn("LINE ログインの検証に失敗", {message: e.message});
        throw new HttpsError("unauthenticated", "LINE ログインを確認できませんでした");
      }

      const uid = firebaseUidFor(profile.sub);
      const auth = getAuth();
      const userProps = {
        displayName: profile.name || "LINE ユーザー",
        ...(profile.picture ? {photoURL: profile.picture} : {}),
      };
      try {
        await auth.updateUser(uid, userProps);
      } catch (e) {
        if (e.code !== "auth/user-not-found") throw e;
        await auth.createUser({uid, ...userProps});
      }

      const token = await auth.createCustomToken(uid, {provider: "line"});
      return {token};
    },
);

const {getFirestore} = require("firebase-admin/firestore");
const {deleteAccount} = require("./account");

// アカウント削除（アプリの設定画面から呼ぶ）。本人のアカウントだけを削除できる。
exports.deleteAccount = onCall({region: "asia-northeast1"}, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError("unauthenticated", "ログインが必要です");
  try {
    await deleteAccount({db: getFirestore(), auth: getAuth(), uid});
  } catch (e) {
    logger.error("アカウント削除に失敗", {uid, message: e.message});
    throw new HttpsError("internal", "削除できませんでした。時間をおいてもう一度お試しください。");
  }
  return {ok: true};
});
