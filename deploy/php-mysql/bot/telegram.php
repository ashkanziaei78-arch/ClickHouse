<?php
/**
 * ربات تلگرام «سبزینه» — نسخه‌ی PHP برای هاست شخصی
 *
 * این فایل آدرس وب‌هوک ربات است. تلگرام پیام‌ها را به اینجا می‌فرستد و
 * ربات از همان دیتابیس سامانه گزارش می‌سازد.
 *
 * امنیت:
 *   • تلگرام باید هدر مخفی درست بفرستد، وگرنه درخواست رد می‌شود
 *   • کاربر باید با همان نام کاربری و رمز سامانه وارد شود
 *   • سطح دسترسی هر کاربر همان چیزی است که در سامانه دارد
 *   • ربات فقط می‌خواند؛ هیچ داده‌ای را تغییر نمی‌دهد
 */
declare(strict_types=1);
require_once __DIR__ . '/../api/lib.php';

// ---------------------------------------------------------------- تنظیمات
$BOT = bot_config();

function bot_config(): array {
    try {
        $r = db()->query("SELECT * FROM " . q('bot_config') . " WHERE id = 'main'")->fetch();
        return $r ?: [];
    } catch (Throwable $e) {
        return [];
    }
}

function tg_api(string $method, array $payload): array {
    global $BOT;
    $token = (string)($BOT['telegram_token'] ?? '');
    if ($token === '') return [];
    $ch = curl_init("https://api.telegram.org/bot{$token}/{$method}");
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_TIMEOUT        => 20,
        CURLOPT_HTTPHEADER     => ['Content-Type: application/json'],
        CURLOPT_POSTFIELDS     => json_encode($payload, JSON_UNESCAPED_UNICODE),
    ]);
    $res = curl_exec($ch);
    curl_close($ch);
    return $res ? (json_decode($res, true) ?: []) : [];
}

function say(string $chatId, string $text, ?array $keyboard = null): void {
    $p = ['chat_id' => $chatId, 'text' => $text, 'parse_mode' => 'HTML'];
    if ($keyboard) $p['reply_markup'] = ['keyboard' => $keyboard, 'resize_keyboard' => true];
    tg_api('sendMessage', $p);
}

function main_menu(): array {
    return [
        [['text' => '📈 تولید'],   ['text' => '📦 انبار']],
        [['text' => '💰 فروش'],    ['text' => '🏦 خزانه']],
        [['text' => '👥 پرسنل'],   ['text' => '⛔ توقفات']],
        [['text' => '📊 خلاصه امروز']],
        [['text' => '🚪 خروج']],
    ];
}

// ------------------------------------------------------- نشست کاربر ربات
function bot_session(string $chatId): array {
    $st = db()->prepare("SELECT * FROM " . q('bot_sessions') . " WHERE chat_id = ?");
    $st->execute([$chatId]);
    return $st->fetch() ?: [];
}

function set_session(string $chatId, ?string $step, ?string $tempUser = null): void {
    $sql = is_pg()
        ? 'INSERT INTO bot_sessions (chat_id, step, temp_username, updated_at)
           VALUES (?,?,?,' . now_sql() . ')
           ON CONFLICT (chat_id) DO UPDATE SET step = EXCLUDED.step,
             temp_username = EXCLUDED.temp_username, updated_at = EXCLUDED.updated_at'
        : 'INSERT INTO bot_sessions (chat_id, step, temp_username, updated_at)
           VALUES (?,?,?,' . now_sql() . ')
           ON DUPLICATE KEY UPDATE step = VALUES(step),
             temp_username = VALUES(temp_username), updated_at = VALUES(updated_at)';
    db()->prepare($sql)->execute([$chatId, $step, $tempUser]);
}

/** کاربر سامانه‌ای که این چت تلگرام به آن وصل است */
function bot_user(string $chatId): ?array {
    $st = db()->prepare(
        'SELECT p.* FROM bot_users b JOIN profiles p ON p.id = b.profile_id
         WHERE b.telegram_chat_id = ? AND b.active = ' . bool_sql(true));
    $st->execute([$chatId]);
    $u = $st->fetch();
    if (!$u) return null;
    if (!to_bool($u['active'] ?? true)) return null;
    $u['perms']    = json_decode((string)($u['perms'] ?? '{}'), true) ?: [];
    $u['is_admin'] = to_bool($u['is_admin'] ?? false);
    return $u;
}

function bot_login(string $chatId, string $username, string $password): bool {
    $st = db()->prepare(
        'SELECT a.id, a.password_hash, p.active FROM app_users a
         LEFT JOIN profiles p ON p.id = a.id WHERE a.username = ?');
    $st->execute([mb_strtolower(trim($username))]);
    $row = $st->fetch();
    if (!$row || !password_verify($password, (string)$row['password_hash'])) return false;
    if (!to_bool($row['active'] ?? true)) return false;

    $pr = db()->prepare('SELECT name, role_label FROM profiles WHERE id = ?');
    $pr->execute([$row['id']]);
    $p = $pr->fetch() ?: [];

    $sql = is_pg()
        ? 'INSERT INTO bot_users (id, telegram_chat_id, profile_id, display_name, role_label, active, created_at)
           VALUES (?,?,?,?,?,' . bool_sql(true) . ',' . now_sql() . ')
           ON CONFLICT (telegram_chat_id) DO UPDATE SET profile_id = EXCLUDED.profile_id,
             display_name = EXCLUDED.display_name, role_label = EXCLUDED.role_label,
             active = ' . bool_sql(true)
        : 'INSERT INTO bot_users (id, telegram_chat_id, profile_id, display_name, role_label, active, created_at)
           VALUES (?,?,?,?,?,' . bool_sql(true) . ',' . now_sql() . ')
           ON DUPLICATE KEY UPDATE profile_id = VALUES(profile_id),
             display_name = VALUES(display_name), role_label = VALUES(role_label),
             active = ' . bool_sql(true);
    db()->prepare($sql)->execute([
        uuid4(), $chatId, $row['id'],
        (string)($p['name'] ?? $username), (string)($p['role_label'] ?? ''),
    ]);
    return true;
}

// ============================================================
//  گزارش‌ها — همان دسترسی‌هایی که کاربر در سامانه دارد
// ============================================================

function fa_num(float|int|string|null $n, int $dec = 0): string {
    return number_format((float)$n, $dec);
}

function range_days(int $days): array {
    $to   = gmdate('Y-m-d');
    $from = gmdate('Y-m-d', strtotime("-$days days"));
    return [$from, $to];
}

function rep_production(array $u, int $days): string {
    if (!has_page_perm(['daily'], 'production', 'view', $u)) {
        return '⛔ به گزارش تولید دسترسی ندارید.';
    }
    [$from, $to] = range_days($days);
    $st = db()->prepare(
        'SELECT COUNT(*) AS n, COALESCE(SUM(production),0) AS prod,
                COALESCE(SUM(waste),0) AS waste
         FROM daily_reports WHERE date BETWEEN ? AND ?');
    $st->execute([$from, $to]);
    $r = $st->fetch() ?: [];

    $ln = db()->prepare(
        'SELECT line, COALESCE(SUM(production),0) AS p FROM daily_reports
         WHERE date BETWEEN ? AND ? GROUP BY line ORDER BY p DESC');
    $ln->execute([$from, $to]);

    $prod  = (float)($r['prod'] ?? 0);
    $waste = (float)($r['waste'] ?? 0);
    $rate  = ($prod + $waste) > 0 ? $waste / ($prod + $waste) * 100 : 0;

    $t = "📈 <b>گزارش تولید</b> ({$days} روز اخیر)\n";
    $t .= "━━━━━━━━━━━━━━━\n";
    $t .= "تعداد گزارش : " . fa_num($r['n'] ?? 0) . "\n";
    $t .= "تولید کل    : " . fa_num($prod, 1) . " کیلوگرم\n";
    $t .= "ضایعات      : " . fa_num($waste, 1) . " کیلوگرم\n";
    $t .= "نرخ ضایعات  : " . fa_num($rate, 2) . "٪\n";
    $rows = $ln->fetchAll();
    if ($rows) {
        $t .= "\n<b>به تفکیک خط:</b>\n";
        foreach ($rows as $x) {
            $t .= "• " . ($x['line'] ?: '—') . ' : ' . fa_num($x['p'], 1) . " kg\n";
        }
    }
    return $t;
}

function rep_stops(array $u, int $days): string {
    if (!has_page_perm(['stops'], 'production', 'view', $u)) {
        return '⛔ به گزارش توقفات دسترسی ندارید.';
    }
    [$from, $to] = range_days($days);
    $st = db()->prepare(
        'SELECT stop_type, COUNT(*) AS n, COALESCE(SUM(duration_min),0) AS m
         FROM production_stops WHERE stop_date BETWEEN ? AND ?
         GROUP BY stop_type ORDER BY m DESC');
    $st->execute([$from, $to]);
    $rows = $st->fetchAll();
    if (!$rows) return "⛔ <b>توقفات</b>\nدر این بازه توقفی ثبت نشده.";

    $tot = array_sum(array_map(fn($r) => (float)$r['m'], $rows));
    $t = "⛔ <b>توقفات</b> ({$days} روز اخیر)\n━━━━━━━━━━━━━━━\n";
    $t .= "مجموع: " . fa_num($tot) . " دقیقه (" . fa_num($tot / 60, 1) . " ساعت)\n\n";
    foreach ($rows as $r) {
        $t .= "• " . ($r['stop_type'] ?: '—') . ' : ' . fa_num($r['m']) . " دقیقه (" . $r['n'] . " مورد)\n";
    }
    return $t;
}

function rep_inventory(array $u): string {
    if (!has_page_perm(['inventory', 'rawmat'], 'warehouse', 'view', $u)) {
        return '⛔ به انبار دسترسی ندارید.';
    }
    $t = "📦 <b>وضعیت انبار</b>\n━━━━━━━━━━━━━━━\n";
    $rm = db()->query(
        'SELECT name, stock, min_stock FROM rawmats ORDER BY name')->fetchAll();
    if ($rm) {
        $t .= "<b>مواد اولیه:</b>\n";
        foreach ($rm as $r) {
            $low = (float)$r['stock'] <= (float)$r['min_stock'] ? ' ⚠️' : '';
            $t .= '• ' . $r['name'] . ' : ' . fa_num($r['stock'], 1) . $low . "\n";
        }
    }
    $inv = db()->query('SELECT COALESCE(SUM(sheets),0) AS s FROM inventory')->fetch();
    $t .= "\nموجودی کاغذ: " . fa_num($inv['s'] ?? 0) . " ورق\n";
    return $t;
}

function rep_sales(array $u, int $days): string {
    if (!has_page_perm(['sales', 'sales_orders'], 'sales', 'view', $u)) {
        return '⛔ به گزارش فروش دسترسی ندارید.';
    }
    [$from, $to] = range_days($days);
    $st = db()->prepare(
        'SELECT COUNT(*) AS n, COALESCE(SUM(total),0) AS t, COALESCE(SUM(paid),0) AS p
         FROM invoices WHERE invoice_date BETWEEN ? AND ?');
    $st->execute([$from, $to]);
    $r = $st->fetch() ?: [];
    $tot  = (float)($r['t'] ?? 0);
    $paid = (float)($r['p'] ?? 0);
    return "💰 <b>گزارش فروش</b> ({$days} روز اخیر)\n━━━━━━━━━━━━━━━\n"
         . 'تعداد فاکتور : ' . fa_num($r['n'] ?? 0) . "\n"
         . 'مبلغ کل      : ' . fa_num($tot) . " ﷼\n"
         . 'دریافت‌شده   : ' . fa_num($paid) . " ﷼\n"
         . 'مانده        : ' . fa_num($tot - $paid) . " ﷼\n";
}

function rep_treasury(array $u): string {
    if (!has_page_perm(['tr_accounts', 'tr_checks'], 'treasury', 'view', $u)) {
        return '⛔ به خزانه دسترسی ندارید.';
    }
    $t = "🏦 <b>خزانه</b>\n━━━━━━━━━━━━━━━\n";
    $acc = db()->query(
        'SELECT name, kind, COALESCE(opening_balance,0) AS b FROM treasury_accounts
         WHERE active = ' . bool_sql(true) . ' ORDER BY name')->fetchAll();
    foreach ($acc as $a) {
        $t .= '• ' . $a['name'] . ' (' . ($a['kind'] === 'bank' ? 'بانک' : 'صندوق') . ') : '
            . fa_num($a['b']) . " ﷼\n";
    }
    $ch = db()->query(
        "SELECT status, COUNT(*) AS n, COALESCE(SUM(amount),0) AS s
         FROM treasury_checks GROUP BY status")->fetchAll();
    if ($ch) {
        $t .= "\n<b>چک‌ها:</b>\n";
        $lbl = ['in_hand' => 'در جریان', 'cashed' => 'وصول‌شده', 'bounced' => 'برگشتی'];
        foreach ($ch as $c) {
            $t .= '• ' . ($lbl[$c['status']] ?? $c['status']) . ' : '
                . $c['n'] . ' فقره — ' . fa_num($c['s']) . " ﷼\n";
        }
    }
    return $t;
}

function rep_hr(array $u): string {
    if (!has_page_perm(['hr_employees', 'hr_attendance'], 'hr', 'view', $u)) {
        return '⛔ به منابع انسانی دسترسی ندارید.';
    }
    $emp = db()->query('SELECT COUNT(*) AS n FROM hr_employees WHERE active = ' . bool_sql(true))->fetch();
    [$from, $to] = range_days(7);
    $att = db()->prepare(
        'SELECT status, COUNT(*) AS n FROM hr_attendance
         WHERE att_date BETWEEN ? AND ? GROUP BY status');
    $att->execute([$from, $to]);
    $t = "👥 <b>منابع انسانی</b>\n━━━━━━━━━━━━━━━\n";
    $t .= 'پرسنل فعال : ' . fa_num($emp['n'] ?? 0) . "\n\n<b>حضور (۷ روز):</b>\n";
    $lbl = ['present' => 'حاضر', 'absent' => 'غایب', 'leave' => 'مرخصی', 'mission' => 'ماموریت'];
    foreach ($att->fetchAll() as $r) {
        $t .= '• ' . ($lbl[$r['status']] ?? $r['status']) . ' : ' . $r['n'] . "\n";
    }
    return $t;
}

function rep_today(array $u): string {
    $t = "📊 <b>خلاصه امروز</b>\n━━━━━━━━━━━━━━━\n";
    $today = gmdate('Y-m-d');

    if (has_page_perm(['daily'], 'production', 'view', $u)) {
        $st = db()->prepare(
            'SELECT COALESCE(SUM(production),0) AS p, COALESCE(SUM(waste),0) AS w
             FROM daily_reports WHERE date = ?');
        $st->execute([$today]);
        $r = $st->fetch();
        $t .= '📈 تولید : ' . fa_num($r['p'] ?? 0, 1) . " kg\n";
        $t .= '♻️ ضایعات : ' . fa_num($r['w'] ?? 0, 1) . " kg\n";
    }
    if (has_page_perm(['stops'], 'production', 'view', $u)) {
        $st = db()->prepare('SELECT COALESCE(SUM(duration_min),0) AS m FROM production_stops WHERE stop_date = ?');
        $st->execute([$today]);
        $t .= '⛔ توقف : ' . fa_num($st->fetch()['m'] ?? 0) . " دقیقه\n";
    }
    // کارهای در انتظار تایید این کاربر
    $pend = db()->prepare(
        "SELECT COUNT(*) AS n FROM daily_reports WHERE status = 'submitted'");
    $pend->execute();
    $t .= "\n⏳ در انتظار تایید : " . fa_num($pend->fetch()['n'] ?? 0) . " گزارش تولید\n";
    return $t;
}

// ============================================================
//  ورودی وب‌هوک
// ============================================================

// ۱) بررسی هدر مخفی — بدون آن هرکسی می‌توانست به ربات پیام جعلی بفرستد
$secret = (string)($BOT['webhook_secret'] ?? '');
$got    = $_SERVER['HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN'] ?? '';
if ($secret === '' || !hash_equals($secret, (string)$got)) {
    http_response_code(401);
    echo 'unauthorized';
    exit;
}

$update = json_decode(file_get_contents('php://input') ?: '', true) ?: [];
$msg    = $update['message'] ?? $update['edited_message'] ?? null;
if (!$msg) { echo 'ok'; exit; }

$chatId  = (string)($msg['chat']['id'] ?? '');
$text    = trim((string)($msg['text'] ?? ''));
$msgId   = $msg['message_id'] ?? null;
if ($chatId === '') { echo 'ok'; exit; }

try {
    handle($chatId, $text, $msgId);
} catch (Throwable $e) {
    error_log('[BOT] ' . $e->getMessage());
    say($chatId, '⚠️ خطایی رخ داد. دوباره تلاش کنید.');
}
echo 'ok';


function handle(string $chatId, string $text, mixed $msgId): void {
    $sess = bot_session($chatId);
    $step = (string)($sess['step'] ?? '');

    // ---- مرحله‌ی ورود ----
    if ($step === 'await_user') {
        set_session($chatId, 'await_pass', $text);
        say($chatId, '🔑 حالا رمز عبور را بفرستید:');
        return;
    }
    if ($step === 'await_pass') {
        $username = (string)($sess['temp_username'] ?? '');
        // پیام حاوی رمز را فورا پاک می‌کنیم
        if ($msgId) tg_api('deleteMessage', ['chat_id' => $chatId, 'message_id' => $msgId]);
        if (bot_login($chatId, $username, $text)) {
            set_session($chatId, null, null);
            $u = bot_user($chatId);
            say($chatId, "✅ خوش آمدید <b>" . htmlspecialchars((string)($u['name'] ?? '')) . "</b>\n"
                . "از منوی پایین گزارش دلخواه را انتخاب کنید:", main_menu());
        } else {
            set_session($chatId, null, null);
            say($chatId, "❌ نام کاربری یا رمز اشتباه بود.\nبرای تلاش دوباره /start را بزنید.");
        }
        return;
    }

    // ---- دستورها ----
    if ($text === '/start' || $text === 'شروع') {
        if (bot_user($chatId)) {
            say($chatId, '👋 شما وارد شده‌اید. یک گزینه را انتخاب کنید:', main_menu());
        } else {
            set_session($chatId, 'await_user');
            say($chatId, "🌿 <b>سبزینه</b> — دستیار گزارش‌گیری\n\n"
                . "برای ورود، نام کاربری سامانه را بفرستید:");
        }
        return;
    }

    if ($text === '/logout' || $text === '🚪 خروج') {
        db()->prepare('DELETE FROM bot_users WHERE telegram_chat_id = ?')->execute([$chatId]);
        set_session($chatId, null, null);
        say($chatId, '🚪 خارج شدید. برای ورود دوباره /start را بزنید.');
        return;
    }

    $u = bot_user($chatId);
    if (!$u) {
        set_session($chatId, 'await_user');
        say($chatId, "برای استفاده باید وارد شوید.\nنام کاربری سامانه را بفرستید:");
        return;
    }

    // ---- گزارش‌ها ----
    $answer = match (true) {
        str_contains($text, 'تولید')   => rep_production($u, 7),
        str_contains($text, 'توقف')    => rep_stops($u, 7),
        str_contains($text, 'انبار')   => rep_inventory($u),
        str_contains($text, 'فروش')    => rep_sales($u, 30),
        str_contains($text, 'خزانه')   => rep_treasury($u),
        str_contains($text, 'پرسنل')   => rep_hr($u),
        str_contains($text, 'امروز')   => rep_today($u),
        $text === '/tolid'             => rep_production($u, 7),
        $text === '/anbar'             => rep_inventory($u),
        $text === '/forush'            => rep_sales($u, 30),
        $text === '/khazane'           => rep_treasury($u),
        $text === '/manabe'            => rep_hr($u),
        $text === '/help' || $text === 'راهنما' =>
            "🌿 <b>راهنمای سبزینه</b>\n\n"
            . "از دکمه‌های پایین استفاده کنید یا این دستورها را بفرستید:\n"
            . "/tolid — گزارش تولید\n/anbar — وضعیت انبار\n"
            . "/forush — گزارش فروش\n/khazane — خزانه\n"
            . "/manabe — منابع انسانی\n/logout — خروج",
        default => "متوجه نشدم 🤔\nاز دکمه‌های پایین استفاده کنید یا /help را بزنید.",
    };

    say($chatId, $answer, main_menu());

    // ثبت در تاریخچه‌ی ربات
    try {
        db()->prepare(
            'INSERT INTO bot_log (id, telegram_chat_id, question, answer, created_at)
             VALUES (?,?,?,?,' . now_sql() . ')')
            ->execute([uuid4(), $chatId, mb_substr($text, 0, 500), mb_substr($answer, 0, 2000)]);
    } catch (Throwable $e) { /* لاگ نشدن گزارش نباید کار ربات را متوقف کند */ }
}
