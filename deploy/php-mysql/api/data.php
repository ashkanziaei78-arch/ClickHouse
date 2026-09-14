<?php
/**
 * خواندن و نوشتن داده‌ها — جایگزین REST API سوپابیس
 *
 * هر درخواست قبل از رسیدن به دیتابیس از check_access() رد می‌شود،
 * یعنی همان قوانینی که قبلا RLS اجرا می‌کرد.
 */
declare(strict_types=1);
require_once __DIR__ . '/lib.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') fail('روش درخواست نامعتبر است', 405);

$u     = require_login();
$in    = body_json();
$op    = (string)($in['op'] ?? '');
$table = (string)($in['table'] ?? '');

// جدول باید در فهرست شناخته‌شده باشد (جلوگیری از دسترسی به جدول‌های داخلی)
if (!isset(policies()[$table])) fail('جدول نامعتبر است: ' . $table, 400);

$cols = table_columns($table);
if (!$cols) fail('جدول در دیتابیس پیدا نشد: ' . $table, 400);

// اگر کلاینت کلید نفرستاد، کلید اصلی واقعی جدول استفاده می‌شود
// (بعضی جدول‌ها مثل org_roles و settings ستون id ندارند)
$keyField = (string)($in['keyField'] ?? '');
if ($keyField === '' || !isset($cols[$keyField])) {
    $keyField = table_pk($table);
}
if (!isset($cols[$keyField])) fail('ستون کلید نامعتبر است', 400);

/** مقدار را برای ذخیره در MySQL آماده می‌کند */
function prep_value(string $type, mixed $v): mixed {
    if ($v === null || $v === '') {
        return null;
    }
    if ($type === 'json') {
        // کلاینت مقدار را به‌صورت نوع واقعی جاوااسکریپت می‌فرستد
        // (رشته، عدد، آرایه یا شیء) — پس همیشه باید JSON شود.
        return json_encode($v, JSON_UNESCAPED_UNICODE);
    }
    if ($type === 'tinyint') return $v ? 1 : 0;
    if ($type === 'datetime') {
        if (is_string($v) && $v !== '') {
            $ts = strtotime($v);
            return $ts ? gmdate('Y-m-d H:i:s', $ts) : null;
        }
        return null;
    }
    if (is_array($v)) return json_encode($v, JSON_UNESCAPED_UNICODE);
    return $v;
}

switch ($op) {

// ------------------------------------------------------------- خواندن همه
case 'getAll': {
    $acc = check_access($table, 'SELECT');
    if (!$acc['ok']) json_out(['rows' => []]);   // مثل RLS: بدون دسترسی = خالی

    $sql  = "SELECT * FROM `$table`";
    $args = [];
    if (!empty($acc['filter'])) {
        $sql .= ' WHERE ' . $acc['filter']['sql'];
        $args = $acc['filter']['args'];
    }
    try {
        $st = db()->prepare($sql);
        $st->execute($args);
        $rows = $st->fetchAll();
    } catch (Throwable $e) {
        fail_internal("getAll $table: " . $e->getMessage());
    }

    $out = [];
    foreach ($rows as $r) {
        foreach ($r as $k => $v) {
            if (($cols[$k] ?? '') === 'json' && is_string($v)) {
                $r[$k] = json_decode($v, true);
            } elseif (($cols[$k] ?? '') === 'tinyint') {
                $r[$k] = (bool)$v;
            }
        }
        $out[] = row_to_camel($r);
    }
    json_out(['rows' => $out]);
}

// ------------------------------------------------------- درج یا به‌روزرسانی
case 'put': {
    $obj = (array)($in['row'] ?? []);
    if (!$obj) fail('داده‌ای برای ذخیره ارسال نشده');

    // تبدیل camelCase به snake_case و حذف ستون‌های ناشناخته
    $row = [];
    foreach ($obj as $k => $v) {
        $sk = to_snake((string)$k);
        if (isset($cols[$sk])) $row[$sk] = $v;
    }

    $keyVal   = $row[$keyField] ?? null;
    $isUpdate = false;
    if ($keyVal !== null && $keyVal !== '') {
        $chk = db()->prepare("SELECT 1 FROM `$table` WHERE `$keyField` = ?");
        $chk->execute([$keyVal]);
        $isUpdate = (bool)$chk->fetchColumn();
    }

    $acc = check_access($table, $isUpdate ? 'UPDATE' : 'INSERT');
    if (!$acc['ok']) {
        fail($acc['reason'] ?? 'برای این کار دسترسی ندارید', 403);
    }

    // مقادیری که سرور تحمیل می‌کند (به کلاینت اعتماد نمی‌شود)
    foreach (($acc['force'] ?? []) as $c => $v) {
        if (isset($cols[$c])) $row[$c] = $v;
    }

    if ($isUpdate) {
        // اگر قانون، فیلتر سطری دارد، فقط سطرهای مجاز به‌روز می‌شوند
        $sets = [];
        $args = [];
        foreach ($row as $c => $v) {
            if ($c === $keyField) continue;
            $sets[] = "`$c` = ?";
            $args[] = prep_value($cols[$c], $v);
        }
        if (!$sets) json_out(['row' => $obj]);

        $sql = "UPDATE `$table` SET " . implode(', ', $sets) . " WHERE `$keyField` = ?";
        $args[] = $keyVal;
        if (!empty($acc['filter'])) {
            $sql .= ' AND ' . $acc['filter']['sql'];
            $args = array_merge($args, $acc['filter']['args']);
        }
        try {
            $st = db()->prepare($sql);
            $st->execute($args);
            if ($st->rowCount() === 0) {
                // یا چیزی عوض نشده، یا سطر خارج از دسترسی کاربر بوده
                $own = db()->prepare("SELECT 1 FROM `$table` WHERE `$keyField` = ?"
                    . (!empty($acc['filter']) ? ' AND ' . $acc['filter']['sql'] : ''));
                $own->execute(array_merge([$keyVal], $acc['filter']['args'] ?? []));
                if (!$own->fetchColumn()) fail('اجازه‌ی ویرایش این رکورد را ندارید', 403);
            }
        } catch (Throwable $e) {
            fail_internal("update $table: " . $e->getMessage());
        }
    } else {
        // شناسه: اگر نبود یا فرمتش UUID نبود، سرور می‌سازد
        if ($keyField === 'id' && (empty($row['id']) || !is_uuid($row['id']))) {
            $row['id'] = uuid4();
        }
        // ستون‌های زمان که در MySQL دیفالت تابعی ندارند
        if (isset($cols['created_at']) && empty($row['created_at'])) {
            $row['created_at'] = gmdate('Y-m-d H:i:s');
        }
        foreach (['req_date' => 'Y-m-d', 'bom_date' => 'Y-m-d'] as $c => $fmt) {
            if (isset($cols[$c]) && empty($row[$c])) $row[$c] = gmdate($fmt);
        }

        $names = array_keys($row);
        $ph    = implode(',', array_fill(0, count($names), '?'));
        $args  = [];
        foreach ($names as $c) $args[] = prep_value($cols[$c], $row[$c]);

        $sql = "INSERT INTO `$table` (" . implode(',', array_map(fn($c) => "`$c`", $names))
             . ") VALUES ($ph)";
        // برای settings و جدول‌های کلید-مقداری، درج تکراری = به‌روزرسانی
        $upd = [];
        foreach ($names as $c) {
            if ($c !== $keyField) $upd[] = "`$c` = VALUES(`$c`)";
        }
        if ($upd) $sql .= ' ON DUPLICATE KEY UPDATE ' . implode(', ', $upd);

        try {
            db()->prepare($sql)->execute($args);
        } catch (Throwable $e) {
            fail_internal("insert $table: " . $e->getMessage());
        }
        $obj['id'] = $row['id'] ?? ($obj['id'] ?? null);
        notify_on_submit($table, $row);
    }

    json_out(['row' => $obj]);
}

// ------------------------------------------------------------------- حذف
case 'del': {
    $id  = $in['id'] ?? null;
    if ($id === null || $id === '') fail('شناسه ارسال نشده');
    $acc = check_access($table, 'DELETE');
    if (!$acc['ok']) fail($acc['reason'] ?? 'اجازه‌ی حذف ندارید', 403);

    $sql  = "DELETE FROM `$table` WHERE `$keyField` = ?";
    $args = [$id];
    if (!empty($acc['filter'])) {
        $sql .= ' AND ' . $acc['filter']['sql'];
        $args = array_merge($args, $acc['filter']['args']);
    }
    try {
        $st = db()->prepare($sql);
        $st->execute($args);
        if ($st->rowCount() === 0) fail('رکورد پیدا نشد یا اجازه‌ی حذفش را ندارید', 403);
    } catch (Throwable $e) {
        fail_internal("delete $table: " . $e->getMessage());
    }
    json_out(['ok' => true]);
}

}

fail('عملیات نامعتبر است', 400);


/** معادل تریگرهای اعلان در پستگرس */
function notify_on_submit(string $table, array $row): void {
    $status = (string)($row['status'] ?? '');
    $map = [
        'daily_reports'       => ['📈 گزارش تولید جدید', 'یک گزارش تولید در انتظار تایید ثبت شد'],
        'sheeter_reports'     => ['✂️ گزارش شیتر جدید', 'یک گزارش شیتر در انتظار تایید ثبت شد'],
        'packaging_reports'   => ['📦 گزارش بسته‌بندی جدید', 'یک گزارش بسته‌بندی در انتظار تایید ثبت شد'],
        'custom_form_records' => ['📄 فرم جدید در انتظار تایید', 'یک رکورد فرم‌ساز ثبت شد'],
        'hr_leaves'           => ['🌴 درخواست مرخصی/ماموریت جدید', 'در انتظار تایید'],
    ];
    if (isset($map[$table]) && $status === 'submitted') {
        add_notification(null, $map[$table][0], $map[$table][1], 'submit');
        return;
    }
    if ($table === 'goods_requests') {
        add_notification(null, '📝 درخواست کالای جدید',
            'واحد: ' . (string)($row['department'] ?? '—'), 'submit');
        return;
    }
    if ($table === 'letters') {
        add_notification((string)($row['recipient_id'] ?? '') ?: null, '📨 نامه داخلی جدید',
            'موضوع: ' . (string)($row['subject'] ?? ''), 'letter');
    }
}
