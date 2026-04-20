import { requireAdmin } from "@/lib/auth";
import { serverClient } from "@/lib/supabase-server";
import Shell from "@/components/Shell";

export const dynamic = "force-dynamic";

export default async function AuditPage() {
  const user = await requireAdmin();
  const sb = await serverClient();
  const { data } = await sb.from("admin_audit_log").select("*").order("created_at", { ascending: false }).limit(300);
  return (
    <Shell email={user.email ?? ""}>
      <h1 className="text-2xl font-semibold mb-6">Audit Log</h1>
      <div className="card overflow-hidden">
        <table>
          <thead><tr><th>When</th><th>Admin</th><th>Action</th><th>Target</th><th>Payload</th></tr></thead>
          <tbody>
            {(data ?? []).map((r: any) => (
              <tr key={r.id}>
                <td className="text-muted text-xs">{new Date(r.created_at).toLocaleString()}</td>
                <td>{r.admin_email}</td>
                <td><span className="badge">{r.action}</span></td>
                <td className="text-muted text-xs">{r.target_type}/{r.target_id}</td>
                <td className="text-muted text-xs font-mono max-w-md truncate">{r.payload ? JSON.stringify(r.payload) : "—"}</td>
              </tr>
            ))}
            {(!data || data.length === 0) && <tr><td colSpan={5} className="text-muted text-center py-6">No actions logged</td></tr>}
          </tbody>
        </table>
      </div>
    </Shell>
  );
}
