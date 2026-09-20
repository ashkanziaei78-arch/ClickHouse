# نصب روی هاست معمولی — دیتابیس روی خود هاست

این نسخه **هیچ وابستگی به Supabase یا هیچ سرویس بیرونی ندارد**.
همه‌چیز — سایت، دیتابیس، ورود کاربران — روی هاست خودتان است.

```
┌──────────────────────────────────────────────┐
│              هاست شما (cPanel)               │
│                                              │
│  index.html ←→ api/*.php ←→ MySQL/PostgreSQL │
│   (سامانه)     (بک‌اند)       (دیتابیس)      │
│                                              │
│   هیچ داده‌ای از این جعبه بیرون نمی‌رود       │
└──────────────────────────────────────────────┘
```

---

## چه هاستی لازم دارم؟

هر هاست اشتراکی معمولی ایرانی یا خارجی که این‌ها را داشته باشد:

| مورد | حداقل | توضیح |
|---|---|---|
| PHP | ۸٫۰ به بالا | تقریبا همه‌ی هاست‌ها دارند |
| MySQL / MariaDB | ۵٫۷ / ۱۰٫۳ به بالا | استاندارد cPanel |
| **یا** PostgreSQL | ۱۲ به بالا | اگر هاستتان دارد |
| افزونه curl | — | فقط برای ربات تلگرام لازم است |
| فضا | ۵۰ مگابایت | سامانه ۲ مگابایت است، بقیه برای داده |
| SSL | رایگان (Let's Encrypt) | تقریبا همه می‌دهند |

**نیازی به VPS، Docker یا دانش فنی خاصی نیست.** ارزان‌ترین پلن هاست کافی است.

---

## مرحله ۱ — ساخت دیتابیس در هاست

> **MySQL یا PostgreSQL؟**
> سامانه با هر دو کار می‌کند و نصاب هر دو را پشتیبانی می‌کند.
> اگر شک دارید MySQL بگیرید — روی تقریبا همه‌ی هاست‌های اشتراکی هست.
> برای PostgreSQL معمولا به VPS یا هاستی که صریحا PostgreSQL دارد نیاز است.
> مراحل زیر برای MySQL نوشته شده؛ برای PostgreSQL در cPanel بخش
> **PostgreSQL Databases** را باز کنید و دقیقا همین کارها را انجام دهید
> (پورت پیش‌فرض ۵۴۳۲ به‌جای ۳۳۰۶).

۱. وارد **cPanel** شوید
۲. بخش **MySQL® Databases** را باز کنید
۳. یک دیتابیس بسازید، مثلا: `erp`
   (cPanel خودش پیشوند اضافه می‌کند، مثلا `username_erp`)
۴. پایین‌تر یک **کاربر جدید** بسازید و رمز قوی بگذارید
۵. در بخش **Add User To Database** کاربر را به دیتابیس وصل کنید
   و **ALL PRIVILEGES** را تیک بزنید

این چهار مقدار را یادداشت کنید — در مرحله ۳ لازم می‌شوند:
```
نام دیتابیس :  username_erp
کاربر       :  username_erpuser
رمز         :  ........
سرور        :  localhost
```

---

## مرحله ۲ — آپلود فایل‌ها

۱. در cPanel → **File Manager** → پوشه‌ی `public_html`
۲. فایل زیپ را آپلود و همان‌جا **Extract** کنید

ساختار نهایی باید این شکلی باشد:

```
public_html/
├── index.html          ← سامانه
├── erp-api.js          ← لایه اتصال به بک‌اند
├── install.php         ← نصاب (بعد از نصب پاک می‌شود)
├── api/                ← بک‌اند PHP
│   ├── auth.php
│   ├── data.php
│   ├── rpc.php
│   ├── changes.php
│   ├── upload.php
│   ├── lib.php
│   ├── policies.php
│   └── .htaccess
├── database/
│   └── mysql_schema.sql
├── uploads/            ← تصاویر امضا (خودکار ساخته می‌شود)
└── vendor/             ← کتابخانه‌ها و فونت
```

⚠️ پوشه‌ی `vendor` را حتما ببرید، وگرنه صفحه سفید می‌ماند.

---

## مرحله ۳ — نصب با یک کلیک

در مرورگر باز کنید:

```
https://yourdomain.ir/install.php
```

نصاب خودش:
- پیش‌نیازهای هاست را بررسی می‌کند
- ۴۹ جدول دیتابیس را می‌سازد
- سمت‌های سازمانی و گردش کارهای پیش‌فرض را وارد می‌کند
- کاربر مدیر سیستم شما را می‌سازد
- فایل تنظیمات را می‌نویسد

فقط اطلاعات مرحله ۱ و یک نام کاربری/رمز برای خودتان وارد کنید.

### ⚠️ بلافاصله بعد از نصب

فایل **`install.php`** را از هاست **پاک کنید**.
تا وقتی روی سرور باشد، کسی می‌تواند دوباره نصب را اجرا کند.

---

## مرحله ۴ — ورود

```
https://yourdomain.ir
```

با همان نام کاربری و رمزی که در نصاب گذاشتید وارد شوید.
بقیه‌ی کاربران را از داخل سامانه بسازید:
**مدیریت ← مدیریت کاربران**

---

## مرحله ۵ — فعال کردن HTTPS (مهم)

در cPanel → **SSL/TLS Status** → **Run AutoSSL**

سپس برای اینکه سایت همیشه روی `https` باز شود، فایلی به نام
`.htaccess` در `public_html` بسازید با این محتوا:

```apache
RewriteEngine On
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

# جلوگیری از دیدن فهرست فایل‌ها
Options -Indexes
```

> بدون HTTPS، رمز کاربران هنگام ورود رمزنگاری نمی‌شود. این مرحله را رد نکنید.

---

## پشتیبان‌گیری

### روش ساده (پنل هاست)
cPanel → **Backup** → **Download a MySQL Database Backup**

### روش خودکار (پیشنهادی)
cPanel → **Cron Jobs** → یک زمان‌بندی روزانه بسازید:

```bash
mysqldump -u USER -pPASSWORD DBNAME > ~/backups/erp_$(date +\%Y\%m\%d).sql
```

و برای پاک کردن بک‌آپ‌های قدیمی‌تر از ۳۰ روز:
```bash
find ~/backups -name "erp_*.sql" -mtime +30 -delete
```

⚠️ یک بار بازیابی را تست کنید. بک‌آپی که تست نشده، بک‌آپ نیست.

---

## اتصال Power BI

چون دیتابیس MySQL روی هاست شماست، Power BI مستقیم وصل می‌شود.

### گام ۱ — اجازه دسترسی از بیرون
cPanel → **Remote MySQL** → IP دفتر خود را اضافه کنید

> هرگز `%` (یعنی همه) را وارد نکنید — دیتابیس‌تان روی کل اینترنت باز می‌شود.

### گام ۲ — کاربر فقط‌خواندنی بسازید
در **phpMyAdmin** → سربرگ **SQL**:

```sql
CREATE USER 'powerbi'@'%' IDENTIFIED BY 'یک-رمز-قوی';
GRANT SELECT ON `نام_دیتابیس`.* TO 'powerbi'@'%';
REVOKE SELECT ON `نام_دیتابیس`.`bot_config`      FROM 'powerbi'@'%';
REVOKE SELECT ON `نام_دیتابیس`.`app_users`       FROM 'powerbi'@'%';
REVOKE SELECT ON `نام_دیتابیس`.`app_sessions`    FROM 'powerbi'@'%';
REVOKE SELECT ON `نام_دیتابیس`.`user_signatures` FROM 'powerbi'@'%';
FLUSH PRIVILEGES;
```

### گام ۳ — ویوهای آماده گزارش‌گیری
```sql
CREATE OR REPLACE VIEW v_production AS
SELECT `date`, line, shift, operator, production, waste,
       CASE WHEN production + waste > 0
            THEN ROUND(waste / (production + waste) * 100, 2) ELSE 0 END AS waste_rate_pct,
       status
FROM daily_reports;

CREATE OR REPLACE VIEW v_stops AS
SELECT stop_date, line, shift, stop_type, duration_min, reason FROM production_stops;

CREATE OR REPLACE VIEW v_packaging AS
SELECT report_date, shift, thickness, pallet_serial, net_weight,
       pallet_weight, qc_powder, qc_spot, qc_wave, status
FROM packaging_reports;

GRANT SELECT ON `نام_دیتابیس`.v_production TO 'powerbi'@'%';
GRANT SELECT ON `نام_دیتابیس`.v_stops      TO 'powerbi'@'%';
GRANT SELECT ON `نام_دیتابیس`.v_packaging  TO 'powerbi'@'%';
```

### گام ۴ — در Power BI Desktop
`Get Data` → **MySQL database**

```
Server   : yourdomain.ir:3306
Database : نام_دیتابیس
Username : powerbi
```

> اگر Power BI درایور خواست: «MySQL Connector/NET» را از سایت MySQL نصب کنید.

---

## تفاوت‌ها با نسخه‌ی Supabase

| قابلیت | وضعیت در این نسخه |
|---|---|
| کل سامانه و ماژول‌ها | ✅ بدون تغییر |
| ورود کاربران و سطح دسترسی | ✅ کار می‌کند (در PHP پیاده شده) |
| گردش کار تأیید | ✅ کار می‌کند |
| امضای دیجیتال | ✅ تصاویر در پوشه‌ی uploads |
| به‌روزرسانی زنده بین کاربران | ✅ با بررسی هر ۲۰ ثانیه (به‌جای WebSocket) |
| ربات تلگرام | ✅ داخل پکیج است (`bot/telegram.php`) — راهنمای «راهنمای-ربات-تلگرام.txt» |
| بک‌آپ خودکار در فضای ابری | ❌ به‌جایش از Cron هاست استفاده کنید |

---

## عیب‌یابی

| نشانه | علت | راه‌حل |
|---|---|---|
| صفحه سفید | پوشه `vendor` آپلود نشده | پوشه را کنار index.html بگذارید |
| «خطای داخلی سرور» | اطلاعات دیتابیس اشتباه | `api/config.php` را بررسی کنید |
| «برای این کار باید وارد شوید» | نشست منقضی شده | دوباره وارد شوید |
| خطای ۵۰۰ روی api | نسخه PHP قدیمی | در پنل هاست PHP را روی ۸٫۰+ بگذارید |
| حساب قفل شد | ۵ بار رمز اشتباه | ۱۵ دقیقه صبر کنید |
| فونت فارسی خراب | فونت آپلود نشده | `vendor/fonts/` را بررسی کنید |

برای دیدن جزئیات خطا: cPanel → **Errors** یا فایل `error_log` در پوشه‌ی سایت.

---

## چک‌لیست امنیتی

- [ ] `install.php` پاک شده است
- [ ] HTTPS فعال است و سایت به آن هدایت می‌شود
- [ ] رمز دیتابیس قوی است (نه `123456`)
- [ ] در Remote MySQL فقط IP دفتر اضافه شده، نه `%`
- [ ] کاربر `powerbi` فقط `SELECT` دارد
- [ ] بک‌آپ روزانه فعال و **یک بار تست شده**
- [ ] رمز کاربر مدیر قوی است
