# راهنمای نصب روی ویندوز سرور — سامانه ERP پیشگامان صنعت سبز

---

## اول این را بخوانید (مهم)

سامانه از دو تکه‌ی جدا تشکیل شده:

```
┌────────────────────────┐        ┌──────────────────────────┐
│   سایت (index.html)    │ ─────► │  دیتابیس + ورود کاربران  │
│   روی IIS ویندوز       │  HTTPS │  (PostgreSQL + Supabase) │
└────────────────────────┘        └──────────────────────────┘
        دامنه شما                     یا ابری، یا روی همین سرور
```

نکته‌ای که باید بدانید: **دیتابیس شما از همان اول SQL واقعی است**
(PostgreSQL). اما سامانه فقط به «دیتابیس» وصل نمی‌شود — به سه چیز وصل
می‌شود که با هم می‌آیند:

| تکه | کارش چیست | بدون آن چه می‌شود |
|---|---|---|
| **PostgreSQL** | نگهداری داده‌ها | هیچ داده‌ای ذخیره نمی‌شود |
| **Auth** | ورود با نام کاربری و رمز | کسی نمی‌تواند وارد شود |
| **RLS** | هرکس فقط داده‌ی مجاز خودش را ببیند | امنیت دسترسی از بین می‌رود |

این سه تکه را **Supabase** فراهم می‌کند (که خودش متن‌باز است و می‌تواند
روی سرور خودتان نصب شود). پس دو مسیر دارید:

---

## کدام مسیر برای شما؟

### 🟢 مسیر ۱ — ساده و سریع (پیشنهاد من برای شروع)
**سایت روی ویندوز سرور خودتان + دیتابیس روی Supabase ابری**

- ⏱ زمان نصب: حدود ۳۰ دقیقه
- 💰 هزینه: رایگان (پلن رایگان Supabase)
- ✅ دامنه‌ی خودتان، SSL، Power BI — همه کار می‌کند
- ⚠️ داده‌ها روی سرور Supabase است، نه سرور شما

### 🔵 مسیر ۲ — همه‌چیز روی سرور خودتان
**سایت + دیتابیس + ورود کاربران، همه روی ویندوز سرور**

- ⏱ زمان نصب: نصف روز تا یک روز
- 💰 هزینه: فقط سرور خودتان
- ✅ هیچ داده‌ای از سرور شما خارج نمی‌شود
- ⚠️ نگهداری، به‌روزرسانی امنیتی و پشتیبان‌گیری با شماست

> **صادقانه:** «روی سرور خودم» به‌معنی «امن‌تر» نیست.
> Supabase ابری توسط تیم حرفه‌ای امن نگه داشته می‌شود. سرور خودتان
> وقتی امن است که کسی مرتب پچ امنیتی بزند و فایروال را درست تنظیم کند.
> اگر الزام قانونی/سازمانی برای نگهداری داده داخل کشور ندارید، مسیر ۱
> هم امن است و هم دردسر کمتری دارد.

---

# 🟢 مسیر ۱ — نصب ساده

## گام ۱ — نصب IIS روی ویندوز سرور

در **Server Manager** → Add Roles and Features → Web Server (IIS)

یا سریع‌تر، در PowerShell با دسترسی Administrator:

```powershell
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
Install-WindowsFeature Web-Static-Content, Web-Default-Doc, Web-Http-Compression-Static
```

تست: در مرورگر سرور به `http://localhost` بروید — باید صفحه‌ی IIS بیاید.

---

## گام ۲ — کپی فایل‌های سایت

۱. پوشه بسازید: `C:\inetpub\erp`
۲. از این پکیج کپی کنید:
   - `app\index.html`  →  `C:\inetpub\erp\index.html`
   - `app\vendor\`     →  `C:\inetpub\erp\vendor\`
   - `iis\web.config`  →  `C:\inetpub\erp\web.config`

⚠️ پوشه‌ی `vendor` را حتماً ببرید. بدون آن، اگر سرور به اینترنت
دسترسی نداشته باشد صفحه سفید می‌ماند.

ساختار نهایی باید این شکلی باشد:
```
C:\inetpub\erp\
├── index.html
├── web.config
└── vendor\
    ├── chart.umd.js
    ├── supabase.min.js
    ├── xlsx.full.min.js
    └── fonts\Vazirmatn.woff2
```

---

## گام ۳ — ساخت سایت در IIS

**IIS Manager** را باز کنید → روی **Sites** راست‌کلیک → **Add Website**

| فیلد | مقدار |
|---|---|
| Site name | `ERP` |
| Physical path | `C:\inetpub\erp` |
| Binding type | `http` |
| Port | `80` |
| Host name | `erp.yourdomain.ir` (دامنه‌ی خودتان) |

**OK** بزنید.

---

## گام ۴ — وصل کردن دامنه

در پنل ثبت دامنه (ایرنیک، یا هرجا خریدید) یک رکورد بسازید:

| نوع | نام | مقدار |
|---|---|---|
| `A` | `erp` | IP سرور ویندوزی شما |

تا چند دقیقه تا چند ساعت طول می‌کشد تا در اینترنت پخش شود.

بررسی: در PowerShell سرور بزنید `nslookup erp.yourdomain.ir`

---

## گام ۵ — نصب گواهی SSL (https)

ساده‌ترین راه رایگان روی ویندوز: **win-acme**

۱. دانلود از https://www.win-acme.com/
۲. فایل را باز کنید و `wacs.exe` را با دسترسی Administrator اجرا کنید
۳. گزینه `N` (ساخت گواهی جدید) → سایت `ERP` را انتخاب کنید
۴. تا آخر Enter بزنید — گواهی خودکار نصب و **هر ۶۰ روز خودکار تمدید** می‌شود

بعد از نصب گواهی، در `web.config` بخش «هدایت http به https» را از حالت
کامنت خارج کنید (توضیحش داخل خود فایل نوشته شده).

⚠️ برای کار کردن آن بخش باید افزونه‌ی **URL Rewrite Module** هم نصب باشد:
https://www.iis.net/downloads/microsoft/url-rewrite

---

## گام ۶ — تمام

آدرس `https://erp.yourdomain.ir` را باز کنید. صفحه‌ی ورود باید بیاید.
با کاربری که از قبل دارید وارد شوید.

---

# 🔵 مسیر ۲ — همه‌چیز روی سرور خودتان

گام‌های ۱ تا ۵ بالا را انجام دهید (IIS، فایل‌ها، دامنه، SSL)،
سپس راهنمای کامل را از این فایل دنبال کنید:

```
docker\README.md
```

آنجا نصب Docker، بالا آوردن Supabase، نصب ساختار دیتابیس و وصل کردن
سامانه به سرور خودتان مرحله‌به‌مرحله نوشته شده است.

---

# 📊 اتصال Power BI به دیتابیس

این بخش در **هر دو مسیر** کار می‌کند.

## گام ۱ — ساخت کاربر فقط‌خواندنی

هرگز با کاربر `postgres` به Power BI وصل نشوید. یک کاربر محدود بسازید
(در SQL Editor سوپابیس یا با pgAdmin):

```sql
CREATE USER powerbi WITH PASSWORD 'یک-رمز-قوی-بگذارید';

GRANT CONNECT ON DATABASE postgres TO powerbi;
GRANT USAGE ON SCHEMA public TO powerbi;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO powerbi;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO powerbi;

-- برای گزارش‌گیری باید همه‌ی سطرها دیده شوند
ALTER USER powerbi BYPASSRLS;

-- جدول‌های حساس را استثنا کنید
REVOKE ALL ON public.bot_config      FROM powerbi;
REVOKE ALL ON public.user_signatures FROM powerbi;
```

## گام ۲ — ویوهای آماده‌ی گزارش‌گیری

```sql
CREATE OR REPLACE VIEW public.v_production AS
SELECT d.date, d.line, d.shift, d.operator,
       d.production, d.waste,
       CASE WHEN d.production + d.waste > 0
            THEN round(d.waste / (d.production + d.waste) * 100, 2)
            ELSE 0 END AS waste_rate_pct,
       d.status
FROM public.daily_reports d;

CREATE OR REPLACE VIEW public.v_stops AS
SELECT s.stop_date, s.line, s.shift, s.stop_type, s.duration_min, s.reason
FROM public.production_stops s;

CREATE OR REPLACE VIEW public.v_packaging AS
SELECT p.report_date, p.shift, p.thickness, p.pallet_serial,
       p.net_weight, p.pallet_weight, p.qc_powder, p.qc_spot, p.qc_wave, p.status
FROM public.packaging_reports p;

CREATE OR REPLACE VIEW public.v_hr_attendance AS
SELECT a.att_date, e.first_name || ' ' || e.last_name AS employee,
       e.department, a.status, a.overtime_min, a.delay_min
FROM public.hr_attendance a
JOIN public.hr_employees e ON e.id = a.employee_id;

GRANT SELECT ON public.v_production, public.v_stops,
                public.v_packaging, public.v_hr_attendance TO powerbi;
```

## گام ۳ — اتصال از Power BI Desktop

`Get Data` → `PostgreSQL database`

| فیلد | مقدار (مسیر ۱ — ابری) | مقدار (مسیر ۲ — سرور خودتان) |
|---|---|---|
| Server | `db.xxxxx.supabase.co:5432` | `localhost:5432` یا IP سرور |
| Database | `postgres` | `postgres` |
| Username | `powerbi` | `powerbi` |

- حالت **Import** → گزارش سریع‌تر
- حالت **DirectQuery** → داده‌ی زنده

> اگر Power BI خطای SSL داد، در تنظیمات اتصال گزینه‌ی
> `Encrypt connection` را تیک بزنید.

---

# ❓ عیب‌یابی

| نشانه | علت محتمل | راه‌حل |
|---|---|---|
| صفحه سفید می‌ماند | پوشه‌ی `vendor` کپی نشده | پوشه را کنار `index.html` بگذارید |
| پیام «کتابخانه‌ها بارگذاری نشد» | همان بالا | همان بالا |
| خطای 500.19 در IIS | افزونه URL Rewrite نصب نیست | یا نصبش کنید یا بخش rewrite را در `web.config` کامنت بگذارید |
| فونت‌ها مربع شده | نوع MIME فونت تعریف نشده | `web.config` را کپی کنید (داخلش هست) |
| ورود کار نمی‌کند | آدرس/کلید Supabase اشتباه | دو خط اول اسکریپت در `index.html` را بررسی کنید |
| داده‌ها خالی است | سطح دسترسی کاربر | در «مدیریت کاربران» دسترسی را بررسی کنید |
| ربات تلگرام جواب نمی‌دهد | سرور ایرانی به تلگرام دسترسی ندارد | پروکسی، یا نگه‌داشتن ربات روی Supabase ابری |

---

# 🔐 چک‌لیست امنیتی

- [ ] گواهی SSL نصب و `https` فعال است
- [ ] رمز کاربر پیش‌فرض عوض شده
- [ ] پورت دیتابیس (۵۴۳۲) روی اینترنت باز نیست
- [ ] کاربر `powerbi` فقط `SELECT` دارد (نه نوشتن)
- [ ] پشتیبان‌گیری شبانه فعال و **یک بار تست شده**
- [ ] به‌روزرسانی‌های ویندوز سرور نصب می‌شوند
- [ ] فقط افراد لازم به سرور دسترسی Remote Desktop دارند

---

# 📁 محتویات این پکیج

```
├── README-FIRST.txt              ← خلاصه‌ی سریع
├── INSTALL-WINDOWS.md            ← همین فایل
├── app\
│   ├── index.html                ← کل سامانه
│   └── vendor\                   ← کتابخانه‌ها و فونت (لازم)
├── database\
│   ├── 00_compat_plain_postgres.sql    ← فقط برای PostgreSQL ساده
│   ├── 01_full_schema.sql              ← ساختار کامل (برای Supabase)
│   ├── 01b_full_schema_plain_postgres.sql ← همان، برای PostgreSQL ساده
│   ├── 02_first_admin.sql              ← ساخت کاربر مدیر
│   └── README.md
├── iis\web.config                ← تنظیمات IIS
├── docker\README.md              ← نصب Supabase روی سرور خودتان
├── edge-functions\               ← توابع سمت سرور (ربات، پشتیبان‌گیری)
└── scripts\
    ├── 1-install-database.bat    ← نصب خودکار دیتابیس
    ├── 2-create-admin.bat        ← ساخت کاربر مدیر
    └── 3-backup-database.bat     ← پشتیبان‌گیری (قابل زمان‌بندی)
```
