import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const TABLES = [
  'profiles','papers','formulas','pack_presets','inventory','suppliers','rawmats',
  'purchase_orders','bom_history','daily_reports','sheeter_reports','production_stops','activity_log','settings',
  'customers','invoices','workflow_templates','approvals','goods_requests','letters',
  'custom_forms','custom_form_records','form_templates',
  'hr_employees','hr_contracts','hr_shifts','hr_attendance','hr_leaves','hr_payroll_items','hr_payslips',
  'acc_accounts','acc_vouchers','acc_voucher_lines',
  'treasury_accounts','treasury_checks','treasury_transactions',
  'sales_orders','sales_deliveries'
];
const RETENTION_DAYS = 30;

Deno.serve(async (_req: Request) => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const backup: Record<string, unknown> = { generated_at: new Date().toISOString() };
    for (const table of TABLES) {
      const { data, error } = await supabase.from(table).select('*');
      backup[table] = error ? { error: error.message } : data;
    }

    const dateStr = new Date().toISOString().slice(0,10);
    const fileName = `backup-${dateStr}.json`;
    const content = JSON.stringify(backup, null, 2);

    const { error: uploadError } = await supabase.storage
      .from('backups')
      .upload(fileName, new Blob([content], { type: 'application/json' }), { upsert: true });
    if (uploadError) {
      return new Response(JSON.stringify({ success: false, error: uploadError.message }), {
        headers: { 'Content-Type': 'application/json' }, status: 500
      });
    }

    let removed = 0;
    const { data: files } = await supabase.storage.from('backups').list('', { limit: 1000 });
    if (files) {
      const cutoff = Date.now() - RETENTION_DAYS*24*3600*1000;
      const old = files.filter(f => f.name.startsWith('backup-') && new Date(f.created_at).getTime() < cutoff).map(f => f.name);
      if (old.length) { await supabase.storage.from('backups').remove(old); removed = old.length; }
    }

    return new Response(JSON.stringify({ success: true, file: fileName, removed }), {
      headers: { 'Content-Type': 'application/json' }
    });
  } catch (e) {
    return new Response(JSON.stringify({ success: false, error: String(e) }), {
      headers: { 'Content-Type': 'application/json' }, status: 500
    });
  }
});
