# 8PartyPlay — Web App Prompt (Next.js + React + Tailwind)

This document specifies the **marketing site + full web app** in the `website/` folder. Dark mode only. Feature parity with iOS and Android. Single Firebase backend shared with the other clients.

---

## 1. Tech Stack

- **Framework:** Next.js 14 (App Router) · React 18 · TypeScript (strict)
- **Styling:** Tailwind CSS 3.4+ with custom tokens that mirror `02_DESIGN_SYSTEM_PROMPT.md`
- **UI primitives:** `shadcn/ui` (Radix + Tailwind)
- **Motion:** Framer Motion for page + list + card animations
- **Icons:** `lucide-react`
- **Firebase:** `firebase@10` modular SDK (Auth, Firestore, RTDB, Functions, Messaging, Storage, Analytics, AppCheck with reCAPTCHA v3)
- **Payments:** Stripe — `@stripe/stripe-js` on client, `stripe` Node SDK in route handlers
- **Realtime:** Firestore `onSnapshot` + Realtime DB presence
- **Forms:** `react-hook-form` + `zod`
- **State:** React Context + Zustand for global stores (`useAuthStore`, `useRoomStore`, `useStarsStore`)
- **PWA:** `next-pwa` or custom service worker (`public/sw.js`) with offline fallback for tools
- **Deploy:** Vercel, edge functions for light endpoints, Node runtime for Stripe webhook

---

## 2. Project Structure

```
website/
  app/
    (marketing)/
      page.tsx                    // hero + features + testimonials + FAQ
      privacy/page.tsx
      terms/page.tsx
      support/page.tsx
      delete-account/page.tsx     // Google Play compliance
    (app)/
      app/
        layout.tsx                // auth-guarded shell with sidebar + tabs
        games/page.tsx
        games/[game]/page.tsx     // setup + session
        tools/page.tsx
        tools/[tool]/page.tsx
        cards/page.tsx
        cards/[deck]/page.tsx
        friends/page.tsx
        factory/page.tsx
        profile/page.tsx
        paywall/page.tsx
    auth/
      sign-in/page.tsx
      sign-up/page.tsx
      forgot-password/page.tsx
    invite/page.tsx               // ?code=XXXX
    r/[code]/page.tsx             // room quick-join universal link
    billing/
      success/page.tsx
      cancel/page.tsx
    api/
      stripe/
        checkout/route.ts         // POST → Stripe Checkout Session
        portal/route.ts           // POST → Billing Portal URL
        webhook/route.ts          // Stripe webhook (raw body)
      ai/
        generate-cards/route.ts   // proxies to Firebase callable
    layout.tsx                    // <html lang="en"> dark, font-inter
    globals.css
    manifest.ts                   // PWA manifest
    robots.ts
    sitemap.ts
  components/
    marketing/                    // Hero, FeatureGrid, Testimonials, FAQ, Footer
    app/
      layout/AppShell.tsx         // sidebar (desktop) + bottom tabs (mobile)
      layout/ProfileDrawer.tsx
      layout/ConnectionBanner.tsx
      games/                      // GameCard, ModeChip, per-game views
      tools/                      // Dice3D, Bottle, Hourglass, Coin, TeamSplitter
      cards/                      // CardStack, DeckTile
      friends/
      factory/
      paywall/
    ui/                           // shadcn primitives
    common/ViralTitle.tsx, GlassCard.tsx, StarBadge.tsx
  lib/
    firebase/
      client.ts                   // initializeApp, getAuth, getFirestore, AppCheck
      admin.ts                    // firebase-admin for server routes
      auth.ts
      firestore.ts
      messaging.ts                // FCM Web push subscribe
    stripe/
      client.ts                   // loadStripe
      server.ts                   // Stripe(apiVersion)
      products.ts                 // price id map
    game/
      state-machine.ts            // shared with iOS/Android semantics
      [game].ts                   // per-game pure logic
    hooks/
      useAuth.ts
      useUser.ts
      useRoom.ts
      useStars.ts
  public/
    icons/                        // PWA icons from h03kekxe8ymunf0mls4b3.png
    sounds/
    sw.js
  styles/
  tailwind.config.ts
  next.config.mjs
```

---

## 3. Theme

Tailwind config:
```ts
colors: {
  bg: { DEFAULT: "#05060B", elevated: "#0B0D15" },
  border: { subtle: "rgba(255,255,255,0.05)" },
  text: { primary: "#F5F6FA", secondary: "rgba(245,246,250,0.68)" },
  accent: { indigo: "#6366F1", violet: "#8B5CF6", pink: "#EC4899", cyan: "#22D3EE", orange: "#F97316", yellow: "#FACC15", green: "#22C55E", red: "#EF4444" },
}
fontFamily: {
  sans: ["Inter", ...],
  viral: ["'Space Grotesk'", "Anton", ...],
}
```

- Root `<html class="dark">`. No light theme.
- Background layer: fixed `div` with mesh gradient via stacked radial gradients + `backdrop-blur-3xl`.
- Cards: `bg-white/5 backdrop-blur-xl border border-white/5 rounded-[18px]`.

---

## 4. Marketing Site

- **Hero:** viral title "Your phone is the party.", subtitle, three CTAs — App Store, Google Play, "Play on web". Animated mesh gradient background.
- **Feature grid:** 11 games, each with SF-symbol-equivalent Lucide icon + short description.
- **Tools strip:** 5 tools with short animations (hover reveals a looping demo).
- **Testimonials, FAQ, Footer** with legal links.
- **Invite landing** at `/invite?code=...` — persists code to localStorage, detects platform via UA, redirects to store or `/app`.
- **Legal pages** aligned with Apple + Google review: Privacy Policy, Terms, Support, Delete Account request form.

---

## 5. Web App (`/app/*`)

- Auth-guarded via middleware on `/app/*`. Redirect to `/auth/sign-in` when no Firebase session.
- Layout: **Sidebar on `md+`**, **bottom tab bar on mobile**. Floating Profile avatar top-right on all pages.
- Connection banner (thin) when Firestore is offline.
- Full 4-tab IA: Games, Tools, Friends, Factory.
- All 11 games playable in the browser — for multi-device, the host can be on web, joiners on iOS / Android / other web tabs. Responsive layouts: phone portrait, tablet landscape, desktop.
- Tools work offline when PWA-installed.

---

## 6. Auth

- Firebase Auth with providers: Google, Apple (OAuth web), Email/Password, Anonymous.
- After successful sign-in, create or update the user doc via Cloud Function `ensureUser`.
- Password reset flow via `/auth/forgot-password`.
- Store FCM web token after permission grant; request only after first explicit user action.

---

## 7. Stripe Integration

- Client flow:
  1. User clicks "Go Pro" → POST `/api/stripe/checkout` with `{ priceId }`.
  2. Route handler (server) uses `stripe.checkout.sessions.create({ mode: "subscription", customer, line_items, success_url: "/billing/success?session_id={CHECKOUT_SESSION_ID}", cancel_url: "/billing/cancel", metadata: { uid } })`.
  3. Return `{ url }`; client `window.location = url`.
  4. `/billing/success` polls `/users/{uid}` for `subscriptionTier` to flip before showing confetti.
- Billing Portal: POST `/api/stripe/portal` returns `url`, redirect.
- Star packs: same pattern with `mode: "payment"`.
- Webhook at `/api/stripe/webhook` — raw body via `export const config = { api: { bodyParser: false } }` pattern (App Router: read `req.text()`, verify with `stripe.webhooks.constructEvent`). For security the webhook is **also** implemented as a Firebase Cloud Function `stripeWebhook` — the Next.js route simply forwards to it (or the Stripe dashboard points straight to the Cloud Function URL, and the Next.js route is optional). Full details in `19_STRIPE_PAYMENTS_PROMPT.md`.

---

## 8. Realtime Multiplayer on Web

- `useRoom(roomId)` hook subscribes to three `onSnapshot` listeners (`/rooms/{id}`, `/players`, `/state/current`).
- Presence: on sign-in, `ref(rtdb, 'presence/' + uid).onDisconnect().set({ online: false, at: serverTimestamp() })`.
- Optimistic UI with rollback on Firestore transaction failure.
- Canvas-based drawing for Draw & Rush uses `<canvas>` + pointer events; strokes uploaded to Firestore in chunks.
- Reconnection handled by Firestore SDK; web shell shows a banner when `enableNetwork` is retrying.

---

## 9. PWA

- `app/manifest.ts` → name "8PartyPlay", short_name "PartyPlay", theme_color "#05060B", background_color "#05060B", icons from `h03kekxe8ymunf0mls4b3.png` at 192/512/maskable, display "standalone", start_url "/app".
- Service worker caches: offline shell (`/app`), all tool assets, SF/Lucide icon font, card `deck.json`.
- Push notifications via Firebase Messaging Web SDK + `public/firebase-messaging-sw.js`.

---

## 10. SEO & Meta

- Per-page `generateMetadata` with OG image, Twitter card.
- `/sitemap.xml` and `/robots.txt` via `sitemap.ts` / `robots.ts`.
- Schema.org `SoftwareApplication` on the homepage, `FAQPage` on FAQ section.
- Structured performance: Lighthouse 95+ on mobile for the marketing site.

---

## 11. Accessibility & i18n

- Semantic HTML, skip-link, focus rings, `aria-live="polite"` for toasts.
- Full keyboard navigation on all 11 games.
- `prefers-reduced-motion` respected.
- Copy wrapped with `next-intl` or `react-i18next` scaffolding (default locale `en`).

---

## 12. Environment Variables

Public (prefixed with `NEXT_PUBLIC_`):
```
NEXT_PUBLIC_FIREBASE_API_KEY
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN
NEXT_PUBLIC_FIREBASE_PROJECT_ID
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID
NEXT_PUBLIC_FIREBASE_APP_ID
NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID
NEXT_PUBLIC_FIREBASE_VAPID_KEY           # FCM web push
NEXT_PUBLIC_RECAPTCHA_SITE_KEY           # App Check
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY
NEXT_PUBLIC_STRIPE_PRICE_MONTHLY
NEXT_PUBLIC_STRIPE_PRICE_YEARLY
NEXT_PUBLIC_APP_URL
```

Server-only (Vercel env):
```
FIREBASE_ADMIN_PROJECT_ID
FIREBASE_ADMIN_CLIENT_EMAIL
FIREBASE_ADMIN_PRIVATE_KEY
STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET
AI_PROVIDER_API_KEY
```

---

## 13. Testing

- Unit tests with Vitest for pure logic (`lib/game/*`).
- Component tests with Testing Library.
- E2E with Playwright: auth, join room, play one round of Memory Grid, open paywall, Stripe Checkout (test mode).
- Lighthouse CI budget: LCP < 2.5s mobile, CLS < 0.05.

---

## 14. Deployment

- Vercel project with the `website/` root, custom domain `8partyplay.app`.
- Preview deploys on PRs.
- Firebase Admin SDK credentials via Vercel env.
- Stripe webhook endpoint registered in Stripe Dashboard: `https://8partyplay.app/api/stripe/webhook` (or Cloud Function URL). Use `STRIPE_WEBHOOK_SECRET` for signature verification.
