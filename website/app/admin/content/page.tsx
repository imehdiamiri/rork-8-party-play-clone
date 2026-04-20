import { requireAdmin } from "@/lib/auth";
import { serverClient } from "@/lib/supabase-server";
import Shell from "@/components/Shell";
import ConfigEditor from "../ConfigEditor";

export const dynamic = "force-dynamic";

export default async function ContentPage() {
  const user = await requireAdmin();
  const sb = await serverClient();
  const { data } = await sb.from("app_config").select("*").order("key");
  return (
    <Shell email={user.email ?? ""}>
      <h1 className="text-2xl font-semibold mb-1">App Config</h1>
      <p className="text-muted text-sm mb-6">Remote configuration read by the iOS app. Edit JSON values carefully.</p>
      <ConfigEditor table="app_config" rpc="admin_set_config" rows={data ?? []} />
    </Shell>
  );
}
