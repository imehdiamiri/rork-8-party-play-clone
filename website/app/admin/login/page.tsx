"use client";
import { Suspense, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { browserClient } from "@/lib/supabase";

function LoginForm() {
  const router = useRouter();
  const search = useSearchParams();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [err, setErr] = useState<string | null>(
    search.get("error") === "not_admin" ? "This account is not an admin." : null
  );
  const [loading, setLoading] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    setLoading(true);
    const sb = browserClient();
    const { error } = await sb.auth.signInWithPassword({ email, password });
    if (error) { setErr(error.message); setLoading(false); return; }
    const { data: isAdmin } = await sb.rpc("current_user_is_admin");
    if (!isAdmin) {
      await sb.auth.signOut();
      setErr("This account is not an admin.");
      setLoading(false);
      return;
    }
    router.push("/admin");
  }

  return (
    <form onSubmit={submit} className="card p-8 w-full max-w-sm space-y-4">
      <div>
        <div className="text-xl font-semibold">8PartyPlay Admin</div>
        <div className="text-sm text-muted mt-1">Sign in with your admin email</div>
      </div>
      <input className="input" type="email" placeholder="you@example.com" value={email} onChange={e=>setEmail(e.target.value)} required />
      <input className="input" type="password" placeholder="Password" value={password} onChange={e=>setPassword(e.target.value)} required />
      {err && <div className="text-sm text-red-400">{err}</div>}
      <button className="btn btn-primary w-full justify-center" disabled={loading}>
        {loading ? "Signing in…" : "Sign in"}
      </button>
    </form>
  );
}

export default function Login() {
  return (
    <div className="min-h-screen flex items-center justify-center p-6">
      <Suspense fallback={<div className="text-muted">Loading…</div>}>
        <LoginForm />
      </Suspense>
    </div>
  );
}
