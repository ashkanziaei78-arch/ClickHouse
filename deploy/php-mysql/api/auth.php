<?php
/**
 * ورود، خروج و تغییر رمز — جایگزین Supabase Auth
 *
 * رمزها با bcrypt هش می‌شوند و هرگز به‌صورت خام ذخیره نمی‌شوند.
 * توکن نشست تصادفی است و در دیتابیس فقط هشِ آن نگهداری می‌شود.
 */
declare(strict_types=1);
require_once __DIR__ . '/lib.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') fail('روش درخواست نامعتبر است', 405);

$in     = body_json();
$action = (string)($in['action'] ?? '');

switch ($action) {

// ------------------------------------------------------------------- ورود
case 'login': {
    $username = trim((string)($in['username'] ?? ''));
    $password = (string)($in['password'] ?? '');
    if ($username === '' || $password === '') fail('نام کاربری و رمز را وارد کنید');

    $st = db()->prepare(
        'SELECT a.id, a.password_hash, a.failed_tries, a.locked_until, p.active
         FROM app_users a
         LEFT JOIN profiles p ON p.id = a.id
         WHERE a.username = ?');
    $st->execute([mb_strtolower($username)]);
    $row = $st->fetch();

    // پیام یکسان برای «کاربر نیست» و «رمز غلط» تا اطلاعات لو نرود
    $generic = 'نام کاربری یا رمز عبور اشتباه است';

    if (!$row) {
        usleep(300000);
        fail($generic, 401);
    }

    if ($row['locked_until'] !== null && strtotime((string)$row['locked_until']) > time()) {
        $mins = (int)ceil((strtotime((string)$row['locked_until']) - time()) / 60);
        fail("به دلیل تلاش‌های ناموفق، حساب موقتا قفل است. {$mins} دقیقه دیگر تلاش کنید.", 429);
    }

    if (!password_verify($password, (string)$row['password_hash'])) {
        $tries = (int)$row['failed_tries'] + 1;
        $lock  = $tries >= LOGIN_MAX_TRIES
            ? (new DateTime('@' . (time() + LOGIN_LOCK_SECONDS)))->format('Y-m-d H:i:s')
            : null;
        $up = db()->prepare('UPDATE app_users SET failed_tries = ?, locked_until = ? WHERE id = ?');
        $up->execute([$tries, $lock, $row['id']]);
        usleep(300000);
        fail($generic, 401);
    }

    if (!to_bool($row['active'] ?? true)) fail('حساب کاربری شما غیرفعال است', 403);

    db()->prepare('UPDATE app_users SET failed_tries = 0, locked_until = NULL WHERE id = ?')
        ->execute([$row['id']]);

    $token = bin2hex(random_bytes(32));
    db()->prepare(
        'INSERT INTO app_sessions (token, user_id, created_at, expires_at, ip)
         VALUES (?,?,' . now_sql() . ',' . plus_seconds_sql() . ',?)')
        ->execute([hash('sha256', $token), $row['id'], SESSION_LIFETIME,
                   mb_substr((string)($_SERVER['REMOTE_ADDR'] ?? ''), 0, 45)]);

    // پاک کردن نشست‌های منقضی (نگهداری خودکار)
    db()->exec('DELETE FROM app_sessions WHERE expires_at < ' . now_sql());

    $ps = db()->prepare('SELECT * FROM profiles WHERE id = ?');
    $ps->execute([$row['id']]);
    $profile = $ps->fetch() ?: [];
    $profile['perms'] = json_decode((string)($profile['perms'] ?? '{}'), true) ?: [];

    json_out(['token' => $token, 'user' => row_to_camel($profile)]);
}

// ------------------------------------------------------------------- خروج
case 'logout': {
    $tok = bearer_token();
    if ($tok) {
        db()->prepare('DELETE FROM app_sessions WHERE token = ?')
            ->execute([hash('sha256', $tok)]);
    }
    json_out(['ok' => true]);
}

// ------------------------------------------------- کاربر فعلی (بازیابی نشست)
case 'me': {
    $u = current_user();
    if (!$u) json_out(['user' => null]);
    json_out(['user' => row_to_camel($u)]);
}

// ------------------------------------------------------------- تغییر رمز خود
case 'change_password': {
    $u   = require_login();
    $old = (string)($in['oldPassword'] ?? '');
    $new = (string)($in['newPassword'] ?? '');
    if (mb_strlen($new) < 8) fail('رمز جدید باید حداقل ۸ کاراکتر باشد');

    $st = db()->prepare('SELECT password_hash FROM app_users WHERE id = ?');
    $st->execute([$u['id']]);
    $hash = (string)($st->fetchColumn() ?: '');
    if (!password_verify($old, $hash)) fail('رمز فعلی اشتباه است', 403);

    db()->prepare('UPDATE app_users SET password_hash = ? WHERE id = ?')
        ->execute([password_hash($new, PASSWORD_BCRYPT), $u['id']]);

    // با تغییر رمز، نشست‌های دیگر باطل می‌شوند (به‌جز همین نشست)
    $tok = bearer_token();
    db()->prepare('DELETE FROM app_sessions WHERE user_id = ? AND token <> ?')
        ->execute([$u['id'], hash('sha256', (string)$tok)]);

    log_activity('تغییر رمز عبور', '🔑');
    json_out(['ok' => true]);
}

// ------------------------------------- مدیریت کاربران (فقط مدیر سیستم)
case 'admin_create_user':
case 'admin_set_password':
case 'admin_set_active': {
    $u = require_login();
    if (!is_admin($u)) fail('فقط مدیر سیستم می‌تواند کاربران را مدیریت کند', 403);

    if ($action === 'admin_create_user') {
        $username = mb_strtolower(trim((string)($in['username'] ?? '')));
        $password = (string)($in['password'] ?? '');
        if (!preg_match('/^[a-z0-9_.]{3,50}$/', $username)) {
            fail('نام کاربری باید ۳ تا ۵۰ کاراکتر و فقط حروف انگلیسی، عدد، نقطه یا خط زیر باشد');
        }
        if (mb_strlen($password) < 8) fail('رمز باید حداقل ۸ کاراکتر باشد');

        $ex = db()->prepare('SELECT 1 FROM app_users WHERE username = ?');
        $ex->execute([$username]);
        if ($ex->fetchColumn()) fail('این نام کاربری قبلا ثبت شده است');

        $id = uuid4();
        db()->beginTransaction();
        try {
            db()->prepare(
                'INSERT INTO app_users (id, username, password_hash, created_at)
                 VALUES (?,?,?,' . now_sql() . ')')
                ->execute([$id, $username, password_hash($password, PASSWORD_BCRYPT)]);

            db()->prepare(
                'INSERT INTO profiles (id, username, name, role, role_label, is_admin, active, perms, created_at)
                 VALUES (?,?,?,?,?,?,' . bool_sql(true) . ',?,' . now_sql() . ')')
                ->execute([
                    $id, $username,
                    (string)($in['name'] ?? $username),
                    (string)($in['role'] ?? ''),
                    (string)($in['roleLabel'] ?? ''),
                    bool_param(!empty($in['isAdmin'])),
                    json_encode((object)($in['perms'] ?? []), JSON_UNESCAPED_UNICODE),
                ]);
            db()->commit();
        } catch (Throwable $e) {
            db()->rollBack();
            fail_internal('create user: ' . $e->getMessage());
        }
        log_activity('ساخت کاربر جدید: ' . $username, '👤');
        json_out(['ok' => true, 'id' => $id]);
    }

    if ($action === 'admin_set_password') {
        $id  = (string)($in['id'] ?? '');
        $new = (string)($in['password'] ?? '');
        if (!is_uuid($id)) fail('شناسه کاربر نامعتبر است');
        if (mb_strlen($new) < 8) fail('رمز باید حداقل ۸ کاراکتر باشد');
        db()->prepare('UPDATE app_users SET password_hash = ?, failed_tries = 0, locked_until = NULL WHERE id = ?')
            ->execute([password_hash($new, PASSWORD_BCRYPT), $id]);
        db()->prepare('DELETE FROM app_sessions WHERE user_id = ?')->execute([$id]);
        log_activity('تغییر رمز یک کاربر توسط مدیر سیستم', '🔑');
        json_out(['ok' => true]);
    }

    // admin_set_active
    $id     = (string)($in['id'] ?? '');
    $active = !empty($in['active']);
    if (!is_uuid($id)) fail('شناسه کاربر نامعتبر است');
    db()->prepare('UPDATE profiles SET active = ? WHERE id = ?')->execute([bool_param($active), $id]);
    if (!$active) db()->prepare('DELETE FROM app_sessions WHERE user_id = ?')->execute([$id]);
    log_activity(($active ? 'فعال' : 'غیرفعال') . ' کردن کاربر', '👤');
    json_out(['ok' => true]);
}

}

fail('عملیات نامعتبر است', 400);
