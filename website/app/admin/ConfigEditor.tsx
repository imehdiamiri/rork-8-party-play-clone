"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { browserClient } from "@/lib/supabase";

export default function ConfigEditor({ table, rpc, rows }: { table: string; rpc: string; rows: any[] }) {
  const router = useRouter();
  const sb = browserClient();
  const [editing, setEditing] = useState<Record<string, string>>({});
  const [newKey, setNewKey] = useState("");
  const [newValue, setNewValue] = useState("");
  const [newDesc, setNewDesc] = useState("");
  const [busy, setBusy] = useState(false);

  async function save(key: string, rawValue: string, description?: string) {
    setBusy(true);
    try {
      const value = JSON.parse(rawValue);
      const { error } = await sb.rpc(rpc, { p_key: key, p_value: value, p_description: description ?? null });
      if (error) throw error;
      setEditing(s => { const n = {...s}; delete n[key]; return n; });
      router.refresh();
    } catch (e: any) { alert("Invalid JSON or error: " + e.message); }
    finally { setBusy(false); }
  }

  return (
    <div className="space-y-4">
      <div className="card p-5">
        <h3 className="font-semibold mb-3">Add new key</h3>
        <div className="grid grid-cols-1 md:grid-cols-[1fr_2fr_1fr_auto] gap-2">
          <input className="input" placeholder="key.dot.path" value={newKey} onChange={e=>setNewKey(e.target.value)} />
          <input className="input font-mono" placeholder='JSON value, e.g. "hello" or 42 or {"a":1}' value={newValue} onChange={e=>setNewValue(e.target.value)} />
          <input className="input" placeholder="description (optional)" value={newDesc} onChange={e=>setNewDesc(e.target.value)} />
          <button className="btn btn-primary" disabled={busy || !newKey}
            onClick={async()=>{ await save(newKey, newValue || "null", newDesc); setNewKey(""); setNewValue(""); setNewDesc(""); }}>
            Save
          </button>
        </div>
      </div>

      <div className="card overflow-hidden">
        <table>
          <thead><tr><th>Key</th><th>Value</th><th>Description</th><th>Updated</th><th></th></tr></thead>
          <tbody>
            {rows.map(r => {
              const val = editing[r.key] ?? JSON.stringify(r.value, null, 0);
              const dirty = editing[r.key] !== undefined;
              return (
                <tr key={r.key}>
                  <td className="font-mono">{r.key}</td>
                  <td>
                    <textarea className="input font-mono text-xs" rows={dirty ? 3 : 1}
                      value={val}
                      onChange={e=>setEditing(s=>({...s,[r.key]:e.target.value}))} />
                  </td>
                  <td className="text-muted text-xs">{r.description}</td>
                  <td className="text-muted text-xs">{r.updated_at ? new Date(r.updated_at).toLocaleDateString() : "—"}</td>
                  <td>
                    {dirty && <button className="btn btn-primary" disabled={busy} onClick={()=>save(r.key, editing[r.key], r.description)}>Save</button>}
                  </td>
                </tr>
              );
            })}
            {rows.length === 0 && <tr><td colSpan={5} className="text-center text-muted py-6">No entries</td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
