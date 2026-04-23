# 8PartyPlay Admin Panel

A full-featured Next.js 15 admin dashboard for 8PartyPlay, backed by Supabase.

## Features
- Dashboard with KPIs (DAU/WAU/MAU, subs, stars, AI)
- User list + search + detail page
- Grant / deduct stars, unlock / lock games, ban / unban, grant subscription (30-day override)
- Invite tracking
- AI usage logs
- Analytics with 30-day signup chart
- Remote **App Config** (economy constants, feature flags) read by iOS app
- Remote **UI Config** (free game list, featured games, banners, theme)
- Announcements + push
- Full **audit log** of every admin action
- Email allow-list auth (no email = no access)

## 1. Deploy the Supabase SQL

Run in the Supabase SQL Editor (in order):
1. `supabase_final_production.sql` (already deployed)
2. `supabase_invite_system.sql` (already deployed)
3. **`supabase_admin_panel.sql`** (new — in repo root)

Then add yourself as the first admin:

```sql
INSERT INTO public.admin_users (email, role) VALUES ('you@example.com', 'superadmin');
```

## 2. Configure environment

Copy `.env.example` → `.env.local` and fill in:

```
NEXT_PUBLIC_SUPABASE_URL=https://YOUR-PROJECT.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...      # optional, not required for current features
```

## 3. Run locally

```bash
cd admin
npm install
npm run dev
# open http://localhost:3001
```

## 4. Deploy to Vercel

1. Push this repo to GitHub.
2. In Vercel: New Project → import the repo → **Root directory: `admin`**.
3. Add the env vars above in Project Settings → Environment Variables.
4. Deploy.
5. Add custom domain **admin.8partyplay.com** in Vercel → Domains, and add a CNAME record pointing to `cname.vercel-dns.com` in your DNS.

## 5. Access control

Only emails listed in `public.admin_users` can sign in. A normal Supabase auth password login is used. Anyone else will be redirected to the login screen with "not an admin" error.

## 6. iOS app — reading remote config

The iOS app can read both `app_config` and `ui_config` via Supabase (anon key; rows are publicly readable). Example helper:

```swift
let rows: [ConfigRow] = try await SupabaseService.shared.client
    .from("ui_config").select("*").execute().value
```

Update `free_games` in the UI Config page to change which games are free without shipping a new build.

## 7. Customization points

- `admin_set_subscription` grants 30 days by default — tweak default in the RPC or pass `p_expires_at`
- Game keys in `UserActions.tsx` (`ALL_GAMES`) — update to match your current game list
- Push notifications: `announcements.send_push` is a flag; wire it to a server function or OneSignal/APNs job when you set that up
