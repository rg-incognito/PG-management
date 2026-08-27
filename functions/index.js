const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getAuth } = require("firebase-admin/auth");
const { onDocumentWritten, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const crypto = require("crypto");

initializeApp();
const db = getFirestore();
const messaging = getMessaging();
const auth = getAuth();

const TIMEZONE = "Asia/Kolkata";

function currentMonthKey(date = new Date()) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`;
}

async function sendToTenant(tenantSnap, title, body, data = {}) {
  const token = tenantSnap.get("fcmToken");
  if (!token) return;
  try {
    await messaging.send({
      token,
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
    });
  } catch (err) {
    logger.warn(`FCM send failed for tenant ${tenantSnap.id}: ${err.message}`);
  }
}

async function sendToTokens(tokens, title, body, data = {}) {
  if (!tokens || tokens.length === 0) return;
  try {
    await messaging.sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
    });
  } catch (err) {
    logger.warn(`FCM multicast send failed: ${err.message}`);
  }
}

// Fires when a payment doc is created/updated. When status flips to "paid",
// push a confirmation to the tenant.
exports.onPaymentWritten = onDocumentWritten("payments/{paymentId}", async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after) return;

  const statusChangedToPaid = after.status === "paid" && before?.status !== "paid";
  if (!statusChangedToPaid) return;

  const tenantSnap = await db.collection("tenants").doc(after.tenantId).get();
  if (!tenantSnap.exists) return;

  await sendToTenant(
    tenantSnap,
    "Payment received",
    `Your rent payment for ${after.month} has been marked as paid. Thank you!`,
    { type: "payment_confirmed", month: after.month }
  );
});

// Fires when a tenant submits a payment claim (QR payment + receipt) from
// their app. Notifies every staff member assigned to that PG so they can
// review the receipt and mark the payment as paid.
exports.onPaymentClaimCreated = onDocumentCreated("paymentClaims/{claimId}", async (event) => {
  const claim = event.data.data();

  const [tenantSnap, staffSnap] = await Promise.all([
    db.collection("tenants").doc(claim.tenantId).get(),
    db.collection("staff").where("assignedPgIds", "array-contains", claim.pgId).get(),
  ]);
  const tenantName = tenantSnap.exists ? tenantSnap.get("name") : "A tenant";

  const tokens = staffSnap.docs.flatMap((doc) => doc.get("fcmTokens") || []);
  await sendToTokens(
    tokens,
    "Payment receipt submitted",
    `${tenantName} submitted a payment receipt for ${claim.month}. Review and confirm in the app.`,
    { type: "payment_claim_submitted", claimId: event.params.claimId, month: claim.month }
  );
});

// Fires on any tenant doc write. Notifies staff when the tenant submits
// documents for verification, and notifies the tenant once staff decide.
exports.onTenantVerificationChanged = onDocumentWritten("tenants/{tenantId}", async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after) return;

  const statusChanged = before?.verificationStatus !== after.verificationStatus;
  if (!statusChanged) return;

  if (after.verificationStatus === "pending") {
    const staffSnap = await db.collection("staff").where("assignedPgIds", "array-contains", after.pgId).get();
    const tokens = staffSnap.docs.flatMap((doc) => doc.get("fcmTokens") || []);
    await sendToTokens(
      tokens,
      "Tenant documents submitted",
      `${after.name} submitted documents for verification. Review in the app.`,
      { type: "tenant_verification_submitted", tenantId: event.params.tenantId }
    );
  } else if (after.verificationStatus === "verified" || after.verificationStatus === "rejected") {
    const tenantSnap = event.data.after;
    if (after.verificationStatus === "verified") {
      await sendToTenant(tenantSnap, "Documents verified", "Your documents have been verified by the PG owner.", {
        type: "tenant_verified",
      });
    } else {
      await sendToTenant(
        tenantSnap,
        "Documents rejected",
        after.verificationNote
          ? `Your documents were rejected: ${after.verificationNote}`
          : "Your documents were rejected. Please re-upload.",
        { type: "tenant_rejected" }
      );
    }
  }
});

// Runs daily: for every PG, check each active tenant's payment status for the
// current month against that PG's due date / penalty settings, and send the
// appropriate reminder (due soon / due today / overdue + penalty).
exports.dailyDueCheck = onSchedule(
  { schedule: "0 8 * * *", timeZone: TIMEZONE },
  async () => {
    const month = currentMonthKey();
    const today = new Date();
    const dayOfMonth = today.getDate();

    const pgsSnap = await db.collection("pgs").get();

    for (const pgDoc of pgsSnap.docs) {
      const pgId = pgDoc.id;
      const settingsSnap = await db.collection("settings").doc(pgId).get();
      const settings = settingsSnap.exists
        ? settingsSnap.data()
        : { dueDate: 5, penaltyType: "flat", penaltyValue: 0, reminderDaysBefore: 3 };

      const dueDate = settings.dueDate ?? 5;
      const reminderDaysBefore = settings.reminderDaysBefore ?? 3;
      const daysUntilDue = dueDate - dayOfMonth;

      const tenantsSnap = await db
        .collection("tenants")
        .where("pgId", "==", pgId)
        .where("status", "==", "active")
        .get();

      for (const tenantSnap of tenantsSnap.docs) {
        const tenantId = tenantSnap.id;
        const paymentId = `${tenantId}_${month}`;
        const paymentRef = db.collection("payments").doc(paymentId);
        const paymentSnap = await paymentRef.get();
        const payment = paymentSnap.exists ? paymentSnap.data() : null;

        if (payment?.status === "paid") continue;

        if (daysUntilDue === reminderDaysBefore) {
          await sendToTenant(
            tenantSnap,
            "Rent due soon",
            `Your rent for ${month} is due on day ${dueDate} of this month.`,
            { type: "due_soon", month }
          );
        } else if (daysUntilDue === 0) {
          await sendToTenant(
            tenantSnap,
            "Rent due today",
            `Your rent for ${month} is due today.`,
            { type: "due_today", month }
          );
        } else if (daysUntilDue < 0 && !payment?.penaltyApplied) {
          const rentAmount = tenantSnap.get("rentAmount") || 0;
          const penaltyValue = settings.penaltyValue ?? 0;
          const penaltyAmount =
            settings.penaltyType === "percentage"
              ? Math.round((rentAmount * penaltyValue) / 100)
              : penaltyValue;

          await paymentRef.set(
            {
              tenantId,
              pgId,
              month,
              amountPaid: payment?.amountPaid ?? 0,
              mode: payment?.mode ?? null,
              status: "overdue",
              penaltyApplied: penaltyAmount,
              updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
          );

          await sendToTenant(
            tenantSnap,
            "Rent overdue",
            `Your rent for ${month} is overdue. A penalty of ${penaltyAmount} has been applied.`,
            { type: "overdue", month, penaltyAmount }
          );
        }
      }
    }

    logger.info(`dailyDueCheck completed for ${month}`);
  }
);

function randomPassword(length = 10) {
  // Avoids visually-ambiguous characters (0/O, 1/l/I) since the owner reads
  // this out or texts it to the tenant.
  const alphabet = "ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
  const bytes = crypto.randomBytes(length);
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join("");
}

// Callable from the admin app. Creates (or resets, if one already exists)
// a Firebase Auth email/password account for a tenant's email, links it to
// their /tenants doc via authUid, and returns the generated password once
// so the owner can hand it to the tenant — Firebase never lets us read a
// password back after this.
exports.provisionTenantLogin = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const tenantId = request.data?.tenantId;
  if (!tenantId) {
    throw new HttpsError("invalid-argument", "tenantId is required.");
  }

  const tenantSnap = await db.collection("tenants").doc(tenantId).get();
  if (!tenantSnap.exists) {
    throw new HttpsError("not-found", "Tenant not found.");
  }
  const tenant = tenantSnap.data();
  if (!tenant.email) {
    throw new HttpsError("failed-precondition", "This tenant has no email on file.");
  }

  const staffSnap = await db.collection("staff").doc(request.auth.uid).get();
  const staff = staffSnap.exists ? staffSnap.data() : null;
  const hasAccess = staff && (staff.assignedPgIds || []).includes(tenant.pgId);
  if (!hasAccess) {
    throw new HttpsError("permission-denied", "You don't have access to this tenant's PG.");
  }

  const password = randomPassword();
  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(tenant.email);
    await auth.updateUser(userRecord.uid, { password });
  } catch (err) {
    if (err.code === "auth/user-not-found") {
      userRecord = await auth.createUser({ email: tenant.email, password, displayName: tenant.name });
    } else {
      throw err;
    }
  }

  await tenantSnap.ref.set({ authUid: userRecord.uid }, { merge: true });

  // Storage rules can't cheaply verify "does this login own this tenant
  // doc" via Firestore lookups, so that fact is baked into the ID token
  // itself as a custom claim instead.
  await auth.setCustomUserClaims(userRecord.uid, { tenantId });

  return { email: tenant.email, password };
});

// Callable from the admin app, owner-only. Creates (or resets) a Firebase
// Auth email/password account for a new or existing staff member, and
// writes/updates their /staff doc (name, role, assignedPgIds). Returns the
// generated password once, same one-time-reveal pattern as tenant logins.
exports.provisionStaffLogin = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const callerSnap = await db.collection("staff").doc(request.auth.uid).get();
  const caller = callerSnap.exists ? callerSnap.data() : null;
  if (!caller || caller.role !== "owner") {
    throw new HttpsError("permission-denied", "Only an owner can manage staff.");
  }

  const { email, name, role, assignedPgIds } = request.data || {};
  if (!email || !name || !role || !Array.isArray(assignedPgIds)) {
    throw new HttpsError("invalid-argument", "email, name, role, and assignedPgIds are required.");
  }
  if (role !== "owner" && role !== "manager") {
    throw new HttpsError("invalid-argument", "role must be 'owner' or 'manager'.");
  }

  const password = randomPassword();
  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
    await auth.updateUser(userRecord.uid, { password });
  } catch (err) {
    if (err.code === "auth/user-not-found") {
      userRecord = await auth.createUser({ email, password, displayName: name });
    } else {
      throw err;
    }
  }

  await db.collection("staff").doc(userRecord.uid).set({ name, role, assignedPgIds }, { merge: true });

  return { email, password };
});

// Keeps a `staff: true` custom claim on every staff member's login in sync
// with their /staff doc, so Storage rules can check `request.auth.token.staff`
// directly instead of an unreliable cross-service Firestore lookup.
exports.onStaffWritten = onDocumentWritten("staff/{staffId}", async (event) => {
  if (!event.data.after.exists) return;
  await auth.setCustomUserClaims(event.params.staffId, { staff: true });
});

// Callable from the admin app. Lets an owner/manager manually push a rent
// reminder right now to every active tenant in a PG who hasn't paid the
// current month yet — on top of the automatic dailyDueCheck job. Purely a
// notification: it doesn't touch payment records or apply penalties.
exports.sendPendingReminders = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const pgId = request.data?.pgId;
  if (!pgId) {
    throw new HttpsError("invalid-argument", "pgId is required.");
  }

  const staffSnap = await db.collection("staff").doc(request.auth.uid).get();
  const staff = staffSnap.exists ? staffSnap.data() : null;
  if (!staff || !(staff.assignedPgIds || []).includes(pgId)) {
    throw new HttpsError("permission-denied", "You don't have access to this PG.");
  }

  const month = currentMonthKey();
  const tenantsSnap = await db
    .collection("tenants")
    .where("pgId", "==", pgId)
    .where("status", "==", "active")
    .get();

  let notified = 0;
  for (const tenantDoc of tenantsSnap.docs) {
    const paymentSnap = await db.collection("payments").doc(`${tenantDoc.id}_${month}`).get();
    if (paymentSnap.exists && paymentSnap.get("status") === "paid") continue;

    await sendToTenant(
      tenantDoc,
      "Rent reminder",
      `Your rent for ${month} is still pending. Please pay at your earliest convenience.`,
      { type: "manual_reminder", month }
    );
    notified++;
  }

  return { notified, month };
});

// Fires when the owner sends an announcement. Pushes it to every active
// tenant in that PG.
exports.onBroadcastCreated = onDocumentCreated("broadcasts/{broadcastId}", async (event) => {
  const broadcast = event.data.data();

  const tenantsSnap = await db
    .collection("tenants")
    .where("pgId", "==", broadcast.pgId)
    .where("status", "==", "active")
    .get();

  const tokens = tenantsSnap.docs.map((d) => d.get("fcmToken")).filter(Boolean);
  await sendToTokens(tokens, broadcast.title, broadcast.message, {
    type: "broadcast",
    broadcastId: event.params.broadcastId,
  });
});
