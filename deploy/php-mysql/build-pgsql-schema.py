#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ساخت اسکیمای PostgreSQL برای نسخه‌ی هاست شخصی

ورودی : supabase/migrations/0001_full_schema.sql  (نسخه‌ی سوپابیس)
خروجی : deploy/php-mysql/database/pgsql_schema.sql

تفاوت با نسخه‌ی سوپابیس:
  • همه‌ی سیاست‌های RLS حذف می‌شوند (کنترل دسترسی در PHP انجام می‌شود)
  • توابع PL/pgSQL حذف می‌شوند (معادلشان در PHP است)
  • وابستگی به auth.users و auth.uid() حذف می‌شود
  • دو جدول app_users و app_sessions اضافه می‌شود (ورود کاربران)
  • افزونه‌های pg_cron و pg_net لازم نیستند
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / 'supabase' / 'migrations' / '0001_full_schema.sql'
OUT = ROOT / 'deploy' / 'php-mysql' / 'database' / 'pgsql_schema.sql'

sql = SRC.read_text(encoding='utf-8')

# ------------------------------------------------------------ ۱) جدول‌ها
tables = re.findall(r'(CREATE TABLE public\.\w+\s*\(.*?\);)', sql, re.S)
if not tables:
    sys.exit('ERROR: جدولی پیدا نشد')

# جدول gt_site به این پروژه مربوط نیست
tables = [t for t in tables if 'public.gt_site' not in t]

# ------------------------------------------------------- ۲) کلید و ایندکس
constraints = re.findall(r'(ALTER TABLE ONLY public\.\w+ ADD CONSTRAINT [^;]+;)', sql)
constraints = [c for c in constraints if 'gt_site' not in c]
# ارجاع به auth.users وجود ندارد چون Supabase نداریم
constraints = [c for c in constraints if 'auth.users' not in c]

indexes = re.findall(r'(CREATE INDEX \w+ ON public\.\w+ USING btree \([^)]+\);)', sql)
indexes = [i for i in indexes if 'gt_site' not in i]

out = ["""-- =====================================================================
-- سامانه ERP «پیشگامان صنعت سبز» — ساختار دیتابیس برای PostgreSQL
-- =====================================================================
-- این فایل خودکار از اسکیمای اصلی ساخته شده است.
-- مخصوص هاست یا سروری که PostgreSQL دارد (بدون Supabase).
--
-- روش اجرا:
--   psql -U کاربر -d نام_دیتابیس -f pgsql_schema.sql
--   یا در pgAdmin: Query Tool → باز کردن همین فایل → اجرا
--
-- نکته: کنترل دسترسی (که در نسخه‌ی سوپابیس با RLS بود) اینجا در
-- لایه‌ی PHP انجام می‌شود؛ پس هرگز دیتابیس را مستقیم روی اینترنت باز نکنید.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";


-- ---------------------------------------------------------- جدول‌ها
"""]

out.extend(tables)

out.append("\n\n-- ---------------------------------------------- کلیدها و محدودیت‌ها\n")
# ترتیب: اول کلید اصلی و یکتا، بعد بررسی، آخر کلید خارجی
order = {'PRIMARY KEY': 0, 'UNIQUE': 1, 'CHECK': 2, 'FOREIGN KEY': 3}


def rank(c):
    for k, v in order.items():
        if k in c:
            return v
    return 4


for c in sorted(constraints, key=rank):
    out.append(c)

out.append("\n\n-- ------------------------------------------------------- ایندکس‌ها\n")
out.extend(indexes)

# ------------------------------------------- ۳) جدول‌های ورود کاربران
out.append("""

-- --------------------------- جدول‌های مخصوص نسخه‌ی PHP (جایگزین Auth) ---

-- رمز کاربران (هش‌شده با bcrypt در PHP — رمز خام هرگز ذخیره نمی‌شود)
CREATE TABLE IF NOT EXISTS public.app_users (
  id            uuid PRIMARY KEY,
  username      text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  failed_tries  integer NOT NULL DEFAULT 0,
  locked_until  timestamp,
  created_at    timestamp NOT NULL DEFAULT (now() at time zone 'utc')
);

-- نشست‌های فعال کاربران
CREATE TABLE IF NOT EXISTS public.app_sessions (
  token      char(64) PRIMARY KEY,
  user_id    uuid NOT NULL,
  created_at timestamp NOT NULL DEFAULT (now() at time zone 'utc'),
  expires_at timestamp NOT NULL,
  ip         varchar(45)
);

CREATE INDEX IF NOT EXISTS app_sessions_user ON public.app_sessions (user_id);
CREATE INDEX IF NOT EXISTS app_sessions_exp  ON public.app_sessions (expires_at);


-- ------------------------------ داده‌ی پایه (بدون داده‌ی کسب‌وکاری) ---

INSERT INTO public.org_roles (role_key, label, sort_order, builtin, active) VALUES
  ('ceo','مدیرعامل',10,true,true),
  ('production_manager','مدیرتولید',20,true,true),
  ('production_planning','برنامه‌ریزی تولید',30,true,true),
  ('sales_manager','مدیرفروش',40,true,true),
  ('commercial','بازرگانی',50,true,true),
  ('finance','مالی',60,true,true),
  ('warehouse_keeper','انباردار',70,true,true),
  ('system_admin','مدیرسیستم',80,true,true)
ON CONFLICT (role_key) DO NOTHING;

INSERT INTO public.workflow_templates (module, step_order, approver_role, step_label) VALUES
  ('daily_reports',   1, 'production_planning', 'تایید برنامه‌ریزی تولید'),
  ('daily_reports',   2, 'ceo',                 'تایید نهایی مدیرعامل'),
  ('sheeter_reports', 1, 'production_planning', 'تایید برنامه‌ریزی تولید'),
  ('sheeter_reports', 2, 'ceo',                 'تایید نهایی مدیرعامل'),
  ('packaging',       1, 'production_planning', 'برنامه‌ریزی تولید'),
  ('packaging',       2, 'ceo',                 'مدیرعامل'),
  ('hr_leaves',       1, 'ceo',                 'تایید مدیرعامل')
ON CONFLICT (module, step_order) DO NOTHING;

INSERT INTO public.settings (key, value) VALUES
  ('lang',  '"fa"'::jsonb),
  ('theme', '"dark"'::jsonb)
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.bot_config (id) VALUES ('main') ON CONFLICT (id) DO NOTHING;
""")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text('\n'.join(out) + '\n', encoding='utf-8')

print(f'✅ ساخته شد: {OUT.relative_to(ROOT)}')
print(f'   جدول‌ها     : {len(tables)} (+۲ جدول ورود کاربران)')
print(f'   محدودیت‌ها  : {len(constraints)}')
print(f'   ایندکس‌ها   : {len(indexes)}')
