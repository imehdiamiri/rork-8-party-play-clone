# 8PartyPlay — Stripe Payments Prompt (Android + Web)

This document specifies the **Stripe** integration shared by the Android and Web clients. iOS continues to use RevenueCat/StoreKit per App Store policy; Stripe entitlements and RevenueCat entitlements converge on the same Firestore user doc.

---

## 1. Overview

- **What Stripe handles:**
  - **Subscriptions** — Monthly and Yearly "Pro" tiers.
  - **One-off star packs** — 100⭐, 500⭐, 1200⭐ (prices mirror iOS consumables).
- **Where Stripe is used:**
  - **Web** — Stripe Checkout + Customer Portal (redirect flows).
  - **Android** — Stripe Android SDK / PaymentSheet, or Stripe Checkout in a Chrome Custom Tab, depending on Play Store policy.
- **Where Stripe is NOT used:**
  - **iOS** — StoreKit via RevenueCat (App Store rules forbid third-party payments for digital goods).
- **Server:** Firebase Cloud Functions (Node 20, TypeScript) with the `stripe` npm package.

---

## 2. Stripe Dashboard Setup

1. Create a Stripe account; enable **Billing**.
2. Products and prices:
   - `prod_pro` — "8PartyPlay Pro"
     - `price_pro_monthly` — $4.99 / month
     - `price_pro_yearly` — $39.99 / year
   - `prod_star_pack_100` — "100 Stars" · `price_star_pack_100` · $0.99 · one-time
   - `prod_star_pack_500` — "500 Stars" · `price_star_pack_500` · $3.99 · one-time
   - `prod_star_pack_1200` — "1200 Stars" · `price_star_pack_1200` · $8.99 · one-time
3. Customer Portal configuration: allow subscription cancel, plan switch (monthly ↔ yearly), payment-method update, invoice history.
4. Webhook endpoint → **Firebase Cloud Function** `stripeWebhook` URL. Listen to:
   - `checkout.session.completed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.paid`
   - `invoice.payment_failed`
5. Copy the webhook signing secret → Firebase Functions config `stripe.webhook_secret`.
6. Copy the restricted secret key → Firebase Functions config `stripe.secret_key`.

```
firebase functions:config:set \
  stripe.secret_key="sk_live_..." \
  stripe.webhook_secret="whsec_..." \
  stripe.price_monthly="price_..." \
  stripe.price_yearly="price_..." \
  stripe.price_star_100="price_..." \
  stripe.price_star_500="price_..." \
  stripe.price_star_1200="price_..."
```

---

## 3. Cloud Functions — TypeScript

### `createStripeCheckoutSession` (callable)

```ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: "2024-10-28.acacia" });
const PRICE_MAP: Record<string, string> = {
  pro_monthly: process.env.STRIPE_PRICE_MONTHLY!,
  pro_yearly:  process.env.STRIPE_PRICE_YEARLY!,
  star_100:    process.env.STRIPE_PRICE_STAR_100!,
  star_500:    process.env.STRIPE_PRICE_STAR_500!,
  star_1200:   process.env.STRIPE_PRICE_STAR_1200!,
};

export const createStripeCheckoutSession = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Sign in required.");
  const uid = req.auth.uid;
  const { productKey, platform } = req.data as { productKey: string; platform: "web" | "android" };
  const priceId = PRICE_MAP[productKey];
  if (!priceId) throw new HttpsError("invalid-argument", "Unknown product.");

  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  const userSnap = await userRef.get();
  let customerId = userSnap.get("stripeCustomerID") as string | undefined;
  if (!customerId) {
    const customer = await stripe.customers.create({
      email: userSnap.get("email") ?? undefined,
      metadata: { firebaseUID: uid },
    });
    customerId = customer.id;
    await userRef.update({ stripeCustomerID: customerId });
  }

  const isSubscription = productKey.startsWith("pro_");
  const origin = platform === "android" ? "partyplay://billing" : "https://8partyplay.app/billing";
  const session = await stripe.checkout.sessions.create({
    mode: isSubscription ? "subscription" : "payment",
    customer: customerId,
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `${origin}/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url:  `${origin}/cancel`,
    allow_promotion_codes: true,
    metadata: { firebaseUID: uid, productKey, platform },
    subscription_data: isSubscription ? { metadata: { firebaseUID: uid, productKey } } : undefined,
  });

  return { url: session.url };
});
```

### `createStripePortalSession` (callable)

```ts
export const createStripePortalSession = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Sign in required.");
  const uid = req.auth.uid;
  const { platform } = req.data as { platform: "web" | "android" };
  const snap = await getFirestore().doc(`users/${uid}`).get();
  const customerId = snap.get("stripeCustomerID") as string | undefined;
  if (!customerId) throw new HttpsError("failed-precondition", "No Stripe customer.");
  const returnUrl = platform === "android" ? "partyplay://billing/portal-return" : "https://8partyplay.app/app/profile";
  const session = await stripe.billingPortal.sessions.create({ customer: customerId, return_url: returnUrl });
  return { url: session.url };
});
```

### `stripeWebhook` (HTTP)

```ts
import { onRequest } from "firebase-functions/v2/https";

export const stripeWebhook = onRequest({ rawBody: true }, async (req, res) => {
  const sig = req.headers["stripe-signature"] as string;
  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, process.env.STRIPE_WEBHOOK_SECRET!);
  } catch (err: any) {
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  const db = getFirestore();
  // Idempotency guard
  const eventRef = db.doc(`stripeEvents/${event.id}`);
  const existing = await eventRef.get();
  if (existing.exists) { res.json({ received: true, duplicate: true }); return; }

  try {
    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        const uid = session.metadata?.firebaseUID;
        const productKey = session.metadata?.productKey;
        if (!uid || !productKey) break;

        if (session.mode === "payment") {
          const stars = ({ star_100: 100, star_500: 500, star_1200: 1200 } as const)[productKey as "star_100"|"star_500"|"star_1200"] ?? 0;
          if (stars > 0) await grantStars(uid, stars, "stripe_pack", productKey);
        }
        break;
      }
      case "customer.subscription.created":
      case "customer.subscription.updated": {
        const sub = event.data.object as Stripe.Subscription;
        const uid = sub.metadata?.firebaseUID;
        if (!uid) break;
        const priceId = sub.items.data[0]?.price.id;
        const tier = priceId === process.env.STRIPE_PRICE_MONTHLY ? "monthly"
                  : priceId === process.env.STRIPE_PRICE_YEARLY  ? "yearly"  : "none";
        const status = sub.status; // active, trialing, past_due, canceled, etc.
        const expiresAt = new Date(sub.current_period_end * 1000);
        const active = status === "active" || status === "trialing";
        await db.doc(`users/${uid}`).update({
          subscriptionTier: active ? tier : "none",
          subscriptionSource: active ? "stripe" : null,
          subscriptionExpiresAt: active ? expiresAt : null,
        });
        // Grant periodic star bonus once per period
        if (active) await grantSubscriptionBonus(uid, tier, sub.id, sub.current_period_start);
        break;
      }
      case "customer.subscription.deleted": {
        const sub = event.data.object as Stripe.Subscription;
        const uid = sub.metadata?.firebaseUID;
        if (!uid) break;
        await db.doc(`users/${uid}`).update({
          subscriptionTier: "none",
          subscriptionSource: null,
          subscriptionExpiresAt: null,
        });
        break;
      }
      case "invoice.paid": {
        // Renewals: grant star bonus for the new period
        const invoice = event.data.object as Stripe.Invoice;
        const uid = invoice.subscription_details?.metadata?.firebaseUID
                 ?? (await stripe.subscriptions.retrieve(invoice.subscription as string)).metadata?.firebaseUID;
        if (uid && invoice.subscription) {
          const sub = await stripe.subscriptions.retrieve(invoice.subscription as string);
          const priceId = sub.items.data[0]?.price.id;
          const tier = priceId === process.env.STRIPE_PRICE_MONTHLY ? "monthly"
                    : priceId === process.env.STRIPE_PRICE_YEARLY  ? "yearly" : "none";
          if (tier !== "none") await grantSubscriptionBonus(uid, tier, sub.id, sub.current_period_start);
        }
        break;
      }
      case "invoice.payment_failed": {
        const invoice = event.data.object as Stripe.Invoice;
        const uid = (await stripe.subscriptions.retrieve(invoice.subscription as string)).metadata?.firebaseUID;
        if (uid) {
          await db.doc(`users/${uid}`).update({ subscriptionTier: "none", subscriptionSource: null });
        }
        break;
      }
    }
    await eventRef.set({ type: event.type, processedAt: FieldValue.serverTimestamp() });
    res.json({ received: true });
  } catch (err: any) {
    console.error(err);
    res.status(500).send("Internal error");
  }
});
```

### `grantStars` / `grantSubscriptionBonus` (helpers, atomic)

```ts
async function grantStars(uid: string, amount: number, type: string, referenceID: string) {
  const db = getFirestore();
  await db.runTransaction(async (tx) => {
    const userRef = db.doc(`users/${uid}`);
    const snap = await tx.get(userRef);
    const current = (snap.get("stars") as number) ?? 0;
    tx.update(userRef, { stars: current + amount });
    tx.set(db.collection(`users/${uid}/starTransactions`).doc(), {
      amount, type, referenceID, source: "stripe",
      description: `+${amount}⭐ via Stripe (${type})`,
      timestamp: FieldValue.serverTimestamp(),
    });
  });
}

async function grantSubscriptionBonus(uid: string, tier: "monthly"|"yearly", subscriptionId: string, periodStart: number) {
  const periodKey = `${subscriptionId}_${periodStart}`;
  const db = getFirestore();
  const guardRef = db.doc(`users/${uid}/starTransactions/sub_${periodKey}`);
  const exists = await guardRef.get();
  if (exists.exists) return;
  const amount = tier === "yearly" ? 600 : 50;
  await db.runTransaction(async (tx) => {
    const userRef = db.doc(`users/${uid}`);
    const snap = await tx.get(userRef);
    const current = (snap.get("stars") as number) ?? 0;
    tx.update(userRef, { stars: current + amount });
    tx.set(guardRef, {
      amount, type: "subscription_bonus", referenceID: periodKey, source: "stripe",
      description: `+${amount}⭐ (${tier} subscription bonus)`,
      timestamp: FieldValue.serverTimestamp(),
    });
  });
}
```

---

## 4. Web Client Flow

1. User taps **Go Pro** on paywall.
2. Client: `const { url } = await httpsCallable(functions, "createStripeCheckoutSession")({ productKey: "pro_monthly", platform: "web" })`.
3. `window.location.href = url`.
4. Stripe redirects to `/billing/success?session_id=...`. The page polls `/users/{uid}` until `subscriptionTier` flips (webhook finishes). Shows confetti + "Welcome to Pro".
5. **Manage Billing** button on Profile calls `createStripePortalSession` and redirects to the returned URL.

---

## 5. Android Client Flow

**Preferred (parity with web):**
1. User taps **Go Pro**.
2. Kotlin: `Functions.getInstance().getHttpsCallable("createStripeCheckoutSession").call(mapOf("productKey" to "pro_monthly", "platform" to "android"))`.
3. Open the returned URL in a **Chrome Custom Tab**.
4. Stripe redirects to `partyplay://billing/success`; `MainActivity` intent-filter catches it, closes the Custom Tab, polls `/users/{uid}` for entitlement, shows success.

**Alternative (in-app, if Play policy allows):**
- Use `PaymentSheet` with an ephemeral key from `createStripePaymentSheet` Cloud Function that returns `{ paymentIntentClientSecret, ephemeralKeySecret, customerId }`. Entitlement still confirmed via webhook.

---

## 6. Security & Compliance

- Webhook signature verification is **mandatory** — never trust the body alone.
- All Checkout Sessions carry `metadata.firebaseUID`. Never trust client-side stars crediting.
- Idempotency via `/stripeEvents/{eventId}` — duplicate webhook deliveries must not double-grant.
- App Check enforced on `createStripeCheckoutSession` and `createStripePortalSession`.
- No Stripe secret keys in client code. Publishable key only on clients.
- iOS users must not see Stripe buttons — gate by `Platform.isIOS` and offer RevenueCat paywall instead to satisfy App Store Guideline 3.1.1.
- Include "Billed by Stripe" and clear pricing on paywalls (Android + Web).
- Delete-account flow must cancel the Stripe subscription: `stripe.subscriptions.cancel(subId)` on the `deleteAccount` Cloud Function.

---

## 7. Testing

- Use Stripe **test mode** with test cards (`4242 4242 4242 4242`, `4000 0000 0000 9995` for declines, `4000 0025 0000 3155` for 3D Secure).
- Stripe CLI for local webhook testing: `stripe listen --forward-to http://localhost:5001/<project>/us-central1/stripeWebhook`.
- Automated tests cover: successful subscribe, renewal via `invoice.paid`, cancellation, star pack purchase, idempotent duplicate webhook.

---

## 8. Migration & Parity with RevenueCat

- A user who subscribes on iOS via RevenueCat gets `subscriptionSource: "apple"`. They see "Managed on iPhone" on web/Android Profile and cannot re-subscribe via Stripe while an Apple subscription is active.
- A user who subscribes on web/Android via Stripe gets `subscriptionSource: "stripe"`. On iOS, the Profile shows "Managed on Web" and hides the Stripe-only "Manage Billing" button; they must cancel via the Customer Portal.
- Both sources grant the same entitlements and the same periodic star bonus schedule.
