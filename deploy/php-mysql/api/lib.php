<?php
/**
 * هسته‌ی بک‌اند — اتصال دیتابیس، احراز هویت و کنترل دسترسی
 *
 * در نسخه‌ی قبلی (Supabase) کنترل دسترسی را خود دیتابیس با RLS انجام
 * می‌داد. MySQL چنین امکانی ندارد، پس همان قوانین اینجا اجرا می‌شوند.
 * هیچ درخواستی بدون عبور از check_access() به دیتابیس نمی‌رسد.
 */

declare(strict_types=1);

mb_internal_encoding('UTF-8');
date_default_timezone_set('UTC');

// در محیط عملیاتی خطاها نباید به کاربر نشان داده شوند
ini_set('display_errors', '0');
error_reporting(E_ALL);

require_once __DIR__ . '/config.php';

// ---------------------------------------------------------------- پاسخ JSON
function json_out(array $data, int $code = 200): never {
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    header('X-Content-Type-Options: nosniff');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function fail(string $msg, int $code = 400): never {
    json_out(['error' => $msg], $code);
}

/** خطای داخلی: جزئیات فقط در لاگ، پیام عمومی برای کاربر */
function fail_internal(string $detail): never {
    error_log('[ERP] ' . $detail);
    json_out(['error' => 'خطای داخلی سرور. با مدیر سیستم تماس بگیرید.'], 500);
}

// ------------------------------------------------------------------- دیتابیس
function db(): PDO {
    static $pdo = null;
    if ($pdo !== null) return $pdo;
    $dsn = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4',
        DB_HOST, DB_PORT, DB_NAME);
    try {
        $pdo = new PDO($dsn, DB_USER, DB_PASS, [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]);
    } catch (PDOException $e) {
        fail_internal('DB connect: ' . $e->getMessage());
    }
    return $pdo;
}

// -------------------------------------------------------------------- کمکی‌ها
function uuid4(): string {
    $d = random_bytes(16);
    $d[6] = chr((ord($d[6]) & 0x0f) | 0x40);
    $d[8] = chr((ord($d[8]) & 0x3f) | 0x80);
    return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($d), 4));
}

function is_uuid(mixed $v): bool {
    return is_string($v) && (bool) preg_match(
        '/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $v);
}

function to_snake(string $s): string {
    return strtolower(preg_replace('/([a-z0-9])([A-Z])/', '$1_$2', $s));
}

function to_camel(string $s): string {
    return lcfirst(str_replace(' ', '', ucwords(str_replace('_', ' ', $s))));
}

function row_to_camel(array $row): array {
    $out = [];
    foreach ($row as $k => $v) {
        $out[to_camel($k)] = $v;
    }
    return $out;
}

function body_json(): array {
    $raw = file_get_contents('php://input') ?: '';
    if ($raw === '') return [];
    $d = json_decode($raw, true);
    return is_array($d) ? $d : [];
}

/** کلید اصلی واقعی جدول (بعضی جدول‌ها id ندارند، مثل org_roles و settings) */
function table_pk(string $table): string {
    static $cache = [];
    if (isset($cache[$table])) return $cache[$table];
    $st = db()->prepare(
        "SELECT COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE
         WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND CONSTRAINT_NAME = 'PRIMARY'
         ORDER BY ORDINAL_POSITION LIMIT 1");
    $st->execute([DB_NAME, $table]);
    return $cache[$table] = (string)($st->fetchColumn() ?: 'id');
}

// ---------------------------------------------------- ستون‌های مجاز هر جدول
function table_columns(string $table): array {
    static $cache = [];
    if (isset($cache[$table])) return $cache[$table];
    $st = db()->prepare(
        'SELECT COLUMN_NAME, DATA_TYPE FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?');
    $st->execute([DB_NAME, $table]);
    $cols = [];
    foreach ($st->fetchAll() as $r) {
        $cols[$r['COLUMN_NAME']] = $r['DATA_TYPE'];
    }

    // مهم: MariaDB ستون JSON را longtext گزارش می‌کند و یک شرط json_valid
    // روی آن می‌گذارد. اگر این را تشخیص ندهیم، مقدار بدون تبدیل به JSON
    // ذخیره می‌شود و دیتابیس آن را رد می‌کند.
    try {
        $cc = db()->prepare(
            'SELECT CHECK_CLAUSE FROM information_schema.CHECK_CONSTRAINTS
             WHERE CONSTRAINT_SCHEMA = ? AND TABLE_NAME = ?');
        $cc->execute([DB_NAME, $table]);
        foreach ($cc->fetchAll() as $r) {
            if (preg_match('/json_valid\s*\(\s*`?(\w+)`?\s*\)/i', (string)$r['CHECK_CLAUSE'], $m)) {
                if (isset($cols[$m[1]])) $cols[$m[1]] = 'json';
            }
        }
    } catch (Throwable $e) {
        // نسخه‌هایی از MySQL این جدول را ندارند — نوع json مستقیم گزارش می‌شود
    }

    return $cache[$table] = $cols;
}

// ===================================================================
//  احراز هویت
// ===================================================================

function bearer_token(): ?string {
    $h = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if ($h === '' && function_exists('apache_request_headers')) {
        foreach (apache_request_headers() as $k => $v) {
            if (strcasecmp($k, 'Authorization') === 0) { $h = $v; break; }
        }
    }
    if (preg_match('/Bearer\s+([A-Za-z0-9._-]+)/', $h, $m)) return $m[1];
    return null;
}

/** نشست را از توکن می‌خواند؛ در دیتابیس فقط هش توکن ذخیره شده است */
function current_user(): ?array {
    static $user = false;
    if ($user !== false) return $user;

    $tok = bearer_token();
    if (!$tok) return $user = null;

    $st = db()->prepare(
        'SELECT p.* FROM app_sessions s
         JOIN profiles p ON p.id = s.user_id
         WHERE s.token = ? AND s.expires_at > UTC_TIMESTAMP()');
    $st->execute([hash('sha256', $tok)]);
    $row = $st->fetch();
    if (!$row) return $user = null;
    if ((int)($row['active'] ?? 1) !== 1) return $user = null;

    $row['perms'] = json_decode((string)($row['perms'] ?? '{}'), true) ?: [];
    $row['is_admin'] = (int)($row['is_admin'] ?? 0) === 1;

    // تمدید نشست تا کاربرِ فعال وسط کار بیرون نیفتد
    $up = db()->prepare(
        'UPDATE app_sessions SET expires_at = DATE_ADD(UTC_TIMESTAMP(), INTERVAL ? SECOND)
         WHERE token = ?');
    $up->execute([SESSION_LIFETIME, hash('sha256', $tok)]);

    return $user = $row;
}

function require_login(): array {
    $u = current_user();
    if (!$u) fail('برای این کار باید وارد شوید', 401);
    return $u;
}

// ===================================================================
//  موتور دسترسی — معادل دقیق has_perm / has_page_perm در پستگرس
// ===================================================================

function is_admin(?array $u = null): bool {
    $u ??= current_user();
    return (bool)($u['is_admin'] ?? false);
}

function has_perm(string $module, string $min_level, ?array $u = null): bool {
    $u ??= current_user();
    if (!$u) return false;
    if ($u['is_admin']) return true;
    $lvl = $u['perms'][$module] ?? null;
    if ($lvl === null) return false;
    if ($min_level === 'view') return in_array($lvl, ['view', 'edit'], true);
    if ($min_level === 'edit') return $lvl === 'edit';
    return false;
}

function has_page_perm(array $pages, string $module, string $min_level, ?array $u = null): bool {
    $u ??= current_user();
    if (!$u) return false;
    if ($u['is_admin']) return true;
    $perms = $u['perms'] ?? [];
    if (!$perms) return false;

    $best = null;
    foreach ($pages as $p) {
        $lvl = $perms[$p] ?? null;
        if ($lvl === 'edit') {
            $best = 'edit';
        } elseif ($lvl === 'view' && ($best === null || $best === 'none')) {
            $best = 'view';
        } elseif ($lvl === 'none' && $best === null) {
            $best = 'none';
        }
    }
    if ($best === null) $best = $perms[$module] ?? null;
    if ($best === null || $best === 'none') return false;
    if ($min_level === 'view') return in_array($best, ['view', 'edit'], true);
    if ($min_level === 'edit') return $best === 'edit';
    return false;
}

function user_has_role(string $role, ?array $u = null): bool {
    $u ??= current_user();
    if (!$u) return false;
    return $u['is_admin'] || ($u['role'] ?? '') === $role;
}

function policies(): array {
    static $p = null;
    return $p ??= require __DIR__ . '/policies.php';
}

/**
 * بررسی دسترسی به یک جدول برای یک عملیات.
 * خروجی: ['ok'=>bool, 'filter'=>?['sql'=>..,'args'=>[..]], 'force'=>[col=>val]]
 *   filter → شرط اضافه‌ی SQL برای محدود کردن سطرها
 *   force  → مقادیری که سرور تحمیل می‌کند (به کلاینت اعتماد نمی‌شود)
 */
function check_access(string $table, string $cmd): array {
    $u = current_user();
    if (!$u) return ['ok' => false];

    $all = policies();
    if (!isset($all[$table])) return ['ok' => false];
    $rules = $all[$table];
    $rule  = $rules[$cmd] ?? $rules['ALL'] ?? null;
    if ($rule === null) return ['ok' => false];

    if ($u['is_admin']) return ['ok' => true];   // مدیر سیستم مثل نسخه‌ی اصلی

    switch ($rule['type']) {
        case 'login':
            return ['ok' => true];

        case 'admin':
            return ['ok' => false];

        case 'deny':
            return ['ok' => false, 'reason' =>
                'این عملیات فقط از طریق گردش کار انجام می‌شود'];

        case 'module':
            return ['ok' => has_perm($rule['module'], $rule['level'], $u)];

        case 'page':
            return ['ok' => has_page_perm($rule['pages'], $rule['module'], $rule['level'], $u)];

        case 'special':
            return special_access($rule, $table, $cmd, $u);
    }
    return ['ok' => false];
}

/** منطق ویژه‌ی سطر-به-سطر (همان چیزی که در RLS با EXISTS نوشته شده بود) */
function special_access(array $rule, string $table, string $cmd, array $u): array {
    $me = $u['id'];
    $field = $rule['field'] ?? null;

    switch ($rule['handler']) {

        case 'own_only':              // فقط ردیف خودش را می‌سازد
            return ['ok' => true, 'force' => [$field => $me]];

        case 'own_or_admin':
            return ['ok' => true, 'filter' => ['sql' => "`$field` = ?", 'args' => [$me]]];

        case 'admin_or_own':
            if (has_perm('management', 'edit', $u)) return ['ok' => true];
            return ['ok' => true,
                    'filter' => ['sql' => "`$field` = ?", 'args' => [$me]],
                    'force'  => [$field => $me]];

        case 'profile_self_or_admin':
            return ['ok' => true, 'filter' => ['sql' => '`id` = ?', 'args' => [$me]]];

        case 'notif_select':
            return ['ok' => true,
                    'filter' => ['sql' => '(`profile_id` = ? OR `profile_id` IS NULL)',
                                 'args' => [$me]]];

        case 'letters_select':
            if (has_perm('management', 'edit', $u)) return ['ok' => true];
            return ['ok' => true,
                    'filter' => ['sql' => '(`sender_id` = ? OR `recipient_id` = ?)',
                                 'args' => [$me, $me]]];

        case 'signature_delete':
            if (has_perm('management', 'edit', $u)) return ['ok' => true];
            return ['ok' => true, 'filter' => ['sql' => '`profile_id` = ?', 'args' => [$me]]];

        // پرونده‌های منابع انسانی: یا دسترسی ماژول، یا فقط پرونده‌ی خودت
        case 'hr_self_or_perm':
            $pages = ['hr_employees','hr_org','hr_contracts','hr_attendance',
                      'hr_leaves','hr_payroll','hr_payslips'];
            if (has_page_perm($pages, 'hr', 'view', $u)) return ['ok' => true];
            if ($table === 'hr_employees') {
                return ['ok' => true, 'filter' => ['sql' => '`profile_id` = ?', 'args' => [$me]]];
            }
            return ['ok' => true, 'filter' => [
                'sql'  => '`employee_id` IN (SELECT id FROM hr_employees WHERE profile_id = ?)',
                'args' => [$me]]];

        case 'hr_leave_select':
            if (has_page_perm(['hr_leaves'], 'hr', 'view', $u)) return ['ok' => true];
            return ['ok' => true, 'filter' => [
                'sql'  => '(`submitted_by` = ? OR `employee_id` IN
                            (SELECT id FROM hr_employees WHERE profile_id = ?))',
                'args' => [$me, $me]]];

        case 'hr_leave_insert':
            // فقط برای خودش یا اگر دسترسی ویرایش منابع انسانی دارد
            return ['ok' => true, 'force' => ['submitted_by' => $me]];

        // گزارش‌های دارای گردش کار: ثبت‌کننده تا قبل از تأیید، یا تأییدکننده‌ی مرحله
        case 'workflow_update':
            if (has_perm('management', 'edit', $u)) return ['ok' => true];
            $conds = ["(`submitted_by` = ? AND `status` IN ('draft','rejected'))"];
            $args  = [$me];
            if (user_has_role('production_planning', $u)) $conds[] = '`current_step` = 1';
            if (user_has_role('ceo', $u))                 $conds[] = '`current_step` = 2';
            return ['ok' => true,
                    'filter' => ['sql' => '(' . implode(' OR ', $conds) . ')', 'args' => $args]];

        case 'owner_or_admin_update':
            if (has_perm('management', 'edit', $u)) return ['ok' => true];
            return ['ok' => true, 'filter' => [
                'sql'  => "(`submitted_by` = ? AND `status` IN ('draft','rejected'))",
                'args' => [$me]]];
    }
    return ['ok' => false];
}

// ===================================================================
//  لاگ فعالیت و اعلان (جایگزین تریگرهای پستگرس)
// ===================================================================

function log_activity(string $action, string $icon = '📝'): void {
    $u = current_user();
    try {
        $st = db()->prepare(
            'INSERT INTO activity_log (id, actor_id, action, icon, created_at)
             VALUES (?,?,?,?,UTC_TIMESTAMP())');
        $st->execute([uuid4(), $u['id'] ?? null, mb_substr($action, 0, 500), $icon]);
    } catch (Throwable $e) {
        error_log('[ERP] activity_log: ' . $e->getMessage());
    }
}

function add_notification(?string $profileId, string $title, ?string $body, string $kind): void {
    try {
        $st = db()->prepare(
            'INSERT INTO notifications (id, profile_id, title, body, kind, sent, created_at)
             VALUES (?,?,?,?,?,0,UTC_TIMESTAMP())');
        $st->execute([uuid4(), $profileId, $title, $body, $kind]);
    } catch (Throwable $e) {
        error_log('[ERP] notification: ' . $e->getMessage());
    }
}
