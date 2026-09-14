#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
تبدیل اسکیمای PostgreSQL/Supabase به MySQL/MariaDB

ورودی : supabase/migrations/0001_full_schema.sql
خروجی : deploy/php-mysql/database/mysql_schema.sql

چرا اسکریپت و نه فایل دستی؟ تا هر وقت ساختار اصلی عوض شد، نسخه‌ی
MySQL هم با یک دستور دوباره ساخته شود و هیچ‌وقت عقب نماند.

تفاوت‌های مهم که اینجا مدیریت می‌شوند:
  • uuid            → CHAR(36)            (تولید شناسه در PHP)
  • jsonb           → JSON / LONGTEXT
  • timestamptz     → DATETIME            (همه‌چیز UTC ذخیره می‌شود)
  • numeric         → DECIMAL(18,4)
  • boolean         → TINYINT(1)
  • text ایندکس‌دار → VARCHAR(191)        (محدودیت طول ایندکس در MySQL)
  • DEFAULT توابع   → در PHP مقداردهی می‌شود (MySQL اجازه نمی‌دهد)
  • RLS و توابع PL/pgSQL → حذف؛ معادلشان در PHP پیاده شده است
"""
import re
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / 'supabase' / 'migrations' / '0001_full_schema.sql'
OUT = ROOT / 'deploy' / 'php-mysql' / 'database' / 'mysql_schema.sql'

sql = SRC.read_text(encoding='utf-8')

# ---------------------------------------------------------------- ۱) جدول‌ها
table_re = re.compile(r'CREATE TABLE public\.(\w+)\s*\((.*?)\);', re.S)
tables = {}
for m in table_re.finditer(sql):
    tables[m.group(1)] = m.group(2)

if not tables:
    sys.exit('ERROR: هیچ جدولی پیدا نشد')

# ------------------------------------------------- ۲) کلیدها و محدودیت‌ها
pk, uniques, fks, checks = {}, [], [], []

for m in re.finditer(
        r'ALTER TABLE ONLY public\.(\w+) ADD CONSTRAINT (\w+) PRIMARY KEY \(([^)]+)\);', sql):
    pk[m.group(1)] = [c.strip() for c in m.group(3).split(',')]

for m in re.finditer(
        r'ALTER TABLE ONLY public\.(\w+) ADD CONSTRAINT (\w+) UNIQUE \(([^)]+)\);', sql):
    uniques.append((m.group(1), m.group(2), [c.strip() for c in m.group(3).split(',')]))

for m in re.finditer(
        r'ALTER TABLE ONLY public\.(\w+) ADD CONSTRAINT (\w+) FOREIGN KEY \(([^)]+)\) '
        r'REFERENCES (\w+)\(([^)]+)\)([^;]*);', sql):
    fks.append({
        'table': m.group(1), 'name': m.group(2),
        'cols': [c.strip() for c in m.group(3).split(',')],
        'ref_table': m.group(4),
        'ref_cols': [c.strip() for c in m.group(5).split(',')],
        'action': m.group(6).strip(),
    })

for m in re.finditer(
        r"ALTER TABLE ONLY public\.(\w+) ADD CONSTRAINT (\w+) CHECK \(\((.*?)\)\);", sql):
    checks.append((m.group(1), m.group(2), m.group(3)))

# ستون‌هایی که ایندکس/کلید می‌شوند باید VARCHAR باشند نه TEXT
indexed_cols = set()
for t, cols in pk.items():
    for c in cols:
        indexed_cols.add((t, c))
for t, _n, cols in uniques:
    for c in cols:
        indexed_cols.add((t, c))
for fk in fks:
    for c in fk['cols']:
        indexed_cols.add((fk['table'], c))
    for c in fk['ref_cols']:
        indexed_cols.add((fk['ref_table'], c))
for m in re.finditer(r'CREATE INDEX \w+ ON public\.(\w+) USING btree \(([^)]+)\)', sql):
    for c in m.group(2).split(','):
        indexed_cols.add((m.group(1), c.strip().split()[0]))


def map_type(table, col, pgtype, is_indexed):
    t = pgtype.strip().lower()
    if t == 'uuid':
        return 'CHAR(36)'
    if t.startswith('timestamp'):
        return 'DATETIME'
    if t == 'date':
        return 'DATE'
    if t.startswith('time '):
        return 'TIME'
    if t == 'jsonb' or t == 'json':
        return 'JSON'
    if t == 'boolean':
        return 'TINYINT(1)'
    if t == 'integer':
        return 'INT'
    if t == 'bigint':
        return 'BIGINT'
    if t == 'numeric':
        return 'DECIMAL(18,4)'
    if t == 'text':
        return 'VARCHAR(191)' if is_indexed else 'TEXT'
    raise SystemExit(f'ERROR: نوع ناشناخته {pgtype!r} در {table}.{col}')


def map_default(table, col, mysql_type, pgdefault):
    """MySQL اجازه‌ی تابع در DEFAULT نمی‌دهد (جز CURRENT_TIMESTAMP)."""
    if pgdefault is None:
        return None, False
    d = pgdefault.strip()
    low = d.lower()
    if 'gen_random_uuid()' in low or 'uuid_generate_v4()' in low:
        return None, True           # شناسه در PHP ساخته می‌شود
    if low in ('now()', 'current_timestamp'):
        return 'CURRENT_TIMESTAMP', False
    if low == 'current_date':
        return None, True           # در PHP مقداردهی می‌شود
    if low == 'true':
        return '1', False
    if low == 'false':
        return '0', False
    m = re.match(r"^'(.*)'::(text|jsonb|json)$", d, re.S)
    if m:
        val = m.group(1).replace("'", "''")
        if mysql_type == 'JSON':
            return None, True       # MariaDB برای JSON دیفالت لیترال نمی‌پذیرد
        return f"'{val}'", False
    if re.match(r'^-?\d+(\.\d+)?$', d):
        return d, False
    return None, True


col_re = re.compile(
    r'^\s*(?:"(?P<q>[^"]+)"|(?P<n>\w+))\s+(?P<type>[a-z ]+(?:\([^)]*\))?)'
    r'(?P<notnull>\s+NOT NULL)?(?:\s+DEFAULT\s+(?P<def>.+?))?\s*$'
)

php_defaults = {}   # جدول → {ستون: نوع مقدار پیش‌فرضی که PHP باید بگذارد}
out = []

out.append("""-- =====================================================================
-- سامانه ERP «پیشگامان صنعت سبز» — ساختار دیتابیس برای MySQL / MariaDB
-- =====================================================================
-- این فایل خودکار از اسکیمای اصلی PostgreSQL ساخته شده است.
-- مناسب هاست‌های معمولی (cPanel / دایرکت‌ادمین) با MySQL یا MariaDB.
--
-- روش اجرا در cPanel:
--   phpMyAdmin → دیتابیس خود را انتخاب کنید → سربرگ Import →
--   همین فایل را انتخاب و اجرا کنید.
--
-- نکته: کنترل دسترسی (که در نسخه‌ی PostgreSQL با RLS انجام می‌شد)
-- اینجا در لایه‌ی PHP پیاده شده است؛ چون MySQL چنین امکانی ندارد.
-- پس هیچ‌وقت به دیتابیس مستقیم از بیرون دسترسی ندهید.
-- =====================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';
""")

for table in sorted(tables):
    body = tables[table]
    lines, pending = [], {}

    # تقسیم ستون‌ها با احترام به پرانتزها
    depth, cur, raw_cols = 0, '', []
    for ch in body:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        if ch == ',' and depth == 0:
            raw_cols.append(cur)
            cur = ''
        else:
            cur += ch
    if cur.strip():
        raw_cols.append(cur)

    for raw in raw_cols:
        raw = raw.strip()
        if not raw:
            continue
        m = col_re.match(raw)
        if not m:
            raise SystemExit(f'ERROR: ستون قابل تجزیه نیست در {table}: {raw!r}')
        name = m.group('q') or m.group('n')
        is_idx = (table, name) in indexed_cols
        mtype = map_type(table, name, m.group('type'), is_idx)
        notnull = bool(m.group('notnull'))
        dflt, php_side = map_default(table, name, mtype, m.group('def'))

        piece = f'  `{name}` {mtype}'
        if notnull and not php_side:
            piece += ' NOT NULL'
        elif notnull and php_side:
            piece += ' NOT NULL'      # PHP همیشه مقدار می‌گذارد
        if dflt is not None:
            piece += f' DEFAULT {dflt}'
        lines.append(piece)
        if php_side:
            pending[name] = (m.group('def') or '').strip()

    if pending:
        php_defaults[table] = pending

    if table in pk:
        cols = ', '.join(f'`{c}`' for c in pk[table])
        lines.append(f'  PRIMARY KEY ({cols})')
    for t, name, cols in uniques:
        if t == table:
            cl = ', '.join(f'`{c}`' for c in cols)
            lines.append(f'  UNIQUE KEY `{name[:60]}` ({cl})')

    out.append(f'CREATE TABLE IF NOT EXISTS `{table}` (')
    out.append(',\n'.join(lines))
    out.append(') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;\n')

# ---------------------------------------------------------------- ۳) ایندکس‌ها
out.append('\n-- ---------- ایندکس‌ها (سرعت گزارش‌ها) ----------')
for m in re.finditer(r'CREATE INDEX (\w+) ON public\.(\w+) USING btree \(([^)]+)\);', sql):
    idx, table, cols = m.group(1), m.group(2), m.group(3)
    parts = []
    for c in cols.split(','):
        c = c.strip()
        desc = ' DESC' if c.lower().endswith(' desc') else ''
        cname = c.split()[0]
        parts.append(f'`{cname}`{desc}')
    out.append(f'CREATE INDEX `{idx[:60]}` ON `{table}` ({", ".join(parts)});')

# ------------------------------------------------------------ ۴) کلید خارجی
out.append('\n-- ---------- ارتباط جدول‌ها ----------')
for fk in fks:
    if fk['ref_table'] == 'users':      # auth.users در MySQL وجود ندارد
        continue
    cols = ', '.join(f'`{c}`' for c in fk['cols'])
    rcols = ', '.join(f'`{c}`' for c in fk['ref_cols'])
    action = fk['action'].upper().strip()
    action = f' {action}' if action else ''
    out.append(
        f'ALTER TABLE `{fk["table"]}` ADD CONSTRAINT `{fk["name"][:60]}` '
        f'FOREIGN KEY ({cols}) REFERENCES `{fk["ref_table"]}` ({rcols}){action};'
    )

# ------------------------------------------------ ۵) جدول کاربران و نشست‌ها
out.append("""
-- ---------- جدول‌های مخصوص نسخه‌ی PHP (جایگزین Supabase Auth) ----------

-- رمز عبور کاربران (هش‌شده با bcrypt در PHP — رمز خام هرگز ذخیره نمی‌شود)
CREATE TABLE IF NOT EXISTS `app_users` (
  `id`            CHAR(36)     NOT NULL,
  `username`      VARCHAR(100) NOT NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `failed_tries`  INT          NOT NULL DEFAULT 0,
  `locked_until`  DATETIME     NULL,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `app_users_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- نشست‌های فعال (برای ورود کاربران)
CREATE TABLE IF NOT EXISTS `app_sessions` (
  `token`      CHAR(64)  NOT NULL,
  `user_id`    CHAR(36)  NOT NULL,
  `created_at` DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at` DATETIME  NOT NULL,
  `ip`         VARCHAR(45)  NULL,
  PRIMARY KEY (`token`),
  KEY `app_sessions_user` (`user_id`),
  KEY `app_sessions_exp`  (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
""")

# ------------------------------------------------------------- ۶) داده‌ی پایه
out.append("""
-- ---------- داده‌ی پایه (بدون هیچ داده‌ی کسب‌وکاری) ----------

INSERT IGNORE INTO `org_roles` (`role_key`,`label`,`sort_order`,`builtin`,`active`,`created_at`) VALUES
  ('ceo','مدیرعامل',10,1,1,NOW()),
  ('production_manager','مدیرتولید',20,1,1,NOW()),
  ('production_planning','برنامه‌ریزی تولید',30,1,1,NOW()),
  ('sales_manager','مدیرفروش',40,1,1,NOW()),
  ('commercial','بازرگانی',50,1,1,NOW()),
  ('finance','مالی',60,1,1,NOW()),
  ('warehouse_keeper','انباردار',70,1,1,NOW()),
  ('system_admin','مدیرسیستم',80,1,1,NOW());

INSERT IGNORE INTO `workflow_templates` (`id`,`module`,`step_order`,`approver_role`,`step_label`) VALUES
  ('11111111-1111-4111-8111-000000000001','daily_reports',1,'production_planning','تایید برنامه‌ریزی تولید'),
  ('11111111-1111-4111-8111-000000000002','daily_reports',2,'ceo','تایید نهایی مدیرعامل'),
  ('11111111-1111-4111-8111-000000000003','sheeter_reports',1,'production_planning','تایید برنامه‌ریزی تولید'),
  ('11111111-1111-4111-8111-000000000004','sheeter_reports',2,'ceo','تایید نهایی مدیرعامل'),
  ('11111111-1111-4111-8111-000000000005','packaging',1,'production_planning','برنامه‌ریزی تولید'),
  ('11111111-1111-4111-8111-000000000006','packaging',2,'ceo','مدیرعامل'),
  ('11111111-1111-4111-8111-000000000007','hr_leaves',1,'ceo','تایید مدیرعامل');

INSERT IGNORE INTO `settings` (`key`,`value`) VALUES
  ('lang','"fa"'),
  ('theme','"dark"');

INSERT IGNORE INTO `bot_config` (`id`,`updated_at`) VALUES ('main', NOW());

SET FOREIGN_KEY_CHECKS = 1;
""")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text('\n'.join(out), encoding='utf-8')

print(f'✅ ساخته شد: {OUT.relative_to(ROOT)}')
print(f'   جدول‌ها      : {len(tables)}')
print(f'   کلید اصلی    : {len(pk)}')
print(f'   یکتا         : {len(uniques)}')
print(f'   کلید خارجی   : {len([f for f in fks if f["ref_table"] != "users"])}')
if php_defaults:
    print(f'   ستون‌هایی که PHP باید مقداردهی کند: '
          f'{sum(len(v) for v in php_defaults.values())} مورد در {len(php_defaults)} جدول')
