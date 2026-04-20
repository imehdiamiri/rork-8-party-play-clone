import { requireAdmin } from "@/lib/auth";
import { serverClient } from "@/lib/supabase-server";
import Shell from "@/components/Shell";
import Editor from "./Editor";

export const dynamic = "force-dynamic";

export default async function AnnouncementsPage() {
  const user = await requireAdmin();
  const sb = await serverClient();
  const { data } = await sb.from("announcements").select("*").order("created_at", { ascending: false });
  return (
    <Shell email={user.email ?? ""}>
      <h1 className="text-2xl font-semibold mb-6">Announcements</h1>
      <Editor rows={data ?? []} />
    </Shell>
  );
}
