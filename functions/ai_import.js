// 写真・PDF の予定表を Claude で読み取り、予定の一覧にする。
// アプリは結果を「まとめて追加」の確認画面に出し、人が確認してから登録する。

// 1 か月に読み取れる回数（費用の上限のため）。
//   free:    無料の人。普通の読み取り（安いモデル）だけ
//   premium: 有料版の人。普通の読み取りがたっぷり＋「正確に読む」（高いモデル）
const PLANS = {
  free: {normal: 5, precise: 0},
  premium: {normal: 200, precise: 10},
};

// 送ってよいファイルの種類と大きさ（base64 にする前のおよそのバイト数）
const IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp", "image/gif"];
const PDF_TYPE = "application/pdf";
const MAX_BYTES = 8 * 1024 * 1024;

// 読み取り結果の形（構造化出力で、この形の JSON だけを返させる）
const EVENTS_SCHEMA = {
  type: "object",
  properties: {
    events: {
      type: "array",
      items: {
        type: "object",
        properties: {
          date: {type: "string", description: "YYYY-MM-DD"},
          allDay: {type: "boolean"},
          start: {type: "string", description: "HH:MM（終日なら空）"},
          end: {type: "string", description: "HH:MM（終日なら空）"},
          title: {type: "string"},
          location: {type: "string"},
          note: {type: "string"},
        },
        required: ["date", "allDay", "start", "end", "title", "location", "note"],
        additionalProperties: false,
      },
    },
    comment: {
      type: "string",
      description: "読み取れなかった所・自信のない所の短い説明（なければ空）",
    },
  },
  required: ["events", "comment"],
  additionalProperties: false,
};

/** Claude への指示。today は端末の日付（年が書かれていない表のため）。 */
function buildPrompt({today, hint}) {
  return [
    "この画像（または PDF）は、学校のプリント・習い事の予定表・勤務表などの予定表です。",
    "カレンダーに登録する予定を読み取って、決められた JSON の形で返してください。",
    "",
    "決まり:",
    `- 今日は ${today} です。年が書かれていなければ、今日に近い年にしてください。`,
    "- 1 件ごとに日付・時刻・タイトル・場所・メモを入れます。",
    "- 時刻が書かれていない予定は allDay を true にし、start と end は空にします。",
    "- 終わりの時刻がない予定は、開始の 1 時間後を終わりにし、メモに「終了時刻は仮」と書きます。",
    "- 手書きの線で消されて別の名前・内容に直されている所は、直した後の内容を使います。",
    "- 当番・持ち物・注意書きなど、その日に関係することはメモに短く入れます。",
    "- 読み取れない所や自信のない所は、推測で埋めずに comment に書きます。",
    "- 予定がひとつも読み取れなければ events を空にし、comment に理由を書きます。",
    hint ?
      `\n使う人からの指示（必ず従ってください）:\n${hint}` :
      "",
  ].join("\n");
}

/** アプリから届いたファイルを確かめて、Claude に渡す形にする。 */
function fileBlock({mimeType, data}) {
  if (typeof data !== "string" || data.length === 0) {
    throw new Error("ファイルがありません");
  }
  if (data.length * 0.75 > MAX_BYTES) {
    throw new Error("ファイルが大きすぎます");
  }
  if (mimeType === PDF_TYPE) {
    return {
      type: "document",
      source: {type: "base64", media_type: PDF_TYPE, data},
    };
  }
  if (IMAGE_TYPES.includes(mimeType)) {
    return {type: "image", source: {type: "base64", media_type: mimeType, data}};
  }
  throw new Error("写真か PDF を選んでください");
}

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const TIME_RE = /^([01]?\d|2[0-3]):[0-5]\d$/;

/** 読み取り結果を確かめ、おかしな行を落とす。 */
function cleanEvents(raw) {
  const list = Array.isArray(raw && raw.events) ? raw.events : [];
  const out = [];
  for (const e of list.slice(0, 200)) {
    if (!e || !DATE_RE.test(e.date) || !String(e.title || "").trim()) continue;
    const d = new Date(`${e.date}T00:00:00Z`);
    if (isNaN(d) || d.toISOString().slice(0, 10) !== e.date) continue;
    const timed = !e.allDay && TIME_RE.test(e.start) && TIME_RE.test(e.end);
    out.push({
      date: e.date,
      allDay: !timed,
      start: timed ? e.start : "",
      end: timed ? e.end : "",
      title: String(e.title).trim().slice(0, 100),
      location: String(e.location || "").trim().slice(0, 200),
      note: String(e.note || "").trim().slice(0, 1000),
    });
  }
  return {
    events: out,
    comment: String((raw && raw.comment) || "").trim().slice(0, 1000),
  };
}

/** 日本時間の今月（例: 2026-11）。端末の日付は使わない（変えれば回数が戻せてしまうため）。 */
function monthKey(now = new Date()) {
  return new Date(now.getTime() + 9 * 3600 * 1000).toISOString().slice(0, 7);
}

/** 今月の使った回数と残り。bonus は動画を見て増えた回数（あとで使う）。 */
function quotaOf(data, plan, month) {
  const d = data && data.month === month ? data : {};
  const p = PLANS[plan] || PLANS.free;
  const normalUsed = d.normal || 0;
  const preciseUsed = d.precise || 0;
  const bonus = d.bonus || 0;
  return {
    plan: PLANS[plan] ? plan : "free",
    month,
    normalUsed,
    normalLimit: p.normal + bonus,
    preciseUsed,
    preciseLimit: p.precise,
  };
}

function usageRef(db, uid) {
  return db.collection("ai_usage").doc(uid);
}

/** 今月の回数を見る。 */
async function getQuota(db, uid, plan, month = monthKey()) {
  const snap = await usageRef(db, uid).get();
  return quotaOf(snap.exists ? snap.data() : null, plan, month);
}

/**
 * 回数を 1 使う。残りがなければ null。使ったあとの回数を返す。
 * kind は "normal"（普通）か "precise"（正確に読む）。
 */
async function takeQuota(db, uid, plan, kind, month = monthKey()) {
  const ref = usageRef(db, uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : null;
    const q = quotaOf(data, plan, month);
    const used = kind === "precise" ? q.preciseUsed : q.normalUsed;
    const limit = kind === "precise" ? q.preciseLimit : q.normalLimit;
    if (used >= limit) return null;
    const d = data && data.month === month ? data : {};
    const next = {
      month,
      normal: q.normalUsed + (kind === "normal" ? 1 : 0),
      precise: q.preciseUsed + (kind === "precise" ? 1 : 0),
      bonus: d.bonus || 0,
    };
    tx.set(ref, next);
    return quotaOf(next, plan, month);
  });
}

/** 読み取りに失敗したときに、使った 1 回を戻す。 */
async function refundQuota(db, uid, plan, kind, month = monthKey()) {
  const ref = usageRef(db, uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : null;
    if (!data || data.month !== month) return;
    const field = kind === "precise" ? "precise" : "normal";
    tx.set(ref, {...data, [field]: Math.max(0, (data[field] || 0) - 1)});
  });
}

/** Claude で読み取る。client は Anthropic の SDK のクライアント。 */
async function readSchedule({client, model, mimeType, data, today, hint}) {
  const stream = client.messages.stream({
    model,
    max_tokens: 16000,
    thinking: {type: "adaptive"},
    output_config: {format: {type: "json_schema", schema: EVENTS_SCHEMA}},
    messages: [{
      role: "user",
      content: [
        fileBlock({mimeType, data}),
        {type: "text", text: buildPrompt({today, hint})},
      ],
    }],
  });
  const message = await stream.finalMessage();
  const text = message.content
      .filter((b) => b.type === "text")
      .map((b) => b.text)
      .join("");
  if (message.stop_reason === "refusal" || !text) {
    throw new Error(`読み取れませんでした（${message.stop_reason}）`);
  }
  return {result: cleanEvents(JSON.parse(text)), usage: message.usage};
}

module.exports = {
  PLANS,
  monthKey,
  quotaOf,
  getQuota,
  refundQuota,
  buildPrompt,
  fileBlock,
  cleanEvents,
  takeQuota,
  readSchedule,
};
