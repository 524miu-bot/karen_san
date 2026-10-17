// アカウント削除。
//
// 消すもの：
//   - users/{uid}（所属グループ・推しの設定）と、その下の取り込んだ X の投稿
//   - グループのメンバー情報（名前・色）。最後の 1 人ならグループごと（予定・招待コードも）消す
//   - グループに残る予定のうち、本人が登録した予定の「登録した人」の名前
//   - Firebase Authentication のユーザー
// 残すもの：
//   - ほかのメンバーがいるグループの予定そのもの（家族の共有データのため）

const {FieldValue} = require("firebase-admin/firestore");

/**
 * グループから抜けるときの処理内容を決める（Firestore に触れない部分）。
 * @return {{action: "delete"} | {action: "leave", update: object}}
 */
function planLeave(family, uid) {
  const memberIds = Array.isArray(family.memberIds) ? family.memberIds : [];
  const others = memberIds.filter((id) => id !== uid);
  if (others.length === 0) return {action: "delete"};
  return {
    action: "leave",
    update: {
      memberIds: others,
      [`memberNames.${uid}`]: FieldValue.delete(),
      [`memberColors.${uid}`]: FieldValue.delete(),
    },
  };
}

async function leaveFamily(db, familyId, uid) {
  const familyRef = db.doc(`families/${familyId}`);
  const plan = await db.runTransaction(async (tx) => {
    const snap = await tx.get(familyRef);
    if (!snap.exists) return {action: "none"};
    const p = planLeave(snap.data(), uid);
    if (p.action === "leave") tx.update(familyRef, p.update);
    return {...p, inviteCode: snap.get("inviteCode")};
  });

  if (plan.action === "delete") {
    if (plan.inviteCode) await db.doc(`invites/${plan.inviteCode}`).delete();
    await db.recursiveDelete(familyRef); // 予定もまとめて消える
  } else if (plan.action === "leave") {
    // 残る予定から本人の名前を消す
    const mine = await familyRef.collection("events")
        .where("createdBy", "==", uid).get();
    for (let i = 0; i < mine.docs.length; i += 400) {
      const batch = db.batch();
      for (const doc of mine.docs.slice(i, i + 400)) {
        batch.update(doc.ref, {createdByName: ""});
      }
      await batch.commit();
    }
  }
}

async function deleteAccount({db, auth, uid}) {
  const userRef = db.doc(`users/${uid}`);
  const userSnap = await userRef.get();
  const familyId = userSnap.exists ? userSnap.get("familyId") : null;
  if (typeof familyId === "string" && familyId) {
    await leaveFamily(db, familyId, uid);
  }
  await db.recursiveDelete(userRef); // X の投稿（xdays）も消える
  try {
    await auth.deleteUser(uid);
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
  }
}

module.exports = {planLeave, deleteAccount};
