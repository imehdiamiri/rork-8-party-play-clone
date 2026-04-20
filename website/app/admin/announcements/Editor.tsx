"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { browserClient } from "@/lib/supabase";

export default function Editor({ rows }: { rows: any[] }) {
  const router = useRouter();
  const sb = browserClient();
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [audience, setAudience] = useState("all");
  const [sendPush, setSendPush] = useState(false);
  const [busy, setBusy] = useState(false);

  async function create() {
    if (!title || !body) return;
    setBusy(true);
    const { error } = await sb.from("announcements").insert({ title, body, audience, send_push: sendPush, active: true });
    setBusy(false);
    if (error) { alert(error.message); return; }
    setTitle(""); setBody(""); router.refresh();
  }

  async function toggle(id: string, active: boolean) {
    await sb.from("announcements").update({ active }).eq("id", id);
    router.refresh();
  }

  return (
    <div className="space-y-6">
      <div className="card p-5 space-y-3">
        <h3 className="font-semibold">New announcement</h3>
        <input className="input" placeholder="Title" value={title} onChange={e=>setTitle(e.target.value)} />
        <textarea className="input" rows={3} placeholder="Body" value={body} onChange={e=>setBody(e.target.value)} />
        <div className="flex gap-3 items-center">
          <select className="input w-40" value={audience} onChange={e=>setAudience(e.target.value)}>
            <option value="all">All users</option>
            <option value="free">Free users</option>
            <option value="subscribed">Subscribers</option>
          </select>
          <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={sendPush} onChange={e=>setSendPush(e.target.checked)} /> Send push</label>
          <button className="btn btn-primary ml-auto" disabled={busy} onClick={create}>Publish</button>
        </div>
      </div>

      <div className="card overflow-hidden">
        <table>
          <thead><tr><th>Title</th><th>Audience</th><th>Push</th><th>Created</th><th>Status</th><th></th></tr></thead>
          <tbody>
            {rows.map(r => (
              <tr key={r.id}>
                <td><div className="font-semibold">{r.title}</div><div className="text-muted text-xs">{r.body}</div></td>
                <td><span className="badge">{r.audience}</span></td>
                <td>{r.send_push ? "✓" : "—"}</td>
                <td className="text-muted text-xs">{new Date(r.created_at).toLocaleString()}</td>
                <td>{r.active ? <span className="badge badge-green">active</span> : <span className="badge">archived</span>}</td>
                <td><button className="btn" onClick={()=>toggle(r.id, !r.active)}>{r.active ? "Archive" : "Unarchive"}</button></td>
              </tr>
            ))}
            {rows.length === 0 && <tr><td colSpan={6} className="text-center text-muted py-6">None yet</td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
