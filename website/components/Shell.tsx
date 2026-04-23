"use client";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { browserClient } from "@/lib/supabase";

const NAV = [
  { href: "/admin", label: "Dashboard", icon: "📊" },
  { href: "/admin/users", label: "Users", icon: "👥" },
  { href: "/admin/invites", label: "Invites", icon: "🎁" },
  { href: "/admin/ai-logs", label: "AI Logs", icon: "🤖" },
  { href: "/admin/analytics", label: "Analytics", icon: "📈" },
  { href: "/admin/content", label: "App Config", icon: "⚙️" },
  { href: "/admin/ui", label: "UI Config", icon: "🎨" },
  { href: "/admin/announcements", label: "Announcements", icon: "📣" },
  { href: "/admin/audit", label: "Audit Log", icon: "📜" },
];

export default function Shell({ email, children }: { email: string; children: React.ReactNode }) {
  const path = usePathname();
  const router = useRouter();

  async function signOut() {
    await browserClient().auth.signOut();
    router.push("/admin/login");
  }

  return (
    <div className="min-h-screen grid grid-cols-[240px_1fr]">
      <aside className="border-r border-border bg-panel p-4 flex flex-col">
        <div className="text-lg font-semibold mb-6 px-2">8PartyPlay Admin</div>
        <nav className="flex flex-col gap-1">
          {NAV.map(n => {
            const active = path === n.href || (n.href !== "/admin" && path.startsWith(n.href));
            return (
              <Link key={n.href} href={n.href}
                className={`px-3 py-2 rounded-lg text-sm flex items-center gap-2 ${active ? "bg-[#1a1a1d] text-white" : "text-muted hover:text-white hover:bg-[#141416]"}`}>
                <span>{n.icon}</span>{n.label}
              </Link>
            );
          })}
        </nav>
        <div className="mt-auto pt-4 border-t border-border text-xs text-muted">
          <div className="truncate mb-2">{email}</div>
          <button onClick={signOut} className="btn w-full justify-center">Sign out</button>
        </div>
      </aside>
      <main className="p-6 overflow-auto">{children}</main>
    </div>
  );
}
