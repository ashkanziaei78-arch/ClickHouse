<?php
/**
 * گردش کار تأیید — معادل توابع SECURITY DEFINER در پستگرس
 *
 * چرا اینجا و نه در دیتابیس؟ چون MySQL معادل امنی برای آن توابع ندارد.
 * منطق دقیقا همان است: فقط تأییدکننده‌ی مرحله‌ی جاری (یا مدیر سیستم،
 * یا مدیرعامل برای اسناد ارجاع‌شده) می‌تواند تأیید یا رد کند.
 */
declare(strict_types=1);
require_once __DIR__ . '/lib.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') fail('روش درخواست نامعتبر است', 405);

$u      = require_login();
$in     = body_json();
$fn     = (string)($in['fn'] ?? '');
$params = (array)($in['params'] ?? []);

/** ماژول‌های دارای گردش کار: نام تابع → [جدول، نام ماژول در workflow_templates] */
const WF = [
    'daily_report'      => ['daily_reports',       'daily_reports'],
    'sheeter_report'    => ['sheeter_reports',     'sheeter_reports'],
    'packaging_report'  => ['packaging_reports',   'packaging'],
    'hr_leave'          => ['hr_leaves',           'hr_leaves'],
    'custom_record'     => ['custom_form_records', null],   // ماژول از slug فرم
];

function wf_steps(string $module): array {
    $st = db()->prepare(
        'SELECT step_order, approver_role, step_label FROM workflow_templates
         WHERE module = ? ORDER BY step_order');
    $st->execute([$module]);
    return $st->fetchAll();
}

function fetch_row(string $table, string $id): ?array {
    $st = db()->prepare("SELECT * FROM `$table` WHERE id = ?");
    $st->execute([$id]);
    return $st->fetch() ?: null;
}

/** آیا کاربر می‌تواند روی مرحله‌ی جاری این سند تصمیم بگیرد؟ */
function can_decide(array $rec, string $module, array $u): bool {
    if (is_admin($u)) return true;
    $steps = wf_steps($module);
    $cur   = (int)($rec['current_step'] ?? 0);
    foreach ($steps as $s) {
        if ((int)$s['step_order'] === $cur) {
            if (($u['role'] ?? '') === $s['approver_role']) return true;
            break;
        }
    }
    // سند معطل‌مانده که به مدیرعامل ارجاع شده
    if (!empty($rec['escalated']) && ($u['role'] ?? '') === 'ceo') return true;
    return false;
}

function record_approval(string $module, string $id, int $step, string $action, ?string $note): void {
    $u = current_user();
    db()->prepare(
        'INSERT INTO approvals (id, module, record_id, step_order, approver_id, action, note, created_at)
         VALUES (?,?,?,?,?,?,?,UTC_TIMESTAMP())')
        ->execute([uuid4(), $module, $id, $step, $u['id'] ?? null, $action, $note]);
}

/** تأیید عمومی: یک مرحله جلو می‌برد، یا اگر مرحله‌ی آخر بود نهایی می‌کند */
function do_approve(string $table, string $module, string $id, array $u): array {
    $rec = fetch_row($table, $id);
    if (!$rec) return ['error' => 'رکورد پیدا نشد'];
    if (($rec['status'] ?? '') !== 'submitted') {
        return ['error' => 'این رکورد در وضعیت قابل تایید نیست'];
    }
    if (!can_decide($rec, $module, $u)) {
        return ['error' => 'اجازه تایید این مرحله را ندارید'];
    }

    $cur   = (int)($rec['current_step'] ?? 0);
    $steps = wf_steps($module);
    $next  = null;
    foreach ($steps as $s) {
        if ((int)$s['step_order'] === $cur + 1) { $next = $s; break; }
    }

    db()->beginTransaction();
    try {
        record_approval($module, $id, $cur, 'approved', null);
        if ($next) {
            db()->prepare("UPDATE `$table` SET current_step = ?, escalated = 0 WHERE id = ?")
                ->execute([(int)$next['step_order'], $id]);
        } else {
            db()->prepare("UPDATE `$table` SET status = 'approved', current_step = 0 WHERE id = ?")
                ->execute([$id]);
        }
        db()->commit();
    } catch (Throwable $e) {
        db()->rollBack();
        fail_internal("approve $table: " . $e->getMessage());
    }
    log_activity('تایید سند در ماژول ' . $module, '✅');
    return ['success' => true];
}

function do_reject(string $table, string $module, string $id, ?string $note, array $u): array {
    $rec = fetch_row($table, $id);
    if (!$rec) return ['error' => 'رکورد پیدا نشد'];
    if (($rec['status'] ?? '') !== 'submitted') {
        return ['error' => 'این رکورد در وضعیت قابل رد نیست'];
    }
    if (!can_decide($rec, $module, $u)) {
        return ['error' => 'اجازه رد این مرحله را ندارید'];
    }
    db()->beginTransaction();
    try {
        record_approval($module, $id, (int)($rec['current_step'] ?? 0), 'rejected', $note);
        db()->prepare("UPDATE `$table` SET status = 'rejected', rejection_note = ? WHERE id = ?")
            ->execute([$note, $id]);
        db()->commit();
    } catch (Throwable $e) {
        db()->rollBack();
        fail_internal("reject $table: " . $e->getMessage());
    }
    log_activity('رد سند در ماژول ' . $module, '❌');
    return ['success' => true];
}

function do_resubmit(string $table, string $module, string $id, array $u): array {
    $rec = fetch_row($table, $id);
    if (!$rec) return ['error' => 'رکورد پیدا نشد'];
    if (($rec['status'] ?? '') !== 'rejected') {
        return ['error' => 'فقط رکورد ردشده قابل ارسال دوباره است'];
    }
    if (($rec['submitted_by'] ?? '') !== $u['id'] && !is_admin($u)) {
        return ['error' => 'فقط ثبت‌کننده اصلی می‌تواند دوباره ارسال کند'];
    }
    $steps = wf_steps($module);
    $first = $steps[0]['step_order'] ?? 0;
    db()->prepare(
        "UPDATE `$table` SET status = 'submitted', current_step = ?, escalated = 0,
         rejection_note = NULL WHERE id = ?")
        ->execute([(int)$first, $id]);
    log_activity('ارسال دوباره سند در ماژول ' . $module, '🔁');
    return ['success' => true];
}

$id   = (string)($params['p_id'] ?? '');
$note = isset($params['p_note']) ? (string)$params['p_note'] : null;

// --------------------------------------------------------------- مسیردهی
try {
switch ($fn) {

case 'approve_daily_report':     json_out(do_approve('daily_reports','daily_reports',$id,$u));
case 'reject_daily_report':      json_out(do_reject ('daily_reports','daily_reports',$id,$note,$u));
case 'resubmit_daily_report':    json_out(do_resubmit('daily_reports','daily_reports',$id,$u));

case 'approve_sheeter_report':   json_out(do_approve('sheeter_reports','sheeter_reports',$id,$u));
case 'reject_sheeter_report':    json_out(do_reject ('sheeter_reports','sheeter_reports',$id,$note,$u));
case 'resubmit_sheeter_report':  json_out(do_resubmit('sheeter_reports','sheeter_reports',$id,$u));

case 'approve_packaging_report': json_out(do_approve('packaging_reports','packaging',$id,$u));
case 'reject_packaging_report':  json_out(do_reject ('packaging_reports','packaging',$id,$note,$u));
case 'resubmit_packaging_report':json_out(do_resubmit('packaging_reports','packaging',$id,$u));

case 'approve_hr_leave':         json_out(do_approve('hr_leaves','hr_leaves',$id,$u));
case 'reject_hr_leave':          json_out(do_reject ('hr_leaves','hr_leaves',$id,$note,$u));

// ------------------------------------------------- فرم‌های ساخته‌شده کاربر
case 'approve_custom_record':
case 'reject_custom_record': {
    $rec = fetch_row('custom_form_records', $id);
    if (!$rec) json_out(['error' => 'رکورد پیدا نشد']);
    $f = db()->prepare('SELECT slug FROM custom_forms WHERE id = ?');
    $f->execute([$rec['form_id']]);
    $slug = (string)($f->fetchColumn() ?: '');
    if ($slug === '') json_out(['error' => 'فرم پیدا نشد']);
    json_out($fn === 'approve_custom_record'
        ? do_approve('custom_form_records', $slug, $id, $u)
        : do_reject ('custom_form_records', $slug, $id, $note, $u));
}

case 'submit_custom_form': {
    $formId = (string)($params['p_form_id'] ?? '');
    $data   = $params['p_data'] ?? [];
    $f = db()->prepare('SELECT * FROM custom_forms WHERE id = ? AND active = 1');
    $f->execute([$formId]);
    $form = $f->fetch();
    if (!$form) json_out(['error' => 'فرم پیدا نشد یا غیرفعال است']);

    $steps  = wf_steps((string)$form['slug']);
    $first  = $steps[0]['step_order'] ?? 0;
    $recId  = uuid4();
    $status = $steps ? 'submitted' : 'approved';

    db()->prepare(
        'INSERT INTO custom_form_records (id, form_id, data, status, current_step, submitted_by, created_at, escalated)
         VALUES (?,?,?,?,?,?,UTC_TIMESTAMP(),0)')
        ->execute([$recId, $formId, json_encode($data, JSON_UNESCAPED_UNICODE),
                   $status, (int)$first, $u['id']]);

    if ($status === 'submitted') {
        add_notification(null, '📄 فرم جدید در انتظار تایید', 'یک رکورد فرم‌ساز ثبت شد', 'submit');
    }
    log_activity('ثبت فرم: ' . (string)$form['title'], '📄');
    json_out(['success' => true, 'id' => $recId]);
}

// --------------------------------------------------------- درخواست کالا
case 'approve_goods_request_warehouse': {
    $rec = fetch_row('goods_requests', $id);
    if (!$rec) json_out(['error' => 'رکورد پیدا نشد']);
    if (($rec['status'] ?? '') !== 'pending_warehouse') {
        json_out(['error' => 'این درخواست در وضعیت قابل تایید انبار نیست']);
    }
    $ok = is_admin($u)
        || !empty($u['perms']['approve_goods_warehouse'])
        || (!empty($rec['escalated']) && ($u['role'] ?? '') === 'ceo');
    if (!$ok) json_out(['error' => 'اجازه تایید انبار را ندارید']);

    db()->prepare(
        "UPDATE goods_requests SET status = 'pending_receiver', warehouse_approver_id = ?,
         warehouse_approved_at = UTC_TIMESTAMP(), escalated = 0 WHERE id = ?")
        ->execute([$u['id'], $id]);
    log_activity('تایید انبار برای درخواست کالا', '✅');
    json_out(['success' => true]);
}

case 'reject_goods_request': {
    $rec = fetch_row('goods_requests', $id);
    if (!$rec) json_out(['error' => 'رکورد پیدا نشد']);
    $ok = is_admin($u) || !empty($u['perms']['approve_goods_warehouse']);
    if (!$ok) json_out(['error' => 'اجازه رد ندارید']);
    db()->prepare("UPDATE goods_requests SET status = 'rejected', rejection_note = ? WHERE id = ?")
        ->execute([$note, $id]);
    log_activity('رد درخواست کالا', '❌');
    json_out(['success' => true]);
}

case 'confirm_goods_request_receipt': {
    $rec = fetch_row('goods_requests', $id);
    if (!$rec) json_out(['error' => 'رکورد پیدا نشد']);
    if (($rec['status'] ?? '') !== 'pending_receiver') {
        json_out(['error' => 'این درخواست در وضعیت قابل تحویل نیست']);
    }
    if (($rec['receiver_id'] ?? '') !== $u['id']) {
        json_out(['error' => 'فقط تحویل‌گیرنده تعیین‌شده می‌تواند تایید کند']);
    }
    db()->prepare("UPDATE goods_requests SET status = 'delivered',
                   receiver_confirmed_at = UTC_TIMESTAMP() WHERE id = ?")->execute([$id]);
    log_activity('تایید دریافت کالا', '📦');
    json_out(['success' => true]);
}

// ----------------------------------------------------------------- نامه
case 'acknowledge_letter': {
    $rec = fetch_row('letters', $id);
    if (!$rec) json_out(['error' => 'نامه پیدا نشد']);
    if (($rec['recipient_id'] ?? '') !== $u['id']) {
        json_out(['error' => 'فقط مخاطب نامه می‌تواند تایید کند']);
    }
    db()->prepare("UPDATE letters SET status = 'acknowledged', acknowledged_at = UTC_TIMESTAMP(),
                   margin_note = COALESCE(?, margin_note) WHERE id = ?")
        ->execute([$params['p_margin_note'] ?? null, $id]);
    log_activity('تایید دریافت نامه', '✅');
    json_out(['success' => true]);
}

// ------------------------------------------------------------- حسابداری
case 'post_voucher': {
    if (!has_page_perm(['acc_vouchers'], 'accounting', 'edit', $u)) {
        json_out(['error' => 'دسترسی ندارید']);
    }
    $v = fetch_row('acc_vouchers', $id);
    if (!$v) json_out(['error' => 'سند پیدا نشد']);
    $s = db()->prepare('SELECT COALESCE(SUM(debit),0) d, COALESCE(SUM(credit),0) c
                        FROM acc_voucher_lines WHERE voucher_id = ?');
    $s->execute([$id]);
    $t = $s->fetch();
    if (round((float)$t['d'], 2) !== round((float)$t['c'], 2)) {
        json_out(['error' => 'سند تراز نیست: بدهکار=' . $t['d'] . ' بستانکار=' . $t['c']]);
    }
    if ((float)$t['d'] == 0.0) json_out(['error' => 'سند بدون مبلغ است']);
    db()->prepare("UPDATE acc_vouchers SET status = 'posted', posted_by = ?,
                   posted_at = UTC_TIMESTAMP() WHERE id = ?")->execute([$u['id'], $id]);
    log_activity('ثبت سند حسابداری', '📒');
    json_out(['success' => true]);
}

case 'unpost_voucher': {
    if (!has_page_perm(['acc_vouchers'], 'accounting', 'edit', $u)) {
        json_out(['error' => 'دسترسی ندارید']);
    }
    db()->prepare("UPDATE acc_vouchers SET status = 'draft', posted_by = NULL,
                   posted_at = NULL WHERE id = ?")->execute([$id]);
    log_activity('برگشت سند حسابداری', '↩️');
    json_out(['success' => true]);
}

// --------------------------------------------------------- گردش کارها
case 'set_module_workflow':
case 'set_custom_form_workflow': {
    if (!has_perm('management', 'edit', $u)) {
        json_out(['error' => 'فقط مدیر سیستم می‌تواند گردش کار را تغییر دهد']);
    }
    $module = (string)($params['p_module'] ?? $params['p_slug'] ?? '');
    if (trim($module) === '') json_out(['error' => 'ماژول نامعتبر است']);
    $steps = $params['p_steps'] ?? [];
    if (is_string($steps)) $steps = json_decode($steps, true) ?: [];

    db()->beginTransaction();
    try {
        db()->prepare('DELETE FROM workflow_templates WHERE module = ?')->execute([$module]);
        $order = 0;
        foreach ((array)$steps as $s) {
            $role = (string)($s['approverRole'] ?? '');
            if ($role === '') continue;
            $order++;
            db()->prepare(
                'INSERT INTO workflow_templates (id, module, step_order, approver_role, step_label)
                 VALUES (?,?,?,?,?)')
                ->execute([uuid4(), $module, $order, $role,
                           ($s['stepLabel'] ?? '') !== '' ? $s['stepLabel'] : null]);
        }
        db()->commit();
    } catch (Throwable $e) {
        db()->rollBack();
        fail_internal('set workflow: ' . $e->getMessage());
    }
    log_activity('تغییر گردش کار ماژول ' . $module, '🔀');
    json_out(['success' => true, 'steps' => $order]);
}

// --------------------------------- ارجاع خودکار اسناد معطل (اجرا با Cron)
case 'run_escalations': {
    if (!is_admin($u)) json_out(['error' => 'دسترسی ندارید']);
    $tables = [
        'daily_reports'       => "status = 'submitted'",
        'sheeter_reports'     => "status = 'submitted'",
        'custom_form_records' => "status = 'submitted'",
        'hr_leaves'           => "status = 'submitted'",
        'goods_requests'      => "status IN ('pending_warehouse','pending_receiver')",
    ];
    $n = 0;
    foreach ($tables as $t => $cond) {
        $st = db()->prepare(
            "UPDATE `$t` SET escalated = 1
             WHERE $cond AND escalated = 0
               AND created_at < DATE_SUB(UTC_TIMESTAMP(), INTERVAL 24 HOUR)");
        $st->execute();
        $n += $st->rowCount();
    }
    json_out(['success' => true, 'escalated' => $n]);
}

}
} catch (Throwable $e) {
    fail_internal("rpc $fn: " . $e->getMessage());
}

fail('تابع ناشناخته: ' . $fn, 400);
