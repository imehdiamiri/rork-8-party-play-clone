import { requireAdmin } from "@/lib/auth";
import { serverClient } from "@/lib/supabase-server";
import Shell from "@/components/Shell";
import Link from "next/link";

export const dynamic = "force-dynamic";

export default async function UsersPage({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
  const user = await requireAdmin();
  const { q = "" } = await searchParams;
  const sb = await serverClient();
  const { data: users } = await sb.rpc("admin_search_users", { p_query: q, p_limit: 100, p_offset: 0 });

  return (
    <Shell email={user.email ?? ""}>
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-2xl font-semibold">Users</h1>
        <form className="flex gap-2">
          <input name="q" defaultValue={q} placeholder="Search username, email, id…" className="input w-80" />
          <button className="btn btn-primary">Search</button>
        </form>
      </div>
      <div className="card overflow-hidden">
        <table>
          <thead>
            <tr><th>User</th><th>Email</th><th>Stars</th><th>Sub</th><th>Status</th><th>Joined</th><th>Last seen</th></tr>
          </thead>
          <tbody>
            {(users ?? []).map((u: any) => (
              <tr key={u.id}>
                <td>
                  <Link href={`/users/${u.id}`} className="text-accent">
                    {u.username} <span className="text-muted">#{u.public_id}</span>
                  </Link>
                </td>
                <td className="text-muted">{u.email ?? "—"}</td>
                <td>{u.stars_balance}</td>
                <td>{u.is_subscribed ? <span className="badge badge-green">active</span> : <span className="badge">free</span>}</td>
                <td>{u.is_banned ? <span className="badge badge-red">banned</span> : <span className="badge badge-blue">ok</span>}</td>
                <td className="text-muted">{new Date(u.created_at).toLocaleDateString()}</td>
                <td className="text-muted">{u.last_sign_in_at ? new Date(u.last_sign_in_at).toLocaleDateString() : "—"}</td>
              </tr>
            ))}
            {(!users || users.length === 0) && <tr><td colSpan={7} className="text-center text-muted py-8">No users found</td></tr>}
          </tbody>
        </table>
      </div>
    </Shell>
  );
}
