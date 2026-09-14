<?php
/**
 * تنظیمات اتصال به دیتابیس
 *
 * ۱) این فایل را به config.php تغییر نام دهید
 * ۲) چهار مقدار زیر را از پنل هاست خود (cPanel → MySQL Databases) بردارید
 *
 * ⚠️ این فایل رمز دیتابیس را دارد — هرگز آن را در گیت‌هاب یا جای عمومی نگذارید.
 */

define('DB_HOST', 'localhost');
define('DB_PORT', 3306);
define('DB_NAME', 'اسم_دیتابیس');
define('DB_USER', 'کاربر_دیتابیس');
define('DB_PASS', 'رمز_دیتابیس');

// مدت اعتبار نشست کاربر (ثانیه) — پیش‌فرض ۱۲ ساعت
define('SESSION_LIFETIME', 12 * 60 * 60);

// قفل موقت حساب بعد از چند تلاش ناموفق ورود
define('LOGIN_MAX_TRIES', 5);
define('LOGIN_LOCK_SECONDS', 15 * 60);

// حداکثر حجم تصویر امضا (بایت)
define('MAX_UPLOAD_BYTES', 2 * 1024 * 1024);
