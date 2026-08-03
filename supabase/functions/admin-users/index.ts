import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const FAKE_EMAIL_DOMAIN = "@sanatsabz.local";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  // Identify the caller from their JWT and confirm they are an active admin
  const authHeader = req.headers.get("Authorization") ?? "";
  const callerClient = createClient(url, anonKey, { global: { headers: { Authorization: authHeader } } });
  const { data: userData, error: userErr } = await callerClient.auth.getUser();
  if (userErr || !userData?.user) return json({ error: "unauthorized" }, 401);

  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data: callerProfile } = await admin.from("profiles")
    .select("is_admin, active").eq("id", userData.user.id).single();
  if (!callerProfile?.is_admin || callerProfile.active === false) return json({ error: "forbidden" }, 403);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "invalid json" }, 400); }
  const action = String(body.action ?? "");

  if (action === "create") {
    const username = String(body.username ?? "").trim().toLowerCase();
    const password = String(body.password ?? "");
    const name = String(body.name ?? "").trim();
    if (!/^[a-z0-9._-]{3,32}$/.test(username)) return json({ error: "نام کاربری نامعتبر (فقط حروف لاتین/عدد، ۳ تا ۳۲ کاراکتر)" }, 400);
    if (password.length < 6) return json({ error: "رمز حداقل ۶ کاراکتر" }, 400);

    const email = username + FAKE_EMAIL_DOMAIN;
    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email, password, email_confirm: true,
    });
    if (createErr) return json({ error: createErr.message }, 400);

    const profile = {
      id: created.user.id,
      username,
      name: name || username,
      role_label: String(body.roleLabel ?? ""),
      role: String(body.role ?? "") || null,
      is_admin: body.isAdmin === true,
      perms: (body.perms && typeof body.perms === "object") ? body.perms : {},
      active: true,
    };
    const { error: profErr } = await admin.from("profiles").upsert(profile, { onConflict: "id" });
    if (profErr) {
      await admin.auth.admin.deleteUser(created.user.id);
      return json({ error: "profile insert failed: " + profErr.message }, 500);
    }
    return json({ ok: true, id: created.user.id });
  }

  if (action === "reset_password") {
    const targetId = String(body.userId ?? "");
    const password = String(body.password ?? "");
    if (!targetId) return json({ error: "userId required" }, 400);
    if (password.length < 6) return json({ error: "رمز حداقل ۶ کاراکتر" }, 400);
    const { error } = await admin.auth.admin.updateUserById(targetId, { password });
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true });
  }

  if (action === "set_active") {
    const targetId = String(body.userId ?? "");
    const active = body.active === true;
    if (!targetId) return json({ error: "userId required" }, 400);
    if (targetId === userData.user.id && !active) return json({ error: "نمی‌توانی حساب خودت را غیرفعال کنی" }, 400);
    const { error } = await admin.from("profiles").update({ active }).eq("id", targetId);
    if (error) return json({ error: error.message }, 400);
    // ban/unban at auth level so a deactivated user cannot sign in at all
    await admin.auth.admin.updateUserById(targetId, { ban_duration: active ? "none" : "87600h" });
    return json({ ok: true });
  }

  return json({ error: "unknown action" }, 400);
});
