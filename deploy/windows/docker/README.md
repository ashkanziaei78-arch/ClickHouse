# نصب Supabase روی ویندوز سرور (همه‌چیز روی سرور خودتان)

این مسیر وقتی لازم است که می‌خواهید **هم دیتابیس و هم سیستم ورود کاربران**
روی سرور خودتان باشد و هیچ داده‌ای بیرون نرود.

> اگر فقط دیتابیس SQL برای Power BI می‌خواهید و سامانه را روی Supabase ابری
> نگه می‌دارید، این پوشه را لازم ندارید — به `INSTALL-WINDOWS.md` مسیر ۱ بروید.

---

## پیش‌نیازها

| مورد | حداقل |
|---|---|
| ویندوز سرور | 2019 یا 2022 (یا Windows 10/11 Pro) |
| RAM | ۸ گیگابایت |
| دیسک | ۱۰۰ گیگابایت SSD |
| Docker Desktop | آخرین نسخه + WSL2 فعال |
| Git for Windows | برای دریافت فایل‌های Supabase |

---

## مرحله ۱ — نصب Docker Desktop

۱. دانلود از: https://www.docker.com/products/docker-desktop/
۲. هنگام نصب، گزینه‌ی **Use WSL 2 instead of Hyper-V** را تیک بزنید
۳. بعد از نصب، ویندوز را ری‌استارت کنید
۴. در PowerShell تست کنید:

```powershell
docker --version
docker compose version
```

> اگر خطای WSL دیدید، در PowerShell با دسترسی Administrator اجرا کنید:
> ```powershell
> wsl --install
> wsl --update
> ```

---

## مرحله ۲ — دریافت Supabase

```powershell
cd C:\
git clone --depth 1 https://github.com/supabase/supabase
cd C:\supabase\docker
copy .env.example .env
```

---

## مرحله ۳ — ساخت کلیدهای امنیتی

⚠️ **مهم‌ترین مرحله از نظر امنیت.** اگر کلیدهای پیش‌فرض را عوض نکنید،
هرکسی که آدرس سرور شما را بداند به همه‌ی داده‌ها دسترسی دارد.

فایل `.env` را با Notepad باز کنید و این مقادیر را عوض کنید:

| کلید | چه بگذاریم |
|---|---|
| `POSTGRES_PASSWORD` | یک رمز قوی و طولانی |
| `JWT_SECRET` | رشته‌ی تصادفی حداقل ۳۲ کاراکتر |
| `ANON_KEY` | از سایت پایین بسازید |
| `SERVICE_ROLE_KEY` | از سایت پایین بسازید |
| `DASHBOARD_USERNAME` | نام کاربری پنل مدیریت |
| `DASHBOARD_PASSWORD` | رمز قوی برای پنل مدیریت |
| `SITE_URL` | `https://erp.yourdomain.ir` |

**ساخت ANON_KEY و SERVICE_ROLE_KEY:**
به این صفحه بروید و `JWT_SECRET` خودتان را وارد کنید تا دو کلید بسازد:
https://supabase.com/docs/guides/self-hosting#api-keys

برای ساخت یک رشته‌ی تصادفی امن در PowerShell:
```powershell
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 48 | ForEach-Object {[char]$_})
```

---

## مرحله ۴ — بالا آوردن سرویس‌ها

```powershell
cd C:\supabase\docker
docker compose up -d
```

بار اول چند دقیقه طول می‌کشد (حدود ۲ گیگابایت دانلود).

بررسی وضعیت:
```powershell
docker compose ps
```
همه‌ی ردیف‌ها باید `running` یا `healthy` باشند.

پنل مدیریت: http://localhost:8000
(با `DASHBOARD_USERNAME` و `DASHBOARD_PASSWORD` وارد شوید)

---

## مرحله ۵ — نصب ساختار دیتابیس ERP

در پنل Supabase → **SQL Editor** → New query
محتویات این فایل را کامل کپی و اجرا کنید:

```
database\01_full_schema.sql
```

> ⚠️ فایل `00_compat_plain_postgres.sql` را اینجا **اجرا نکنید** —
> آن فقط برای PostgreSQL ساده است و اینجا ساختار Supabase را خراب می‌کند.

سپس فایل `database\02_first_admin.sql` را (بعد از نوشتن نام کاربری و رمز
دلخواه داخلش) در همان SQL Editor اجرا کنید.

---

## مرحله ۶ — اتصال سامانه به سرور خودتان

فایل `app\index.html` را با Notepad++ باز کنید و این دو خط را پیدا کنید
(نزدیک ابتدای بخش اسکریپت):

```js
const SUPABASE_URL = 'https://xxxxx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGci...';
```

و با مقادیر سرور خودتان جایگزین کنید:

```js
const SUPABASE_URL = 'https://api.yourdomain.ir';   // یا http://IP-سرور:8000
const SUPABASE_ANON_KEY = 'ANON_KEY که در مرحله ۳ ساختید';
```

ذخیره کنید و فایل را در پوشه‌ی سایت IIS بگذارید.

---

## مرحله ۷ — توابع سمت سرور (ربات تلگرام، پشتیبان‌گیری)

پوشه‌ی `edge-functions\` شامل ۵ تابع است. برای نصب:

```powershell
npm install -g supabase
supabase login
supabase functions deploy telegram-bot --no-verify-jwt
supabase functions deploy telegram-notify --no-verify-jwt
supabase functions deploy bot-daily-report --no-verify-jwt
supabase functions deploy daily-backup
supabase functions deploy admin-users
```

> ⚠️ سرورهای داخل ایران به `api.telegram.org` دسترسی ندارند.
> اگر سرور ایرانی است، ربات تلگرام کار نمی‌کند مگر با پروکسی.
> بقیه‌ی سامانه بدون مشکل کار می‌کند.

---

## نگهداری

**پشتیبان‌گیری روزانه:**
```powershell
docker exec supabase-db pg_dump -U postgres --no-owner --no-privileges -Fc postgres > C:\ERP-Backups\erp_%date%.dump
```
این دستور را در **Task Scheduler** ویندوز زمان‌بندی کنید.

**به‌روزرسانی Supabase:**
```powershell
cd C:\supabase\docker
docker compose pull
docker compose up -d
```

**دیدن لاگ خطاها:**
```powershell
docker compose logs -f
```

---

## چک‌لیست امنیتی قبل از بهره‌برداری

- [ ] همه‌ی رمزهای `.env` عوض شده (هیچ مقدار پیش‌فرضی نمانده)
- [ ] پورت ۵۴۳۲ (دیتابیس) روی اینترنت **باز نیست** — فقط از داخل شبکه
- [ ] پورت ۸۰۰۰ پشت HTTPS است، نه مستقیم روی اینترنت
- [ ] فایروال ویندوز فقط پورت‌های ۸۰ و ۴۴۳ را باز گذاشته
- [ ] پشتیبان‌گیری شبانه تست شده (یک بار واقعاً بازیابی کنید)
- [ ] رمز کاربر پیش‌فرض `admin` عوض شده
