import { requireAdmin } from "@/lib/auth";
import { serverClient } from "@/lib/supabase-server";
import Shell from "@/components/Shell";

export const dynamic = "force-dynamic";

function Stat({ label, value, hint }: { label: string; value: any; hint?: string }) {
  return (
    <div className="card p-5">
      <div className="text-xs uppercase tracking-wide text-muted">{label}</div>
      <div className="text-3xl font-semibold mt-2">{value ?? "—"}</div>
      {hint && <div className="text-xs text-muted mt-1">{hint}</div>}
    </div>
  );
}

export default async function Dashboard() {
  const user = await requireAdmin();
  const sb = await serverClient();
  const { data } = await sb.rpc("admin_analytics_summary");
  const s: any = data ?? {};

  return (
    <Shell email={user.email ?? ""}>
      <h1 className="text-2xl font-semibold mb-6">Overview</h1>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Stat label="Total users" value={s.total_users} />
        <Stat label="New (24h)" value={s.new_users_24h} />
        <Stat label="New (7d)" value={s.new_users_7d} />
        <Stat label="New (30d)" value={s.new_users_30d} />
        <Stat label="DAU" value={s.dau} hint="last 24h" />
        <Stat label="WAU" value={s.wau} hint="last 7 days" />
        <Stat label="MAU" value={s.mau} hint="last 30 days" />
        <Stat label="Active subs" value={s.active_subscriptions} />
        <Stat label="Stars circulating" value={s.total_stars_circulating} />
        <Stat label="AI calls (24h)" value={s.ai_calls_24h} />
        <Stat label="AI stars spent (30d)" value={s.ai_stars_spent_30d} />
        <Stat label="Invites completed" value={s.invites_completed} />
        <Stat label="Banned users" value={s.banned_users} />
      </div>
    </Shell>
  );
}
