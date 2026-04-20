import { requireAdmin } from "@/lib/auth";
import { serverClient } from "@/lib/supabase-server";
import Shell from "@/components/Shell";
import ConfigEditor from "../ConfigEditor";

export const dynamic = "force-dynamic";

export default async function UiPage() {
  const user = await requireAdmin();
  const sb = await serverClient();
  const { data } = await sb.from("ui_config").select("*").order("key");
  return (
    <Shell email={user.email ?? ""}>
      <h1 className="text-2xl font-semibold mb-1">UI Config</h1>
      <p className="text-muted text-sm mb-6">Remote UI customization — free game list, featured games, banners, theme tokens.</p>
      <ConfigEditor table="ui_config" rpc="admin_set_ui_config" rows={data ?? []} />
    </Shell>
  );
}
