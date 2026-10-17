const test = require("node:test");
const assert = require("node:assert/strict");
const {FieldValue} = require("firebase-admin/firestore");

const {planLeave} = require("./account");

test("最後の 1 人ならグループごと削除する", () => {
  assert.deepEqual(planLeave({memberIds: ["me"]}, "me"), {action: "delete"});
  assert.deepEqual(planLeave({memberIds: []}, "me"), {action: "delete"});
  assert.deepEqual(planLeave({}, "me"), {action: "delete"});
});

test("ほかにメンバーがいれば、自分だけを外して名前と色を消す", () => {
  const p = planLeave({memberIds: ["mom", "me", "dad"]}, "me");
  assert.equal(p.action, "leave");
  assert.deepEqual(p.update.memberIds, ["mom", "dad"]);
  assert.ok(p.update["memberNames.me"].isEqual(FieldValue.delete()));
  assert.ok(p.update["memberColors.me"].isEqual(FieldValue.delete()));
  assert.deepEqual(Object.keys(p.update).sort(),
      ["memberColors.me", "memberIds", "memberNames.me"]);
});
