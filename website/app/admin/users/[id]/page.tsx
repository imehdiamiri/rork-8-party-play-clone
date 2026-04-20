import { requireAdmin } from "@/lib/auth";
import { serverClient } from "@/lib/supabase-server";
import Shell from "@/components/Shell";
import UserActions from "./UserActions";

export const dynamic = "force-dynamic";

export default async function UserDetail({ params }: { params: Promise<{ id: string }> }) {
  const user = await requireAdmin();
  const { id } = await params;
  const sb = await serverClient();
  const { data } = await sb.rpc("admin_user_detail", { p_user_id: id });
  const d: any = data ?? {};
  const profile = d.profile ?? {};
  const wallet = d.wallet ?? {};
  const sub = d.subscription;
  const ban = d.ban;
  const unlocks: any[] = d.unlocks ?? [];
  const txs: any[] = d.recent_transactions ?? [];
  const ai: any[] = d.recent_ai ?? [];
  const inv = d.invite_stats ?? {};

  return (
    <Shell email={user.email ?? ""}>
      <div className="flex items-center gap-4 mb-6">
        <div>
          <h1 className="text-2xl font-semibold">{profile.username}</h1>
          <div className="text-muted text-sm">{profile.email} · #{profile.public_id} · {id}</div>
        </div>
        <div className="ml-auto flex gap-2">
          {sub && sub.status === "active" ? <span className="badge badge-green">subscribed · {sub.tier}</span> : <span className="badge">free</span>}
          {ban ? <span className="badge badge-red">banned</span> : <span className="badge badge-blue">active</span>}
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <div className="card p-5">
          <div className="text-xs text-muted uppercase mb-1">Stars balance</div>
          <div className="text-3xl font-semibold">{wallet.stars_balance ?? 0}</div>
        </div>
        <div className="card p-5">
          <div className="text-xs text-muted uppercase mb-1">Invite code</div>
          <div className="text-xl font-mono">{inv.invite_code ?? "—"}</div>
          <div className="text-xs text-muted mt-1">Invited {inv.invited_count ?? 0} users</div>
        </div>
        <div className="card p-5">
          <div className="text-xs text-muted uppercase mb-1">Unlocked games</div>
          <div className="text-xl font-semibold">{unlocks.length}</div>
        </div>
      </div>

      <UserActions userId={id} unlocks={unlocks} isSubscribed={sub?.status === "active"} isBanned={!!ban} />

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-8">
        <div className="card p-5">
          <h3 className="font-semibold mb-3">Recent star transactions</h3>
          <table>
            <thead><tr><th>When</th><th>Δ</th><th>Type</th><th>Reason</th></tr></thead>
            <tbody>
              {txs.map((t:any) => (
                <tr key={t.id}>
                  <td className="text-muted">{new Date(t.created_at).toLocaleString()}</td>
                  <td className={t.amount >= 0 ? "text-green-400" : "text-red-400"}>{t.amount > 0 ? "+" : ""}{t.amount}</td>
                  <td><span className="badge">{t.transaction_type}</span></td>
                  <td className="text-muted">{t.reason}</td>
                </tr>
              ))}
              {txs.length === 0 && <tr><td colSpan={4} className="text-muted text-center py-4">No transactions</td></tr>}
            </tbody>
          </table>
        </div>
        <div className="card p-5">
          <h3 className="font-semibold mb-3">Recent AI usage</h3>
          <table>
            <thead><tr><th>When</th><th>Feature</th><th>Cost</th><th>OK</th></tr></thead>
            <tbody>
              {ai.map((a:any) => (
                <tr key={a.id}>
                  <td className="text-muted">{new Date(a.created_at).toLocaleString()}</td>
                  <td>{a.feature}</td>
                  <td>{a.stars_cost}</td>
                  <td>{a.success ? "✅" : "❌"}</td>
                </tr>
              ))}
              {ai.length === 0 && <tr><td colSpan={4} className="text-muted text-center py-4">No AI activity</td></tr>}
            </tbody>
          </table>
        </div>
      </div>
    </Shell>
  );
}
