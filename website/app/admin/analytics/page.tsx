import { requireAdmin } from "@/lib/auth";
import { serverClient } from "@/lib/supabase-server";
import Shell from "@/components/Shell";
import Chart from "./Chart";

export const dynamic = "force-dynamic";

export default async function AnalyticsPage() {
  const user = await requireAdmin();
  const sb = await serverClient();
  const { data: series } = await sb.rpc("admin_signups_timeseries", { p_days: 30 });
  const { data: summary } = await sb.rpc("admin_analytics_summary");

  return (
    <Shell email={user.email ?? ""}>
      <h1 className="text-2xl font-semibold mb-6">Analytics</h1>
      <div className="card p-5 mb-6">
        <h3 className="font-semibold mb-3">Signups (last 30 days)</h3>
        <Chart data={(series ?? []).map((r: any) => ({ day: r.day, count: Number(r.count) }))} />
      </div>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Kpi label="Total users" value={(summary as any)?.total_users} />
        <Kpi label="DAU" value={(summary as any)?.dau} />
        <Kpi label="WAU" value={(summary as any)?.wau} />
        <Kpi label="MAU" value={(summary as any)?.mau} />
        <Kpi label="Active subs" value={(summary as any)?.active_subscriptions} />
        <Kpi label="Invites done" value={(summary as any)?.invites_completed} />
        <Kpi label="AI calls 24h" value={(summary as any)?.ai_calls_24h} />
        <Kpi label="Stars circulating" value={(summary as any)?.total_stars_circulating} />
      </div>
    </Shell>
  );
}

function Kpi({ label, value }: { label: string; value: any }) {
  return <div className="card p-5"><div className="text-xs text-muted uppercase">{label}</div><div className="text-2xl font-semibold mt-2">{value ?? "—"}</div></div>;
}
