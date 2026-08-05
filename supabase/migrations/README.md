# مهاجرت‌های دیتابیس

## `0001_full_schema.sql` — ساختار کامل، آماده‌ی اجرا

این فایل خروجی **واقعی** از ساختار زنده‌ی دیتابیس عملیاتی است (نه بازنویسی
دستی) — همه‌ی ۴۷ جدول، کلیدها، ایندکس‌ها، RLS، ۳۳ تابع امن و ۸ تریگر.
اجرای آن روی یک Postgres/Supabase خالی، دقیقاً همین ساختار را می‌سازد،
**بدون هیچ داده‌ی کسب‌وکاری** — نه کاربر، نه گزارش، نه فاکتور — فقط چند
ردیف تنظیمات پایه (سمت‌های سازمانی و گردش کار پیش‌فرض) تا کاربران واقعی
از صفر شروع به وارد کردن اطلاعات کنند.

قبل از اجرا، فایل را باز کنید و تنها یک خط را ویرایش کنید: در تابع
`forward_notification_to_telegram`، مقدار `<YOUR_PROJECT_URL>` را با
آدرس واقعی پروژه‌ی جدید جایگزین کنید.

**پیش‌نیاز:** یک Postgres با schema به نام `auth` (یعنی Supabase — ابری
یا خودمیزبان). روی Postgres ساده یا MySQL اجرا نمی‌شود، چون `auth.uid()`
و `auth.users` در تمام RLS policyها استفاده شده‌اند.

```bash
psql "postgresql://postgres:[PASSWORD]@[HOST]:5432/postgres" \
  -v ON_ERROR_STOP=1 -f supabase/migrations/0001_full_schema.sql
```

> این فایل قبل از commit، به‌طور کامل روی یک Postgres 16 خالی (با شبیه‌ساز
> schema `auth` و نقش‌های `anon`/`authenticated`/`service_role`) اجرا و
> تعداد جدول‌ها، policyها، ایندکس‌ها و constraintها با دیتابیس عملیاتی
> مو‌به‌مو مقایسه شده است.

پس از اجرا، اولین کاربر مدیر سیستم را طبق بخش پایانی همان فایل بسازید.

## گرفتن خروجی جدید (بعد از تغییرات آینده)

اگر بعداً جدول/تابع/policy جدیدی اضافه کردید، برای به‌روزرسانی این فایل:

```bash
pg_dump "postgresql://postgres:[PASSWORD]@db.[REF].supabase.co:5432/postgres" \
  --schema-only --no-owner --no-privileges -f schema.sql
```

خلاصه‌ی جدول‌ها، policyها و توابع در [`../../docs/DATABASE.md`](../../docs/DATABASE.md) مستند شده است.

## هنگام افزودن جدول جدید
1. `ALTER TABLE ... ENABLE ROW LEVEL SECURITY;` و نوشتن policy
2. افزودن به `TABLE_MAP` در `index.html`
3. افزودن به آرایه‌ی `TABLES` در `supabase/functions/daily-backup/index.ts`
4. افزودن ستون‌ها/جدول به `0001_full_schema.sql` تا نصب تازه هم‌گام بماند

## نکته
جدول `gt_site` در دیتابیس عملیاتی دیده شد که در هیچ‌جای این پروژه
(`index.html`، مستندات، Edge Functionها) استفاده نشده — به همین دلیل
عمداً از این فایل حذف شده است. اگر می‌دانید مربوط به چیست نگهش دارید،
در غیر این صورت بی‌خطر است که از دیتابیس عملیاتی هم حذفش کنید.
