import { requireAdmin } from "@/lib/auth";
import { serverClient } from "@/lib/supabase-server";
import Shell from "@/components/Shell";
import Link from "next/link";

export const dynamic = "force-dynamic";

export default async function AiLogsPage() {
  const user = await requireAdmin();
  const sb = await serverClient();
  const { data } = await sb.from("ai_usage_log")
    .select("id, user_id, feature, stars_cost, success, error, created_at, profiles:user_id(username)")
    .order("created_at", { ascending: false }).limit(200);
  return (
    <Shell email={user.email ?? ""}>
      <h1 className="text-2xl font-semibold mb-6">AI Usage Logs</h1>
      <div className="card overflow-hidden">
        <table>
          <thead><tr><th>When</th><th>User</th><th>Feature</th><th>Cost</th><th>OK</th><th>Error</th></tr></thead>
          <tbody>
            {(data ?? []).map((r: any) => (
              <tr key={r.id}>
                <td className="text-muted text-xs">{new Date(r.created_at).toLocaleString()}</td>
                <td>{r.user_id ? <Link className="text-accent" href={`/users/${r.user_id}`}>{r.profiles?.username ?? r.user_id.slice(0,8)}</Link> : "—"}</td>
                <td>{r.feature}</td>
                <td>{r.stars_cost}</td>
                <td>{r.success ? "✅" : "❌"}</td>
                <td className="text-red-400 text-xs">{r.error}</td>
              </tr>
            ))}
            {(!data || data.length === 0) && <tr><td colSpan={6} className="text-muted text-center py-6">No AI activity</td></tr>}
          </tbody>
        </table>
      </div>
    </Shell>
  );
}
