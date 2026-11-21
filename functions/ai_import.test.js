const test = require("node:test");
const assert = require("node:assert");
const {buildPrompt, fileBlock, cleanEvents, takeQuota, readSchedule} =
  require("./ai_import");

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

test("1 日の回数を超えたら断り、日が変われば戻る", async () => {
  const db = fakeDb();
  assert.equal(await takeQuota(db, "u", "2026-11-21", 2), true);
  assert.equal(await takeQuota(db, "u", "2026-11-21", 2), true);
  assert.equal(await takeQuota(db, "u", "2026-11-21", 2), false);
  assert.equal(await takeQuota(db, "u", "2026-11-22", 2), true);
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
