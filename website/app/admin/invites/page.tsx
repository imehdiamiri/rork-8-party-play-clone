import { requireAdmin } from "@/lib/auth";
import { serverClient } from "@/lib/supabase-server";
import Shell from "@/components/Shell";
import Link from "next/link";

export const dynamic = "force-dynamic";

export default async function InvitesPage() {
  const user = await requireAdmin();
  const sb = await serverClient();
  const { data } = await sb.from("profiles")
    .select("id, username, invite_code, invited_by, created_at")
    .not("invited_by", "is", null)
    .order("created_at", { ascending: false })
    .limit(200);

  return (
    <Shell email={user.email ?? ""}>
      <h1 className="text-2xl font-semibold mb-6">Invites</h1>
      <div className="card overflow-hidden">
        <table>
          <thead><tr><th>Invited user</th><th>Inviter</th><th>When</th></tr></thead>
          <tbody>
            {(data ?? []).map((r: any) => (
              <tr key={r.id}>
                <td><Link className="text-accent" href={`/users/${r.id}`}>{r.username}</Link></td>
                <td><Link className="text-accent" href={`/users/${r.invited_by}`}>{r.invited_by?.slice(0,8)}…</Link></td>
                <td className="text-muted text-xs">{new Date(r.created_at).toLocaleString()}</td>
              </tr>
            ))}
            {(!data || data.length === 0) && <tr><td colSpan={3} className="text-muted text-center py-6">No invites yet</td></tr>}
          </tbody>
        </table>
      </div>
    </Shell>
  );
}
