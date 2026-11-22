const test = require("node:test");
const assert = require("node:assert");
const {buildPrompt, fileBlock, cleanEvents, takeQuota, refundQuota, quotaOf,
  monthKey, readSchedule} = require("./ai_import");

test("指示文に今日の日付と使う人の指示が入る", () => {
  const p = buildPrompt({today: "2026-11-21", hint: "小西の欄だけ"});
  assert.match(p, /2026-11-21/);
  assert.match(p, /小西の欄だけ/);
});

test("写真と PDF だけを受け付ける", () => {
  assert.equal(fileBlock({mimeType: "image/jpeg", data: "AAAA"}).type, "image");
  assert.equal(fileBlock({mimeType: "application/pdf", data: "AAAA"}).type,
      "document");
  assert.throws(() => fileBlock({mimeType: "text/html", data: "AAAA"}));
  assert.throws(() => fileBlock({mimeType: "image/jpeg", data: ""}));
});

test("おかしな行は落とし、時刻がなければ終日にする", () => {
  const r = cleanEvents({
    events: [
      {date: "2026-11-01", allDay: false, start: "09:00", end: "12:00",
        title: " 練習 ", location: "大谷小", note: ""},
      {date: "2026-11-07", allDay: false, start: "", end: "",
        title: "清水公園", location: "", note: ""},
      {date: "2026-02-30", allDay: true, start: "", end: "", title: "ない日",
        location: "", note: ""},
      {date: "2026-11-08", allDay: true, start: "", end: "", title: "",
        location: "", note: ""},
    ],
    comment: "11/22 の終了時刻が読めません",
  });
  assert.equal(r.events.length, 2);
  assert.equal(r.events[0].title, "練習");
  assert.equal(r.events[1].allDay, true);
  assert.match(r.comment, /11\/22/);
});

function fakeDb() {
  const store = {};
  const ref = {id: "u"};
  return {
    store,
    collection: () => ({doc: (id) => ({...ref, id})}),
    runTransaction: async (fn) => fn({
      get: async (r) => ({exists: r.id in store, data: () => store[r.id]}),
      set: (r, v) => {
        store[r.id] = v;
      },
    }),
  };
}

test("無料は月 5 回、来月になると戻る", async () => {
  const db = fakeDb();
  for (let i = 1; i <= 5; i++) {
    const q = await takeQuota(db, "u", "free", "normal", "2026-11");
    assert.equal(q.normalUsed, i);
  }
  assert.equal(await takeQuota(db, "u", "free", "normal", "2026-11"), null);
  const dec = await takeQuota(db, "u", "free", "normal", "2026-12");
  assert.equal(dec.normalUsed, 1);
  assert.equal(dec.normalLimit, 5);
});

test("「正確に読む」は有料版だけ。普通の回数とは別に数える", async () => {
  const db = fakeDb();
  assert.equal(await takeQuota(db, "u", "free", "precise", "2026-11"), null);
  const q = await takeQuota(db, "u", "premium", "precise", "2026-11");
  assert.equal(q.preciseUsed, 1);
  assert.equal(q.preciseLimit, 10);
  assert.equal(q.normalUsed, 0);
  assert.equal(q.normalLimit, 200);
});

test("失敗したら 1 回戻し、動画のおまけの回数は上限に足す", async () => {
  const db = fakeDb();
  await takeQuota(db, "u", "free", "normal", "2026-11");
  await refundQuota(db, "u", "free", "normal", "2026-11");
  assert.equal(db.store.u.normal, 0);
  db.store.u.bonus = 2;
  assert.equal(quotaOf(db.store.u, "free", "2026-11").normalLimit, 7);
  assert.equal(quotaOf(db.store.u, "free", "2026-12").normalLimit, 5);
});

test("月は日本時間で数える", () => {
  // 11/30 15:00 UTC は日本時間 12/1 0:00
  assert.equal(monthKey(new Date("2026-11-30T15:00:00Z")), "2026-12");
  assert.equal(monthKey(new Date("2026-11-30T14:59:00Z")), "2026-11");
});

test("Claude の返した JSON を予定の一覧にする", async () => {
  let sent;
  const client = {messages: {stream: (p) => {
    sent = p;
    return {finalMessage: async () => ({
      stop_reason: "end_turn",
      usage: {input_tokens: 1, output_tokens: 1},
      content: [{type: "thinking", thinking: "..."}, {type: "text", text:
        JSON.stringify({events: [{date: "2026-11-14", allDay: true,
          start: "", end: "", title: "緑区大会", location: "大谷小",
          note: ""}], comment: ""})}],
    })};
  }}};
  const {result} = await readSchedule({client, model: "m",
    mimeType: "image/png", data: "AAAA", today: "2026-11-21", hint: ""});
  assert.equal(result.events[0].title, "緑区大会");
  assert.equal(sent.output_config.format.type, "json_schema");
  assert.equal(sent.thinking.type, "adaptive");
});
