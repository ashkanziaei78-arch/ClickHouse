<?php
/**
 * تشخیص تغییر داده‌ها — جایگزین Realtime سوپابیس
 *
 * روی هاست اشتراکی WebSocket نداریم، پس سامانه هر چند ثانیه یک‌بار
 * این فایل را صدا می‌زند. برای هر جدول یک «اثر انگشت» سبک برمی‌گردد
 * (تعداد ردیف + آخرین زمان تغییر). اگر عوض شده باشد، سامانه داده‌ها
 * را تازه می‌کند.
 *
 * عمدا سبک است: فقط COUNT و MAX، بدون خواندن محتوای ردیف‌ها.
 */
declare(strict_types=1);
require_once __DIR__ . '/lib.php';

require_login();

$watch = ['daily_reports', 'goods_requests', 'letters', 'custom_form_records',
          'packaging_reports', 'sheeter_reports', 'hr_leaves', 'notifications'];

$out = [];
foreach ($watch as $t) {
    try {
        $cols = table_columns($t);
        $stampCol = isset($cols['created_at']) ? 'created_at' : null;
        $sql = $stampCol
            ? "SELECT COUNT(*) c, COALESCE(MAX(`$stampCol`),'') m FROM `$t`"
            : "SELECT COUNT(*) c, '' m FROM `$t`";
        $r = db()->query($sql)->fetch();
        $out[$t] = $r['c'] . ':' . $r['m'];
    } catch (Throwable $e) {
        $out[$t] = 'err';
    }
}

json_out(['stamps' => $out, 'server_time' => gmdate('c')]);
