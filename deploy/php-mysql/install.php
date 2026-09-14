<?php
/**
 * نصاب وب — سامانه ERP پیشگامان صنعت سبز
 *
 * این فایل را کنار index.html آپلود کنید و در مرورگر باز کنید:
 *     https://yourdomain.ir/install.php
 *
 * ⚠️ بعد از پایان نصب حتما این فایل را پاک کنید.
 */
declare(strict_types=1);
mb_internal_encoding('UTF-8');
session_start();

$API_DIR   = __DIR__ . '/api';
$CONFIG    = $API_DIR . '/config.php';
$SCHEMA    = __DIR__ . '/database/mysql_schema.sql';
$installed = file_exists($CONFIG);
$step      = (int)($_POST['step'] ?? ($installed ? 2 : 1));
$errors    = [];
$done      = false;

function e(string $s): string { return htmlspecialchars($s, ENT_QUOTES, 'UTF-8'); }

// ------------------------------------------------------- بررسی پیش‌نیازها
$checks = [
    'نسخه PHP (حداقل 8.0)'      => version_compare(PHP_VERSION, '8.0.0', '>='),
    'افزونه PDO MySQL'          => extension_loaded('pdo_mysql'),
    'افزونه mbstring'           => extension_loaded('mbstring'),
    'افزونه JSON'               => extension_loaded('json'),
    'قابلیت نوشتن در پوشه api'  => is_writable($API_DIR) || is_writable(__DIR__),
    'فایل ساختار دیتابیس'       => file_exists($SCHEMA),
];
$ready = !in_array(false, $checks, true);

// ------------------------------------------------------------ انجام نصب
if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['do'] ?? '') === 'install') {
    $host = trim((string)($_POST['host'] ?? 'localhost'));
    $port = (int)($_POST['port'] ?? 3306);
    $name = trim((string)($_POST['dbname'] ?? ''));
    $user = trim((string)($_POST['dbuser'] ?? ''));
    $pass = (string)($_POST['dbpass'] ?? '');
    $au   = mb_strtolower(trim((string)($_POST['adminuser'] ?? '')));
    $ap   = (string)($_POST['adminpass'] ?? '');
    $an   = trim((string)($_POST['adminname'] ?? 'مدیر سیستم'));

    if ($name === '' || $user === '') $errors[] = 'نام دیتابیس و کاربر دیتابیس الزامی است.';
    if (!preg_match('/^[a-z0-9_.]{3,50}$/', $au)) {
        $errors[] = 'نام کاربری مدیر باید ۳ تا ۵۰ کاراکتر و فقط حروف انگلیسی، عدد، نقطه یا خط زیر باشد.';
    }
    if (mb_strlen($ap) < 8) $errors[] = 'رمز مدیر باید حداقل ۸ کاراکتر باشد.';

    if (!$errors) {
        try {
            $pdo = new PDO("mysql:host=$host;port=$port;dbname=$name;charset=utf8mb4",
                $user, $pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
        } catch (PDOException $ex) {
            $errors[] = 'اتصال به دیتابیس ناموفق بود: ' . $ex->getMessage();
        }
    }

    if (!$errors) {
        // اجرای فایل ساختار
        try {
            $sqlText = file_get_contents($SCHEMA);
            // حذف کامنت‌های تک‌خطی تا تقسیم دستورات درست انجام شود
            $sqlText = preg_replace('/^--.*$/m', '', (string)$sqlText);
            foreach (array_filter(array_map('trim', explode(";\n", $sqlText))) as $stmt) {
                if ($stmt === '') continue;
                $pdo->exec($stmt);
            }
        } catch (PDOException $ex) {
            $errors[] = 'خطا در ساخت جدول‌ها: ' . $ex->getMessage();
        }
    }

    if (!$errors) {
        // ساخت کاربر مدیر
        try {
            $chk = $pdo->prepare('SELECT id FROM app_users WHERE username = ?');
            $chk->execute([$au]);
            $uid = $chk->fetchColumn();

            if (!$uid) {
                $d = random_bytes(16);
                $d[6] = chr((ord($d[6]) & 0x0f) | 0x40);
                $d[8] = chr((ord($d[8]) & 0x3f) | 0x80);
                $uid = vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($d), 4));

                $pdo->prepare('INSERT INTO app_users (id,username,password_hash,created_at)
                               VALUES (?,?,?,NOW())')
                    ->execute([$uid, $au, password_hash($ap, PASSWORD_BCRYPT)]);
            } else {
                $pdo->prepare('UPDATE app_users SET password_hash = ? WHERE id = ?')
                    ->execute([password_hash($ap, PASSWORD_BCRYPT), $uid]);
            }

            $pdo->prepare(
                'INSERT INTO profiles (id,username,name,role,role_label,is_admin,active,perms,created_at)
                 VALUES (?,?,?,?,?,1,1,?,NOW())
                 ON DUPLICATE KEY UPDATE is_admin = 1, active = 1, name = VALUES(name)')
                ->execute([$uid, $au, $an, 'system_admin', 'مدیرسیستم', '{}']);
        } catch (PDOException $ex) {
            $errors[] = 'خطا در ساخت کاربر مدیر: ' . $ex->getMessage();
        }
    }

    if (!$errors) {
        // نوشتن فایل تنظیمات
        $cfg = "<?php\n"
             . "// ساخته‌شده توسط نصاب — " . date('Y-m-d H:i') . "\n"
             . "define('DB_HOST', " . var_export($host, true) . ");\n"
             . "define('DB_PORT', " . $port . ");\n"
             . "define('DB_NAME', " . var_export($name, true) . ");\n"
             . "define('DB_USER', " . var_export($user, true) . ");\n"
             . "define('DB_PASS', " . var_export($pass, true) . ");\n"
             . "define('SESSION_LIFETIME', 12 * 60 * 60);\n"
             . "define('LOGIN_MAX_TRIES', 5);\n"
             . "define('LOGIN_LOCK_SECONDS', 15 * 60);\n"
             . "define('MAX_UPLOAD_BYTES', 2 * 1024 * 1024);\n";
        if (@file_put_contents($CONFIG, $cfg) === false) {
            $errors[] = 'فایل api/config.php نوشته نشد. دسترسی پوشه را روی ۷۵۵ بگذارید یا فایل را دستی بسازید.';
        } else {
            @chmod($CONFIG, 0640);
            $done = true;
        }
    }
}
?>
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>نصب سامانه ERP</title>
<style>
  *{box-sizing:border-box;font-family:Tahoma,sans-serif}
  body{margin:0;background:#0B0F1A;color:#E6EDF6;padding:24px;line-height:1.9}
  .box{max-width:680px;margin:0 auto;background:#121826;border:1px solid #232D44;
       border-radius:14px;padding:26px}
  h1{font-size:20px;margin:0 0 6px;color:#10D970}
  .sub{color:#9FB0C6;font-size:13px;margin-bottom:22px}
  label{display:block;font-size:13px;margin:14px 0 6px;color:#C9D6E8}
  input{width:100%;padding:11px 12px;border-radius:8px;border:1px solid #232D44;
        background:#1A2234;color:#E6EDF6;font-size:14px}
  button{margin-top:22px;width:100%;padding:13px;border:0;border-radius:9px;
         background:#10D970;color:#04220F;font-weight:bold;font-size:15px;cursor:pointer}
  .chk{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid #1c2437;font-size:13px}
  .ok{color:#10D970}.bad{color:#FF5C5C}
  .err{background:#3a1414;border:1px solid #FF5C5C;color:#ffc9c9;padding:12px;
       border-radius:8px;margin:14px 0;font-size:13px}
  .ok-box{background:#0d2e1a;border:1px solid #10D970;padding:16px;border-radius:9px;font-size:14px}
  .warn{background:#3a2e14;border:1px solid #FFB020;color:#ffe2ad;padding:12px;
        border-radius:8px;margin-top:16px;font-size:13px}
  code{background:#1A2234;padding:2px 6px;border-radius:4px;font-size:12px}
  .grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
  @media(max-width:560px){.grid{grid-template-columns:1fr}}
</style>
</head>
<body>
<div class="box">
  <h1>نصب سامانه ERP — پیشگامان صنعت سبز</h1>
  <div class="sub">نسخه‌ی هاست شخصی (PHP + MySQL)</div>

<?php if ($done): ?>
  <div class="ok-box">
    <b>✅ نصب با موفقیت انجام شد.</b><br><br>
    حالا می‌توانید وارد سامانه شوید:<br>
    <a href="index.html" style="color:#10D970">رفتن به سامانه ←</a>
  </div>
  <div class="warn">
    <b>مهم — همین حالا انجام دهید:</b><br>
    فایل <code>install.php</code> را از هاست پاک کنید.<br>
    تا وقتی این فایل روی سرور باشد، کسی می‌تواند دوباره نصب را اجرا کند.
  </div>

<?php else: ?>

  <?php foreach ($errors as $er): ?>
    <div class="err">⚠️ <?= e($er) ?></div>
  <?php endforeach; ?>

  <?php if ($installed && !$errors): ?>
    <div class="warn">
      سامانه قبلا نصب شده است (<code>api/config.php</code> وجود دارد).<br>
      اگر می‌خواهید از نو نصب کنید، اول آن فایل را پاک کنید.
    </div>
  <?php endif; ?>

  <h3 style="font-size:15px;margin:18px 0 8px">۱) بررسی پیش‌نیازها</h3>
  <?php foreach ($checks as $label => $okc): ?>
    <div class="chk"><span><?= e($label) ?></span>
      <span class="<?= $okc ? 'ok' : 'bad' ?>"><?= $okc ? '✓ درست' : '✗ مشکل دارد' ?></span></div>
  <?php endforeach; ?>

  <?php if (!$ready): ?>
    <div class="err">تا وقتی موارد بالا درست نشوند نصب ممکن نیست.
      معمولا با تغییر نسخه‌ی PHP در پنل هاست حل می‌شود.</div>
  <?php else: ?>

  <form method="post">
    <input type="hidden" name="do" value="install">

    <h3 style="font-size:15px;margin:22px 0 4px">۲) اطلاعات دیتابیس</h3>
    <div class="sub" style="margin:0 0 6px">این اطلاعات را از پنل هاست بخش
      <code>MySQL Databases</code> بردارید.</div>

    <div class="grid">
      <div><label>آدرس سرور دیتابیس</label>
        <input name="host" value="<?= e($_POST['host'] ?? 'localhost') ?>"></div>
      <div><label>پورت</label>
        <input name="port" value="<?= e((string)($_POST['port'] ?? '3306')) ?>"></div>
    </div>
    <label>نام دیتابیس</label>
    <input name="dbname" required value="<?= e($_POST['dbname'] ?? '') ?>">
    <label>کاربر دیتابیس</label>
    <input name="dbuser" required value="<?= e($_POST['dbuser'] ?? '') ?>">
    <label>رمز دیتابیس</label>
    <input name="dbpass" type="password" value="">

    <h3 style="font-size:15px;margin:24px 0 4px">۳) کاربر مدیر سامانه</h3>
    <div class="sub" style="margin:0 0 6px">با این حساب وارد سامانه می‌شوید.</div>
    <div class="grid">
      <div><label>نام کاربری (انگلیسی)</label>
        <input name="adminuser" required value="<?= e($_POST['adminuser'] ?? 'admin') ?>"></div>
      <div><label>نام نمایشی</label>
        <input name="adminname" value="<?= e($_POST['adminname'] ?? 'مدیر سیستم') ?>"></div>
    </div>
    <label>رمز عبور (حداقل ۸ کاراکتر)</label>
    <input name="adminpass" type="password" required>

    <button type="submit">شروع نصب</button>
  </form>

  <?php endif; ?>
<?php endif; ?>
</div>
</body>
</html>
