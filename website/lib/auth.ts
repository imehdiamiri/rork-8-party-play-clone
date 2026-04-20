import { serverClient } from "./supabase-server";
import { redirect } from "next/navigation";

export async function requireAdmin() {
  const sb = await serverClient();
  const { data: { user } } = await sb.auth.getUser();
  if (!user) redirect("/admin/login");

  const { data, error } = await sb.rpc("current_user_is_admin");
  if (error || !data) {
    await sb.auth.signOut();
    redirect("/admin/login?error=not_admin");
  }
  return user;
}
