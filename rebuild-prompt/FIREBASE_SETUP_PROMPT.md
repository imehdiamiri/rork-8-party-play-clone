# 8PartyPlay — Firebase Setup & Cloud Functions Prompt

This document covers the complete Firebase project configuration, Firestore security rules, and Cloud Functions TypeScript source for 8PartyPlay.

---

## 1. Firebase Project Configuration

### Services to enable
- **Authentication** — Email/Password, Google, Apple, Anonymous providers.
- **Firestore** — Native mode, multi-region (nam5 or eur3).
- **Realtime Database** — For presence / heartbeat (lighter than Firestore for online-status).
- **Cloud Functions** — Node 20 runtime, TypeScript.
- **Cloud Storage** — For user avatar uploads.
- **Cloud Messaging (FCM)** — For push notifications.
- **Remote Config** — For feature flags, version gates, maintenance mode.
- **App Check** — DeviceCheck (production) + Debug provider (CI/testing).
- **Analytics** — Enabled by default.

### iOS setup
1. Add `GoogleService-Info.plist` to the Xcode target (never commit to version control — use CI secret injection).
2. Add URL scheme from `GoogleService-Info.plist` `REVERSED_CLIENT_ID` for Google Sign-In.
3. Enable **Sign in with Apple** capability in Xcode + entitlements.
4. Register APNs certificates/keys in Firebase Console → Cloud Messaging.
5. Add `PrivacyInfo.xcprivacy` with required reason API entries (see App Store requirements).

### SPM packages to install
```
https://github.com/firebase/firebase-ios-sdk.git  ≥ 11.0.0
  Products: FirebaseAuth, FirebaseFirestore, FirebaseFirestoreSwift,
            FirebaseFunctions, FirebaseMessaging, FirebaseStorage,
            FirebaseRemoteConfig, FirebaseAnalytics, FirebaseAppCheck

https://github.com/google/GoogleSignIn-iOS.git  ≥ 7.0.0
  Products: GoogleSignIn, GoogleSignInSwift

https://github.com/RevenueCat/purchases-ios-spm.git  ≥ 5.0.0
  Products: RevenueCat, RevenueCatUI
```

### App initialization (`8PartyPlayApp.swift`)
```swift
import FirebaseCore
import FirebaseAppCheck
import RevenueCat

@main
struct EightPartyPlayApp: App {
    init() {
        // App Check — DeviceCheck in production, debug in simulator
        #if targetEnvironment(simulator)
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(DeviceCheckProviderFactory())
        #endif

        FirebaseApp.configure()

        // RevenueCat
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY)
        Purchases.logLevel = .error
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}
```

---

## 2. Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper functions
    function isSignedIn() {
      return request.auth != null;
    }
    function isOwner(uid) {
      return isSignedIn() && request.auth.uid == uid;
    }
    function isAdmin() {
      return isSignedIn() && request.auth.token.admin == true;
    }
    function isCloudFunction() {
      return request.auth.token.firebase.sign_in_provider == 'custom';
    }

    // ── Users ──────────────────────────────────────────────────────────────
    match /users/{uid} {
      allow read: if isSignedIn();
      allow create: if isOwner(uid);
      // Only allow writing non-financial fields from client
      allow update: if isOwner(uid)
        && !request.resource.data.keys().hasAny(['stars', 'subscriptionTier', 'subscriptionExpiresAt'])
        || isAdmin() || isCloudFunction();

      match /starTransactions/{txId} {
        allow read: if isOwner(uid);
        allow write: if isAdmin() || isCloudFunction();
      }

      match /savedCards/{cardId} {
        allow read, write: if isOwner(uid);
      }

      match /deviceTokens/{tokenId} {
        allow read, write: if isOwner(uid);
      }
    }

    // ── Username / PublicID uniqueness guards ──────────────────────────────
    match /usernames/{username} {
      allow read: if isSignedIn();
      allow write: if isAdmin() || isCloudFunction();
    }
    match /publicIDs/{id} {
      allow read: if isSignedIn();
      allow write: if isAdmin() || isCloudFunction();
    }

    // ── Friendships ────────────────────────────────────────────────────────
    match /friendships/{friendshipId} {
      function isParty() {
        return isSignedIn() && (
          request.auth.uid == resource.data.requesterID ||
          request.auth.uid == resource.data.recipientID
        );
      }
      allow read: if isParty() || isAdmin();
      // Create: only via Cloud Function (validates no duplicates, rate limit)
      allow create: if isCloudFunction();
      // Update: only recipient can accept/decline; Cloud Function handles it
      allow update, delete: if isCloudFunction() || isAdmin();
    }

    // ── Rooms ──────────────────────────────────────────────────────────────
    match /rooms/{roomId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn();
      allow update: if isSignedIn() && request.auth.uid == resource.data.hostID
        || isCloudFunction();
      allow delete: if isCloudFunction();

      match /players/{playerId} {
        allow read: if isSignedIn();
        allow write: if isSignedIn() && request.auth.uid == playerId
          || isSignedIn() && get(/databases/$(database)/documents/rooms/$(roomId)).data.hostID == request.auth.uid
          || isCloudFunction();
      }

      match /state/current {
        allow read: if isSignedIn();
        // Only host or Cloud Function writes authoritative game state
        allow write: if isSignedIn()
          && get(/databases/$(database)/documents/rooms/$(roomId)).data.hostID == request.auth.uid
          || isCloudFunction();
      }

      match /events/{eventId} {
        allow read: if isSignedIn();
        // Any authenticated player in the room can append events
        allow create: if isSignedIn()
          && exists(/databases/$(database)/documents/rooms/$(roomId)/players/$(request.auth.uid));
        allow update, delete: if false;
      }
    }

    // ── Room code lookup ───────────────────────────────────────────────────
    match /roomCodes/{code} {
      allow read: if isSignedIn();
      allow write: if isCloudFunction();
    }

    // ── Invites ────────────────────────────────────────────────────────────
    match /invites/{inviteId} {
      allow read: if isSignedIn();
      allow write: if isCloudFunction();
    }

    // ── Admin config ───────────────────────────────────────────────────────
    match /adminConfig/{doc} {
      allow read: if isSignedIn();
      allow write: if isAdmin();
    }
  }
}
```

---

## 3. Realtime Database Rules (Presence)

```json
{
  "rules": {
    "presence": {
      "$uid": {
        ".read": "auth != null",
        ".write": "auth != null && auth.uid === $uid"
      }
    },
    "rooms": {
      "$roomId": {
        "presence": {
          "$uid": {
            ".read": "auth != null",
            ".write": "auth != null && auth.uid === $uid"
          }
        }
      }
    }
  }
}
```

---

## 4. Cloud Functions — Full TypeScript Source

### `functions/src/index.ts`

```typescript
import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();

// ─── Constants ─────────────────────────────────────────────────────────────
const SIGNUP_BONUS_STARS = 50;
const INVITE_REWARD_STARS = 30;
const DAILY_REWARD_STARS = 5;
const AI_FREE_DAILY_QUOTA = 3;
const HOST_GRACE_PERIOD_SECONDS = 30;

// ─── onUserCreate ──────────────────────────────────────────────────────────
export const onUserCreate = functions.auth.user().onCreate(async (user) => {
  const counterRef = db.doc("adminConfig/counters");
  const publicUserID = await db.runTransaction(async (tx) => {
    const snap = await tx.get(counterRef);
    const current = snap.exists ? (snap.data()?.userCount ?? 0) : 0;
    const next = current + 1;
    tx.set(counterRef, { userCount: next }, { merge: true });
    return next;
  });

  const userRef = db.doc(`users/${user.uid}`);
  await userRef.set({
    username: user.displayName ?? `Player${publicUserID}`,
    usernameLower: (user.displayName ?? `player${publicUserID}`).toLowerCase(),
    email: user.email ?? null,
    publicUserID,
    avatarURL: user.photoURL ?? null,
    stars: SIGNUP_BONUS_STARS,
    subscriptionTier: "none",
    subscriptionExpiresAt: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
    matchesPlayed: 0,
    wins: 0,
  });

  // Uniqueness guard
  const usernameLower = (user.displayName ?? `player${publicUserID}`).toLowerCase();
  await db.doc(`usernames/${usernameLower}`).set({ uid: user.uid });
  await db.doc(`publicIDs/${publicUserID}`).set({ uid: user.uid });

  // Signup bonus transaction record
  await db.collection(`users/${user.uid}/starTransactions`).add({
    amount: SIGNUP_BONUS_STARS,
    type: "signup_bonus",
    description: "Welcome bonus",
    referenceID: null,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
});

// ─── grantStars ────────────────────────────────────────────────────────────
export const grantStars = functions.https.onCall(async (request) => {
  const { uid, amount, type, description, referenceID } = request.data as {
    uid: string; amount: number; type: string; description: string; referenceID?: string;
  };

  if (!request.auth?.token?.admin) {
    throw new functions.https.HttpsError("permission-denied", "Admin only.");
  }
  if (amount <= 0 || amount > 100000) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid amount.");
  }

  const userRef = db.doc(`users/${uid}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (!snap.exists) throw new functions.https.HttpsError("not-found", "User not found.");
    const current = snap.data()?.stars ?? 0;
    tx.update(userRef, { stars: current + amount, lastActiveAt: admin.firestore.FieldValue.serverTimestamp() });
    tx.set(db.collection(`users/${uid}/starTransactions`).doc(), {
      amount, type, description, referenceID: referenceID ?? null,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
});

// ─── spendStars ────────────────────────────────────────────────────────────
export const spendStars = functions.https.onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");

  const { amount, reason } = request.data as { amount: number; reason: string };
  if (amount <= 0) throw new functions.https.HttpsError("invalid-argument", "Amount must be positive.");

  const userRef = db.doc(`users/${uid}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (!snap.exists) throw new functions.https.HttpsError("not-found", "User not found.");
    const current = snap.data()?.stars ?? 0;
    if (current < amount) throw new functions.https.HttpsError("failed-precondition", "Insufficient stars.");
    tx.update(userRef, { stars: current - amount });
    tx.set(db.collection(`users/${uid}/starTransactions`).doc(), {
      amount: -amount, type: "spend", description: reason, referenceID: null,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
});

// ─── searchUsers ───────────────────────────────────────────────────────────
export const searchUsers = functions.https.onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");

  const { query } = request.data as { query: string };
  if (!query || query.trim().length < 2) {
    throw new functions.https.HttpsError("invalid-argument", "Query too short.");
  }

  const q = query.trim().toLowerCase();
  const usersRef = db.collection("users");

  // Search by usernameLower prefix
  const byUsername = await usersRef
    .where("usernameLower", ">=", q)
    .where("usernameLower", "<=", q + "\uf8ff")
    .limit(10)
    .get();

  // Search by publicUserID (numeric)
  const numericID = parseInt(q, 10);
  let byID: admin.firestore.QuerySnapshot | null = null;
  if (!isNaN(numericID)) {
    byID = await usersRef.where("publicUserID", "==", numericID).limit(5).get();
  }

  const results = new Map<string, object>();
  const addResult = (doc: admin.firestore.QueryDocumentSnapshot) => {
    if (doc.id !== uid) {
      const d = doc.data();
      results.set(doc.id, {
        uid: doc.id,
        username: d.username,
        publicUserID: d.publicUserID,
        avatarURL: d.avatarURL ?? null,
      });
    }
  };

  byUsername.docs.forEach(addResult);
  byID?.docs.forEach(addResult);

  return { users: Array.from(results.values()) };
});

// ─── sendFriendRequest ─────────────────────────────────────────────────────
export const sendFriendRequest = functions.https.onCall(async (request) => {
  const requesterID = request.auth?.uid;
  if (!requesterID) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");

  const { recipientID } = request.data as { recipientID: string };
  if (requesterID === recipientID) {
    throw new functions.https.HttpsError("invalid-argument", "Cannot friend yourself.");
  }

  // Check existing friendship
  const existing = await db.collection("friendships")
    .where("requesterID", "in", [requesterID, recipientID])
    .get();
  for (const doc of existing.docs) {
    const d = doc.data();
    if (
      (d.requesterID === requesterID && d.recipientID === recipientID) ||
      (d.requesterID === recipientID && d.recipientID === requesterID)
    ) {
      throw new functions.https.HttpsError("already-exists", "Friendship already exists.");
    }
  }

  await db.collection("friendships").add({
    requesterID, recipientID,
    state: "pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // FCM push to recipient (best-effort)
  const tokenSnap = await db.collection(`users/${recipientID}/deviceTokens`).get();
  const tokens = tokenSnap.docs.map((d) => d.data().token as string).filter(Boolean);
  if (tokens.length > 0) {
    const requesterSnap = await db.doc(`users/${requesterID}`).get();
    const requesterName = requesterSnap.data()?.username ?? "Someone";
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title: "Friend Request", body: `${requesterName} wants to be your friend!` },
      data: { type: "friend_request", fromUID: requesterID },
    });
  }

  return { success: true };
});

// ─── respondFriendRequest ─────────────────────────────────────────────────
export const respondFriendRequest = functions.https.onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");

  const { friendshipID, accept } = request.data as { friendshipID: string; accept: boolean };
  const ref = db.doc(`friendships/${friendshipID}`);
  const snap = await ref.get();
  if (!snap.exists) throw new functions.https.HttpsError("not-found", "Request not found.");

  const d = snap.data()!;
  if (d.recipientID !== uid) throw new functions.https.HttpsError("permission-denied", "Not recipient.");
  if (d.state !== "pending") throw new functions.https.HttpsError("failed-precondition", "Request not pending.");

  await ref.update({
    state: accept ? "accepted" : "declined",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

// ─── redeemInviteCode ──────────────────────────────────────────────────────
export const redeemInviteCode = functions.https.onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");

  const { code } = request.data as { code: string };
  const inviteSnap = await db.collection("invites").where("code", "==", code).limit(1).get();
  if (inviteSnap.empty) throw new functions.https.HttpsError("not-found", "Invalid invite code.");

  const inviteDoc = inviteSnap.docs[0];
  const invite = inviteDoc.data();

  if (invite.usedBy?.includes(uid)) {
    throw new functions.https.HttpsError("already-exists", "Already redeemed.");
  }
  if (invite.expiresAt && invite.expiresAt.toDate() < new Date()) {
    throw new functions.https.HttpsError("deadline-exceeded", "Invite expired.");
  }
  if (invite.usedBy?.length >= invite.maxUses) {
    throw new functions.https.HttpsError("resource-exhausted", "Invite limit reached.");
  }

  await inviteDoc.ref.update({ usedBy: admin.firestore.FieldValue.arrayUnion(uid) });

  // Reward referrer
  const referrerID: string = invite.createdBy;
  const userRef = db.doc(`users/${referrerID}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    const current = snap.data()?.stars ?? 0;
    tx.update(userRef, { stars: current + INVITE_REWARD_STARS });
    tx.set(db.collection(`users/${referrerID}/starTransactions`).doc(), {
      amount: INVITE_REWARD_STARS, type: "invite_reward",
      description: `Friend redeemed your invite code`,
      referenceID: uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { roomID: invite.roomID ?? null };
});

// ─── generateCards ─────────────────────────────────────────────────────────
export const generateCards = functions.https.onCall(
  { secrets: ["OPENAI_API_KEY"] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");

    const { category, subtype, vibe, audience, count = 6 } = request.data as {
      category: string; subtype: string; vibe: string; audience: string; count?: number;
    };

    // Check quota for free users
    const userSnap = await db.doc(`users/${uid}`).get();
    const tier = userSnap.data()?.subscriptionTier ?? "none";
    if (tier === "none") {
      const today = new Date().toISOString().split("T")[0];
      const quotaRef = db.doc(`users/${uid}/quotas/ai_${today}`);
      const quotaSnap = await quotaRef.get();
      const used = quotaSnap.exists ? (quotaSnap.data()?.used ?? 0) : 0;
      if (used >= AI_FREE_DAILY_QUOTA) {
        throw new functions.https.HttpsError("resource-exhausted", "Daily AI quota exceeded. Upgrade to Pro for unlimited.");
      }
      await quotaRef.set({ used: used + 1 }, { merge: true });
    }

    // Call OpenAI
    const apiKey = process.env.OPENAI_API_KEY;
    const prompt = `Generate ${count} unique party game card prompts for the following:
Category: ${category}
Subtype: ${subtype}
Vibe: ${vibe}
Audience: ${audience}

Return a JSON array of objects with keys: "text" (the card prompt, max 120 chars).
Be creative, fun, and appropriate. No offensive or adult content unless vibe is explicitly "spicy".
Only return the JSON array, no other text.`;

    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        temperature: 0.9,
        max_tokens: 600,
      }),
    });

    if (!resp.ok) {
      throw new functions.https.HttpsError("internal", "AI generation failed.");
    }

    const json = await resp.json() as { choices: { message: { content: string } }[] };
    const cards = JSON.parse(json.choices[0].message.content) as { text: string }[];

    return { cards };
  }
);

// ─── revenueCatWebhook ─────────────────────────────────────────────────────
export const revenueCatWebhook = functions.https.onRequest(async (req, res) => {
  // Verify RevenueCat webhook secret (set as environment variable RC_WEBHOOK_SECRET)
  const secret = process.env.RC_WEBHOOK_SECRET;
  const incoming = req.headers["authorization"];
  if (secret && incoming !== secret) {
    res.status(401).send("Unauthorized");
    return;
  }

  const event = req.body?.event;
  if (!event) { res.status(400).send("Bad Request"); return; }

  const appUserID: string = event.app_user_id;
  const eventType: string = event.type;

  // Map RevenueCat app_user_id to Firebase UID
  const userSnap = await db.collection("users")
    .where("revenueCatUserID", "==", appUserID)
    .limit(1).get();
  if (userSnap.empty) { res.status(200).send("Unknown user"); return; }

  const uid = userSnap.docs[0].id;

  if (eventType === "INITIAL_PURCHASE" || eventType === "RENEWAL") {
    const periodKey: string = event.period_type + "_" + event.event_timestamp_ms;
    const tier = event.product_id?.includes("yearly") ? "yearly" : "monthly";
    const bonusAmount = tier === "yearly" ? 100 : 30;
    const expiresAt = new Date(event.expiration_at_ms);

    // Idempotent: check if periodKey already claimed
    const txSnap = await db.collection(`users/${uid}/starTransactions`)
      .where("referenceID", "==", periodKey)
      .limit(1).get();
    if (!txSnap.empty) { res.status(200).send("Already processed"); return; }

    const userRef = db.doc(`users/${uid}`);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      const current = snap.data()?.stars ?? 0;
      tx.update(userRef, {
        stars: current + bonusAmount,
        subscriptionTier: tier,
        subscriptionExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      });
      tx.set(db.collection(`users/${uid}/starTransactions`).doc(), {
        amount: bonusAmount, type: "subscription_bonus",
        description: `${tier} subscription bonus`,
        referenceID: periodKey,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  }

  if (eventType === "EXPIRATION" || eventType === "CANCELLATION") {
    await db.doc(`users/${uid}`).update({
      subscriptionTier: "none",
      subscriptionExpiresAt: null,
    });
  }

  res.status(200).send("OK");
});

// ─── dailyReward (scheduled) ───────────────────────────────────────────────
export const dailyReward = functions.scheduler.onSchedule("every 24 hours", async () => {
  // This is a pull-model reward — clients request it themselves.
  // This scheduled function only cleans up stale quota documents.
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 2);
  // Cleanup logic would go here (optional)
});

// Client-callable daily reward claim
export const claimDailyReward = functions.https.onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");

  const today = new Date().toISOString().split("T")[0];
  const rewardRef = db.doc(`users/${uid}/dailyRewards/${today}`);

  const snap = await rewardRef.get();
  if (snap.exists) {
    throw new functions.https.HttpsError("already-exists", "Already claimed today.");
  }

  const userRef = db.doc(`users/${uid}`);
  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    const current = userSnap.data()?.stars ?? 0;
    tx.update(userRef, { stars: current + DAILY_REWARD_STARS });
    tx.set(rewardRef, { claimedAt: admin.firestore.FieldValue.serverTimestamp() });
    tx.set(db.collection(`users/${uid}/starTransactions`).doc(), {
      amount: DAILY_REWARD_STARS, type: "daily_reward",
      description: "Daily reward", referenceID: today,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { stars: DAILY_REWARD_STARS };
});

// ─── startRoom / closeRoom ─────────────────────────────────────────────────
export const startRoom = functions.https.onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");

  const { roomID } = request.data as { roomID: string };
  const roomRef = db.doc(`rooms/${roomID}`);
  const snap = await roomRef.get();
  if (!snap.exists) throw new functions.https.HttpsError("not-found", "Room not found.");
  if (snap.data()?.hostID !== uid) throw new functions.https.HttpsError("permission-denied", "Host only.");

  await roomRef.update({
    status: "inProgress",
    startedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

export const closeRoom = functions.https.onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");

  const { roomID, reason } = request.data as { roomID: string; reason?: string };
  const roomRef = db.doc(`rooms/${roomID}`);
  const snap = await roomRef.get();
  if (!snap.exists) throw new functions.https.HttpsError("not-found", "Room not found.");
  if (snap.data()?.hostID !== uid) throw new functions.https.HttpsError("permission-denied", "Host only.");

  await roomRef.update({
    status: "completed",
    closedAt: admin.firestore.FieldValue.serverTimestamp(),
    closeReason: reason ?? "host_closed",
  });

  // Clean up roomCode entry
  const code = snap.data()?.code;
  if (code) await db.doc(`roomCodes/${code}`).delete();

  return { success: true };
});

export const kickPlayer = functions.https.onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");

  const { roomID, targetUID } = request.data as { roomID: string; targetUID: string };
  const roomRef = db.doc(`rooms/${roomID}`);
  const snap = await roomRef.get();
  if (!snap.exists) throw new functions.https.HttpsError("not-found", "Room not found.");
  if (snap.data()?.hostID !== uid) throw new functions.https.HttpsError("permission-denied", "Host only.");

  await db.doc(`rooms/${roomID}/players/${targetUID}`).delete();
  return { success: true };
});
```

---

## 5. Environment Variables (Cloud Functions)

Set these in Firebase Console → Functions → Environment:

| Key | Description |
|---|---|
| `OPENAI_API_KEY` | Server-side OpenAI key (never exposed to client) |
| `RC_WEBHOOK_SECRET` | RevenueCat webhook authorization header value |

---

## 6. Swift Firebase Service Layer

### `FirebaseAuthService.swift`
```swift
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

@Observable
@MainActor
final class FirebaseAuthService {
    var currentUser: FirebaseAuth.User? = Auth.auth().currentUser
    private var authStateListener: AuthStateDidChangeListenerHandle?

    init() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.currentUser = user }
        }
    }

    // MARK: - Email/Password
    func signUp(email: String, password: String, username: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = username
        try await changeRequest.commitChanges()
    }

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    // MARK: - Google
    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        let idToken = result.user.idToken?.tokenString ?? ""
        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        try await Auth.auth().signIn(with: credential)
    }

    // MARK: - Apple
    private var currentNonce: String?

    func signInWithApple(authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8)
        else { throw AuthError.invalidCredential }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        try await Auth.auth().signIn(with: credential)
    }

    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    // MARK: - Guest
    func signInAsGuest() async throws {
        try await Auth.auth().signInAnonymously()
    }

    // MARK: - Sign Out
    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Delete Account
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        // Call Cloud Function to soft-delete first
        let functions = Functions.functions()
        try await functions.httpsCallable("deleteUserAccount").call(["uid": user.uid])
        try await user.delete()
    }

    // MARK: - Helpers
    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess { fatalError("Unable to generate nonce.") }
                return random
            }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count { result.append(charset[Int(random)]); remainingLength -= 1 }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

nonisolated enum AuthError: Error {
    case invalidCredential
}
```

### `FirebaseDatabaseService.swift` (key methods)

```swift
// Key patterns for Firestore operations:

// Fetch user profile
func fetchUser(uid: String) async throws -> UserProfile {
    let snap = try await db.document("users/\(uid)").getDocument()
    return try snap.data(as: UserProfile.self)
}

// Update username (validates uniqueness)
func updateUsername(uid: String, newUsername: String) async throws {
    let lower = newUsername.lowercased().trimmingCharacters(in: .whitespaces)
    guard lower.count >= 3 && lower.count <= 20 else { throw DBError.invalidUsername }

    // Check uniqueness
    let existing = try await db.document("usernames/\(lower)").getDocument()
    if existing.exists && existing.data()?["uid"] as? String != uid {
        throw DBError.usernameTaken
    }

    let batch = db.batch()
    batch.updateData(["username": newUsername, "usernameLower": lower], forDocument: db.document("users/\(uid)"))
    batch.setData(["uid": uid], forDocument: db.document("usernames/\(lower)"))
    try await batch.commit()
}

// Real-time room listener
func listenToRoom(roomID: String, onChange: @escaping (GameRoom) -> Void) -> ListenerRegistration {
    db.document("rooms/\(roomID)").addSnapshotListener { snap, _ in
        guard let room = try? snap?.data(as: GameRoom.self) else { return }
        Task { @MainActor in onChange(room) }
    }
}

// Star balance listener
func listenToStarBalance(uid: String, onChange: @escaping (Int) -> Void) -> ListenerRegistration {
    db.document("users/\(uid)").addSnapshotListener { snap, _ in
        let stars = snap?.data()?["stars"] as? Int ?? 0
        Task { @MainActor in onChange(stars) }
    }
}
```

---

## 7. Firestore Indexes (firestore.indexes.json)

```json
{
  "indexes": [
    {
      "collectionGroup": "friendships",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "recipientID", "order": "ASCENDING" },
        { "fieldPath": "state", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "friendships",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "requesterID", "order": "ASCENDING" },
        { "fieldPath": "state", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "rooms",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "access", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

---

## 8. RevenueCat Configuration

### iOS SDK setup (already in `8PartyPlayApp.swift` above)

### Offering structure (configure in RevenueCat dashboard)
```
Offering: "default"
  Package: "$rc_monthly"   → StoreKit product: "com.8partyplay.pro.monthly"
  Package: "$rc_annual"    → StoreKit product: "com.8partyplay.pro.yearly"

Offering: "star_packs"
  Package: "stars_small"   → "com.8partyplay.stars.100"   (100 ⭐)
  Package: "stars_medium"  → "com.8partyplay.stars.300"   (300 ⭐)
  Package: "stars_large"   → "com.8partyplay.stars.700"   (700 ⭐)
  Package: "stars_mega"    → "com.8partyplay.stars.1500"  (1500 ⭐)
```

### `StoreViewModel.swift` (key patterns)
```swift
@Observable
@MainActor
final class StoreViewModel {
    var offerings: Offerings?
    var isPro: Bool = false
    var isLoading: Bool = false

    func loadOfferings() async {
        do {
            offerings = try await Purchases.shared.offerings()
            let info = try await Purchases.shared.customerInfo()
            isPro = info.entitlements["pro"]?.isActive == true
        } catch { /* handle */ }
    }

    func purchase(package: Package) async throws {
        isLoading = true
        defer { isLoading = false }
        let result = try await Purchases.shared.purchase(package: package)
        isPro = result.customerInfo.entitlements["pro"]?.isActive == true
    }

    func restorePurchases() async throws {
        let info = try await Purchases.shared.restorePurchases()
        isPro = info.entitlements["pro"]?.isActive == true
    }
}
```
