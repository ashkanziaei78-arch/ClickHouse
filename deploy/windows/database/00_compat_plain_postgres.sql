-- =====================================================================
-- لایه‌ی سازگاری برای PostgreSQL معمولی روی ویندوز
-- =====================================================================
--
-- ⚠️ این فایل را فقط و فقط وقتی اجرا کنید که PostgreSQL ساده
--    (نصب‌شده با فایل نصب ویندوزی) دارید — نه Supabase.
--
--    اگر Supabase (ابری یا خودمیزبان با Docker) دارید، این فایل را
--    اجرا نکنید؛ Supabase خودش همه‌ی این‌ها را دارد و اجرای این فایل
--    ساختار اصلی آن را خراب می‌کند.
--
-- چه کاری می‌کند؟
--    اسکیمای ERP به چند چیز نیاز دارد که فقط Supabase فراهم می‌کند:
--      • schema به نام auth با جدول auth.users
--      • تابع auth.uid()  → شناسه‌ی کاربر واردشده
--      • schema به نام net → ارسال درخواست HTTP از داخل دیتابیس
--      • نقش‌های anon / authenticated / service_role
--    این فایل معادل‌های ساده‌ی آن‌ها را می‌سازد تا اسکیمای اصلی بدون
--    خطا نصب شود.
--
-- ❗ محدودیت مهم: این لایه فقط «ساختار» را می‌سازد. ورود کاربران و
--    کنترل دسترسی واقعی (RLS) کار نمی‌کند، چون auth.uid() همیشه NULL
--    برمی‌گرداند. یعنی این حالت مناسب است برای:
--      ✔ اتصال Power BI و گزارش‌گیری
--      ✔ آماده‌سازی ساختار برای انتقال بعدی
--      ✘ اجرای خود سامانه‌ی ERP (برای آن Supabase لازم است)
-- =====================================================================


-- ---------------------------------------------------------------------
-- ۱) نقش‌هایی که Supabase به‌صورت پیش‌فرض دارد
-- ---------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN BYPASSRLS;
  END IF;
END
$$;


-- ---------------------------------------------------------------------
-- ۲) schema احراز هویت (معادل ساده‌ی Supabase Auth)
-- ---------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE IF NOT EXISTS auth.users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         text UNIQUE,
  password_hash text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- در Supabase این تابع شناسه‌ی کاربر واردشده را از توکن JWT می‌خواند.
-- اینجا (بدون سرور احراز هویت) همیشه NULL برمی‌گرداند، مگر اینکه
-- برنامه‌ای مقدار app.current_user_id را در session ست کند.
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('app.current_user_id', true), '')::uuid;
$$;

CREATE OR REPLACE FUNCTION auth.role()
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(NULLIF(current_setting('app.current_role', true), ''), 'anon');
$$;

GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
GRANT SELECT ON auth.users TO authenticated, service_role;


-- ---------------------------------------------------------------------
-- ۳) schema شبکه (معادل ساده‌ی افزونه‌ی pg_net)
--    روی ویندوز افزونه‌ی pg_net وجود ندارد؛ این توابع «بی‌اثر» هستند
--    تا تریگر اعلان تلگرام بدون خطا اجرا شود (ولی پیام نمی‌فرستد).
-- ---------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS net;

CREATE OR REPLACE FUNCTION net.http_post(
  url                   text,
  body                  jsonb DEFAULT NULL,
  params                jsonb DEFAULT NULL,
  headers               jsonb DEFAULT NULL,
  timeout_milliseconds  int   DEFAULT 5000
) RETURNS bigint
LANGUAGE sql
AS $$ SELECT 0::bigint $$;

CREATE OR REPLACE FUNCTION net.http_get(
  url                   text,
  params                jsonb DEFAULT NULL,
  headers               jsonb DEFAULT NULL,
  timeout_milliseconds  int   DEFAULT 5000
) RETURNS bigint
LANGUAGE sql
AS $$ SELECT 0::bigint $$;

GRANT USAGE ON SCHEMA net TO anon, authenticated, service_role;


-- ---------------------------------------------------------------------
-- ۴) بررسی نهایی
-- ---------------------------------------------------------------------
DO $$
BEGIN
  RAISE NOTICE '---------------------------------------------';
  RAISE NOTICE 'لایه سازگاری با موفقیت نصب شد.';
  RAISE NOTICE 'حالا فایل 01b_full_schema_plain_postgres.sql را اجرا کنید.';
  RAISE NOTICE '---------------------------------------------';
END
$$;
