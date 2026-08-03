# راهنمای راه‌اندازی (هاست، دامنه، سرور)

این سند سه سناریوی استقرار را پوشش می‌دهد. اگر تازه شروع می‌کنید، **سناریوی ۱** ساده‌ترین و سریع‌ترین است.

---

## نکته‌ی کلیدی پیش از شروع

رابط کاربری یک **فایل استاتیک** است. یعنی:

- به Node.js، PHP یا سرور اپلیکیشن **نیاز ندارد**
- روی ارزان‌ترین هاست اشتراکی هم اجرا می‌شود
- فضای مورد نیاز: کمتر از ۱ مگابایت
- دیتابیس جداگانه روی Supabase است و ربطی به هاست ندارد

---

## سناریوی ۱ — هاست اشتراکی + دامنه (ساده‌ترین)

### ۱. خرید دامنه
| نوع | مزیت | ملاحظه |
|---|---|---|
| `.ir` | ارزان، پرداخت ریالی، ثبت از ایرنیک | مناسب شرکت داخلی |
| `.com` | بین‌المللی | نیاز به کارت ارزی |

### ۲. خرید هاست
- کمترین پلن هاست اشتراکی با **cPanel** کافی است
- **الزامی:** پشتیبانی از `SSL/HTTPS` (تقریباً همه رایگان می‌دهند)
- بدون HTTPS، مرورگر ورود کاربران را ناامن اعلام می‌کند

### ۳. آپلود
1. وارد cPanel → **File Manager**
2. به پوشه‌ی `public_html` بروید
3. فایل `index.html` را آپلود کنید
4. تمام — سایت روی `https://yourdomain.ir` بالا می‌آید

### ۴. فعال‌سازی SSL
cPanel → **SSL/TLS Status** → گزینه‌ی `Run AutoSSL`
(یا از بخش Let's Encrypt هاست)

### ۵. اتصال دامنه به هاست
در پنل ثبت دامنه، **نیم‌سرورهای (Nameservers)** هاست را وارد کنید. معمولاً فروشنده‌ی هاست این کار را انجام می‌دهد.

---

## سناریوی ۲ — سرور مجازی اختصاصی (VPS)

مناسب وقتی می‌خواهید **داده‌ها روی سرور خودتان** باشد یا **Power BI** را مستقیم به دیتابیس وصل کنید.

### مشخصات پیشنهادی سرور
| مورد | حداقل |
|---|---|
| سیستم‌عامل | Ubuntu 22.04 / 24.04 |
| CPU | ۴ هسته |
| RAM | ۸ گیگابایت |
| دیسک | ۱۰۰ گیگابایت SSD |
| شبکه | IP اختصاصی |

### معماری پیشنهادی: Supabase خودمیزبان

Supabase متن‌باز است و کامل روی سرور خودتان نصب می‌شود. مزیت بزرگ: **کد برنامه تقریباً بدون تغییر کار می‌کند** (فقط آدرس و کلید عوض می‌شود) و همه‌ی امکانات — احراز هویت، RLS، توابع، گردش کار — حفظ می‌شوند.

```bash
# نصب Docker
curl -fsSL https://get.docker.com | sh

# دریافت Supabase
git clone --depth 1 https://github.com/supabase/supabase
cd supabase/docker
cp .env.example .env

# ⚠️ حتماً رمزهای داخل .env را عوض کنید:
#    POSTGRES_PASSWORD, JWT_SECRET, ANON_KEY,
#    SERVICE_ROLE_KEY, DASHBOARD_PASSWORD
nano .env

docker compose up -d
```

### انتقال داده‌ها از Supabase ابری به سرور

```bash
# خروجی کامل از پروژه‌ی فعلی
pg_dump "postgresql://postgres:[PASSWORD]@db.[REF].supabase.co:5432/postgres" \
  --no-owner --no-privileges -Fc -f backup.dump

# بازیابی روی سرور جدید
pg_restore -d "postgresql://postgres:[NEW_PASSWORD]@localhost:5432/postgres" \
  --no-owner --no-privileges backup.dump
```

### وب‌سرور و SSL

```bash
apt update && apt install -y nginx certbot python3-certbot-nginx

# قرار دادن فایل سایت
mkdir -p /var/www/erp
cp index.html /var/www/erp/

# پیکربندی nginx
cat > /etc/nginx/sites-available/erp <<'EOF'
server {
    listen 80;
    server_name yourdomain.ir www.yourdomain.ir;
    root /var/www/erp;
    index index.html;
    location / { try_files $uri $uri/ /index.html; }
}
EOF

ln -sf /etc/nginx/sites-available/erp /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# گواهی SSL رایگان (تمدید خودکار)
certbot --nginx -d yourdomain.ir -d www.yourdomain.ir
```

### فایروال

```bash
ufw allow 22/tcp      # SSH
ufw allow 80/tcp      # HTTP
ufw allow 443/tcp     # HTTPS
ufw enable
```

> **پورت ۵۴۳۲ (دیتابیس) را روی اینترنت باز نکنید.** برای Power BI بخش بعد را ببینید.

### ⚠️ نکته درباره‌ی سرور ایرانی و ربات تلگرام

سرورهای داخل ایران به `api.telegram.org` دسترسی ندارند. اگر سرور ایرانی می‌گیرید:

- **راه ۱:** پروکسی روی سرور تنظیم کنید تا توابع ربات به تلگرام برسند
- **راه ۲:** ربات را روی همان Supabase ابری نگه دارید و فقط دیتابیس اصلی را به سرور منتقل کنید

بقیه‌ی سامانه (سایت، دیتابیس، Power BI) روی سرور ایرانی بدون مشکل کار می‌کند.

---

## اتصال Power BI

### ۱. ساخت کاربر فقط‌خواندنی

هرگز با کاربر `postgres` به Power BI وصل نشوید. یک کاربر محدود بسازید:

```sql
CREATE USER powerbi WITH PASSWORD 'یک-رمز-قوی';

GRANT CONNECT ON DATABASE postgres TO powerbi;
GRANT USAGE ON SCHEMA public TO powerbi;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO powerbi;

-- جدول‌هایی که بعداً ساخته می‌شوند هم خواندنی باشند
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO powerbi;

-- برای گزارش‌گیری باید همه‌ی سطرها دیده شوند
ALTER USER powerbi BYPASSRLS;

-- جدول‌های حساس را استثنا کنید
REVOKE ALL ON public.bot_config FROM powerbi;
REVOKE ALL ON public.user_signatures FROM powerbi;
```

### ۲. محدودکردن دسترسی به IP دفتر

در فایل `pg_hba.conf`:
```
hostssl  postgres  powerbi  <IP-دفتر>/32  scram-sha-256
```

### ۳. اتصال از Power BI Desktop

```
Get Data → PostgreSQL database
Server:   yourdomain.ir:5432   (یا IP سرور)
Database: postgres
Username: powerbi
```

- حالت **Import** برای گزارش‌های سریع
- حالت **DirectQuery** برای داده‌ی زنده

### ۴. ویوهای آماده‌ی گزارش‌گیری (اختیاری ولی مفید)

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
SELECT s.stop_date, s.line, s.shift, s.stop_type,
       s.duration_min, s.reason
FROM public.production_stops s;

CREATE OR REPLACE VIEW public.v_hr_attendance AS
SELECT a.att_date, e.first_name || ' ' || e.last_name AS employee,
       e.department, a.status, a.overtime_min, a.delay_min
FROM public.hr_attendance a
JOIN public.hr_employees e ON e.id = a.employee_id;

GRANT SELECT ON public.v_production, public.v_stops, public.v_hr_attendance TO powerbi;
```

---

## سناریوی ۳ — GitHub Pages (رایگان، برای تست)

1. Settings → **Pages**
2. Source: `Deploy from a branch`
3. Branch: شاخه‌ی مورد نظر — Folder: `/ (root)`
4. آدرس: `https://<username>.github.io/<repo>/`

> برای مخزن خصوصی نیاز به پلن پولی گیت‌هاب دارد. برای محیط عملیاتی، سناریوی ۱ یا ۲ توصیه می‌شود.

---

## چک‌لیست پیش از بهره‌برداری

- [ ] HTTPS فعال و گواهی معتبر است
- [ ] رمز کاربران پیش‌فرض عوض شده
- [ ] توکن ربات تلگرام و کلید هوش مصنوعی چرخانده شده (اگر جایی به اشتراک گذاشته شده)
- [ ] بک‌آپ شبانه فعال و تست‌شده است
- [ ] دسترسی دیتابیس فقط از IPهای مجاز
- [ ] یک بار کل چرخه تست شده: ثبت فرم ← تأیید ← گزارش ← نمودار

---

## عیب‌یابی

| مشکل | علت محتمل | راه‌حل |
|---|---|---|
| صفحه سفید می‌ماند | کتابخانه‌های CDN لود نشده | کتابخانه‌ها را داخل فایل جاسازی کنید |
| ورود کار نمی‌کند | آدرس/کلید Supabase اشتباه | مقادیر ابتدای `index.html` را بررسی کنید |
| داده‌ها خالی است | RLS اجازه نمی‌دهد | سطح دسترسی کاربر را در «مدیریت کاربران» بررسی کنید |
| ربات پاسخ نمی‌دهد | وب‌هوک ثبت نشده | [TELEGRAM-BOT.md](TELEGRAM-BOT.md) را ببینید |
| فونت فارسی درست نیست | فونت جاسازی نشده | فونت را به‌صورت base64 در CSS اضافه کنید |
