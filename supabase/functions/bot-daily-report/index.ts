import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
const env=(k:string)=>Deno.env.get(k)??"";
const fmt=(n:number)=>(Number(n)||0).toLocaleString("en-US");
function toJalali(gy:number,gm:number,gd:number){const g=[0,31,59,90,120,151,181,212,243,273,304,334];let jy=gy<=1600?0:979;gy-=gy<=1600?621:1600;const gy2=gm>2?gy+1:gy;let days=365*gy+Math.floor((gy2+3)/4)-Math.floor((gy2+99)/100)+Math.floor((gy2+399)/400)-80+gd+g[gm-1];jy+=33*Math.floor(days/12053);days%=12053;jy+=4*Math.floor(days/1461);days%=1461;if(days>365){jy+=Math.floor((days-1)/365);days=(days-1)%365;}const jm=days<186?1+Math.floor(days/31):7+Math.floor((days-186)/30);const jd=1+(days<186?days%31:(days-186)%30);return `${jy}/${String(jm).padStart(2,"0")}/${String(jd).padStart(2,"0")}`;}

Deno.serve(async (req)=>{
  const supa=createClient(env("SUPABASE_URL"),env("SUPABASE_SERVICE_ROLE_KEY"),{auth:{persistSession:false}});
  const { data: cfg } = await supa.from("bot_config").select("*").eq("id","main").single();
  if(!cfg) return new Response("no config",{status:500});
  const url=new URL(req.url);
  if(url.searchParams.get("key")!==cfg.webhook_secret) return new Response("unauthorized",{status:401});
  const num=(v:any)=>Number(v)||0;

  // yesterday (Gregorian)
  const y=new Date(Date.now()-864e5); const day=y.toISOString().slice(0,10);
  const jday=toJalali(y.getFullYear(),y.getMonth()+1,y.getDate());

  const {data:dr}=await supa.from("daily_reports").select("production,waste,line").eq("date",day);
  const prod=(dr||[]).reduce((s:number,r:any)=>s+num(r.production),0), waste=(dr||[]).reduce((s:number,r:any)=>s+num(r.waste),0);
  const byLine:any={}; (dr||[]).forEach((r:any)=>{const l=r.line||"نامشخص";byLine[l]=(byLine[l]||0)+num(r.production);});
  const {data:st}=await supa.from("production_stops").select("duration_min").eq("stop_date",day);
  const stopMin=(st||[]).reduce((s:number,r:any)=>s+num(r.duration_min),0);
  const {data:inv}=await supa.from("invoices").select("total").eq("invoice_date",day);
  const sales=(inv||[]).reduce((s:number,r:any)=>s+num(r.total),0);
  const today=new Date().toISOString().slice(0,10);
  const {data:chk}=await supa.from("treasury_checks").select("amount,due_date,status,direction").in("status",["in_hand","deposited"]);
  const dueToday=(chk||[]).filter((c:any)=>c.due_date===today);
  const overdue=(chk||[]).filter((c:any)=>c.due_date&&c.due_date<today);

  const lineTxt=Object.keys(byLine).length?"\n"+Object.entries(byLine).map(([l,v])=>`   • ${l}: ${fmt(v as number)} kg`).join("\n"):"";
  let text=`📊 گزارش روزانه — ${jday}\n\n🏭 تولید: ${fmt(prod)} kg${lineTxt}\n🗑 ضایعات: ${fmt(waste)} kg\n⛔ توقف: ${fmt(stopMin)} دقیقه\n💰 فروش (فاکتور): ${fmt(sales)} ریال`;
  if(dueToday.length) text+=`\n🧾 چک سررسید امروز: ${dueToday.length} فقره (${fmt(dueToday.reduce((s:number,c:any)=>s+num(c.amount),0))} ریال)`;
  if(overdue.length) text+=`\n⚠️ چک معوق (سررسید گذشته): ${overdue.length} فقره`;
  if(!prod&&!sales&&!(dr||[]).length) text+=`\n\n(دیروز داده‌ای ثبت نشده بود)`;

  const {data:users}=await supa.from("bot_users").select("telegram_chat_id").eq("active",true);
  let sent=0;
  for(const u of (users||[])){
    const r=await fetch(`https://api.telegram.org/bot${cfg.telegram_token}/sendMessage`,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({chat_id:u.telegram_chat_id,text})});
    if(r.ok) sent++;
  }
  return new Response(JSON.stringify({ok:true,sent,recipients:(users||[]).length}),{headers:{"Content-Type":"application/json"}});
});
