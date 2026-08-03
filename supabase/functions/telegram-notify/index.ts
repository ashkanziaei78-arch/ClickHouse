import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
const env=(k:string)=>Deno.env.get(k)??"";

Deno.serve(async (req)=>{
  const supa=createClient(env("SUPABASE_URL"),env("SUPABASE_SERVICE_ROLE_KEY"),{auth:{persistSession:false}});
  const {data:cfg}=await supa.from("bot_config").select("*").eq("id","main").single();
  if(!cfg) return new Response("no config",{status:500});
  const url=new URL(req.url);
  if(url.searchParams.get("key")!==cfg.webhook_secret) return new Response("unauthorized",{status:401});
  let body:any={}; try{ body=await req.json(); }catch{}
  const id=body.id;
  if(!id) return new Response(JSON.stringify({ok:true,skipped:true}),{headers:{"Content-Type":"application/json"}});
  const {data:nt}=await supa.from("notifications").select("*").eq("id",id).eq("sent",false).maybeSingle();
  if(!nt) return new Response(JSON.stringify({ok:true,already:true}),{headers:{"Content-Type":"application/json"}});

  let recipients:string[]=[];
  if(nt.profile_id){
    const {data}=await supa.from("bot_users").select("telegram_chat_id").eq("active",true).eq("profile_id",nt.profile_id);
    recipients=(data||[]).map((r:any)=>r.telegram_chat_id);
  }else{
    const {data}=await supa.from("bot_users").select("telegram_chat_id").eq("active",true);
    recipients=(data||[]).map((r:any)=>r.telegram_chat_id);
  }
  const text=`🔔 <b>${(nt.title||"اعلان")}</b>${nt.body?"\n"+nt.body:""}`;
  let sent=0;
  for(const chat of recipients){
    const r=await fetch(`https://api.telegram.org/bot${cfg.telegram_token}/sendMessage`,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({chat_id:chat,text,parse_mode:"HTML"})});
    if(r.ok) sent++;
  }
  await supa.from("notifications").update({sent:true}).eq("id",id);
  return new Response(JSON.stringify({ok:true,sent,recipients:recipients.length}),{headers:{"Content-Type":"application/json"}});
});
