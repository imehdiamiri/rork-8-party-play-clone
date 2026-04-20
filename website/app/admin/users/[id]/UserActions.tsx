"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { browserClient } from "@/lib/supabase";

const ALL_GAMES = [
  "reverse_singing","truth_or_dare","guess_seconds","memory_grid","imposter",
  "spin_bottle","draw_rush","memory_path","quick_game","cards"
];

export default function UserActions({ userId, unlocks, isSubscribed, isBanned }:
  { userId: string; unlocks: any[]; isSubscribed: boolean; isBanned: boolean }) {
  const router = useRouter();
  const sb = browserClient();
  const [busy, setBusy] = useState(false);
  const [delta, setDelta] = useState(50);
  const [reason, setReason] = useState("Admin grant");
  const unlockedKeys = new Set(unlocks.map(u => u.game_key));

  async function run(fn: () => Promise<any>) {
    setBusy(true);
    try { await fn(); router.refresh(); }
    catch (e: any) { alert(e.message); }
    finally { setBusy(false); }
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div className="card p-5 space-y-3">
        <h3 className="font-semibold">Adjust stars</h3>
        <input className="input" type="number" value={delta} onChange={e=>setDelta(parseInt(e.target.value)||0)} />
        <input className="input" value={reason} onChange={e=>setReason(e.target.value)} placeholder="Reason" />
        <div className="flex gap-2">
          <button disabled={busy} className="btn btn-primary flex-1 justify-center"
            onClick={()=>run(async()=>{ const {error} = await sb.rpc("admin_adjust_stars",{p_user_id:userId,p_delta:Math.abs(delta),p_reason:reason}); if(error) throw error; })}>
            + Grant
          </button>
          <button disabled={busy} className="btn btn-danger flex-1 justify-center"
            onClick={()=>run(async()=>{ const {error} = await sb.rpc("admin_adjust_stars",{p_user_id:userId,p_delta:-Math.abs(delta),p_reason:reason}); if(error) throw error; })}>
            − Deduct
          </button>
        </div>
      </div>

      <div className="card p-5 space-y-3">
        <h3 className="font-semibold">Subscription</h3>
        <div className="text-sm text-muted">Status: {isSubscribed ? "Active" : "Free"}</div>
        <div className="flex gap-2">
          <button disabled={busy} className="btn btn-primary flex-1 justify-center"
            onClick={()=>run(async()=>{ const {error} = await sb.rpc("admin_set_subscription",{p_user_id:userId,p_active:true,p_tier:"premium"}); if(error) throw error; })}>
            Grant 30d
          </button>
          <button disabled={busy} className="btn btn-danger flex-1 justify-center"
            onClick={()=>run(async()=>{ const {error} = await sb.rpc("admin_set_subscription",{p_user_id:userId,p_active:false}); if(error) throw error; })}>
            Revoke
          </button>
        </div>
      </div>

      <div className="card p-5 space-y-3">
        <h3 className="font-semibold">Ban</h3>
        <div className="text-sm text-muted">Status: {isBanned ? "Banned" : "Active"}</div>
        {!isBanned ? (
          <button disabled={busy} className="btn btn-danger w-full justify-center"
            onClick={()=>{ const r = prompt("Ban reason?") ?? ""; run(async()=>{ const {error} = await sb.rpc("admin_set_ban",{p_user_id:userId,p_banned:true,p_reason:r}); if(error) throw error; }); }}>
            Ban user
          </button>
        ) : (
          <button disabled={busy} className="btn btn-primary w-full justify-center"
            onClick={()=>run(async()=>{ const {error} = await sb.rpc("admin_set_ban",{p_user_id:userId,p_banned:false}); if(error) throw error; })}>
            Unban
          </button>
        )}
      </div>

      <div className="card p-5 md:col-span-3">
        <h3 className="font-semibold mb-3">Game unlocks</h3>
        <div className="grid grid-cols-2 md:grid-cols-5 gap-2">
          {ALL_GAMES.map(g => {
            const unlocked = unlockedKeys.has(g);
            return (
              <button key={g} disabled={busy}
                onClick={()=>run(async()=>{ const {error} = await sb.rpc("admin_unlock_game",{p_user_id:userId,p_game_key:g,p_lock:unlocked}); if(error) throw error; })}
                className={`btn justify-center text-xs ${unlocked ? "bg-[#13331f] border-[#1f5a33] text-green-400" : ""}`}>
                {unlocked ? "✓ " : ""}{g}
              </button>
            );
          })}
        </div>
        <div className="text-xs text-muted mt-2">Tap to toggle unlock / lock</div>
      </div>
    </div>
  );
}
