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

// 写真・PDF の予定表を AI（Claude）で読み取る。
// Anthropic の API キーは Secret Manager に保存する（firebase functions:secrets:set ANTHROPIC_API_KEY）
const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");
// 普通の読み取りと「正確に読む」で使うモデル（functions/.env で変えられる）
const AI_MODEL = defineString("AI_MODEL", {default: "claude-haiku-5-5"});
const AI_MODEL_PRECISE =
  defineString("AI_MODEL_PRECISE", {default: "claude-opus-5-5"});
// 課金の仕組みができるまで、有料版として扱う人の uid（カンマ区切り。家族のテスト用）
const PREMIUM_UIDS = defineString("PREMIUM_UIDS", {default: ""});
const aiImport = require("./ai_import");

/** 有料版かどうか。entitlements/{uid} はサーバーだけが書く（アプリ内課金の確認後）。 */
async function planOf(uid) {
  const testers = PREMIUM_UIDS.value().split(",").map((s) => s.trim());
  if (testers.includes(uid)) return "premium";
  const snap = await getFirestore().collection("entitlements").doc(uid).get();
  const until = snap.exists && snap.data().premiumUntil;
  return until && until.toMillis() > Date.now() ? "premium" : "free";
}

function requireUid(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError("unauthenticated", "ログインが必要です");
  return uid;
}

// 今月の残り回数（「まとめて追加」の画面に出す）
exports.aiQuota = onCall({region: "asia-northeast1"}, async (request) => {
  const uid = requireUid(request);
  return aiImport.getQuota(getFirestore(), uid, await planOf(uid));
});

exports.readSchedule = onCall(
    {
      region: "asia-northeast1",
      secrets: [ANTHROPIC_API_KEY],
      timeoutSeconds: 300,
      memory: "512MiB",
    },
    async (request) => {
      const uid = requireUid(request);
      const {mimeType, data, today, hint, precise} = request.data || {};
      const day = /^\d{4}-\d{2}-\d{2}$/.test(today || "") ?
        today : new Date().toISOString().slice(0, 10);
      try {
        aiImport.fileBlock({mimeType, data});
      } catch (e) {
        throw new HttpsError("invalid-argument", e.message);
      }
      const db = getFirestore();
      const plan = await planOf(uid);
      const kind = precise === true ? "precise" : "normal";
      if (kind === "precise" && plan !== "premium") {
        throw new HttpsError("permission-denied",
            "「正確に読む」は有料版の機能です。");
      }
      const quota = await aiImport.takeQuota(db, uid, plan, kind);
      if (!quota) {
        throw new HttpsError("resource-exhausted", kind === "precise" ?
          "今月の「正確に読む」は使い切りました。来月またお使いください。" :
          "今月の AI 読み取りの回数を使い切りました。来月またお使いください。");
      }
      const Anthropic = require("@anthropic-ai/sdk");
      const client = new Anthropic({apiKey: ANTHROPIC_API_KEY.value()});
      const model = kind === "precise" ? AI_MODEL_PRECISE.value() : AI_MODEL.value();
      try {
        const {result, usage} = await aiImport.readSchedule({
          client,
          model,
          mimeType,
          data,
          today: day,
          hint: String(hint || "").slice(0, 1000),
        });
        logger.info("予定表を読み取り", {
          uid, plan, kind, model, count: result.events.length,
          input: usage.input_tokens, output: usage.output_tokens,
        });
        return {...result, quota};
      } catch (e) {
        logger.error("予定表の読み取りに失敗", {uid, model, message: e.message});
        await aiImport.refundQuota(db, uid, plan, kind).catch(() => {});
        throw new HttpsError("internal",
            "読み取れませんでした。写真を撮り直すか、時間をおいてお試しください。");
      }
    },
);
