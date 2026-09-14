#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ترجمه‌ی خودکار قوانین امنیتی RLS پستگرس → آرایه‌ی قوانین PHP

چرا خودکار؟ چون ۱۶۰ قانون امنیتی داریم؛ نوشتن دستی‌شان یعنی ریسک
جاافتادن یکی و باز شدن یک در پشتی. این اسکریپت از روی خود اسکیما
می‌سازد، پس هیچ قانونی جا نمی‌ماند.

خروجی: deploy/php-mysql/api/policies.php
"""
import re
import pathlib
import collections

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / 'supabase' / 'migrations' / '0001_full_schema.sql'
OUT = ROOT / 'deploy' / 'php-mysql' / 'api' / 'policies.php'

sql = SRC.read_text(encoding='utf-8')

pol_re = re.compile(
    r'CREATE POLICY (\w+) ON public\.(\w+) AS \w+ FOR (\w+) TO \w+'
    r'(?: USING \((.*?)\))?(?: WITH CHECK \((.*?)\))?;\n', re.S)

page_re = re.compile(r"has_page_perm\(ARRAY\[(.*?)\],\s*'(\w+)'::text,\s*'(\w+)'::text\)", re.S)
perm_re = re.compile(r"has_perm\('(\w+)'::text,\s*'(\w+)'::text\)")

# جدول‌هایی که منطق سطر-به-سطرشان ویژه است و در PHP دستی پیاده شده
SPECIAL = {
    ('daily_reports', 'UPDATE'):     'workflow_update',
    ('packaging_reports', 'UPDATE'): 'workflow_update',
    ('sheeter_reports', 'UPDATE'):   'owner_or_admin_update',
    ('hr_employees', 'SELECT'):      'hr_self_or_perm',
    ('hr_attendance', 'SELECT'):     'hr_self_or_perm',
    ('hr_contracts', 'SELECT'):      'hr_self_or_perm',
    ('hr_payroll_items', 'SELECT'):  'hr_self_or_perm',
    ('hr_payslips', 'SELECT'):       'hr_self_or_perm',
    ('hr_leaves', 'SELECT'):         'hr_leave_select',
    ('hr_leaves', 'INSERT'):         'hr_leave_insert',
    ('letters', 'SELECT'):           'letters_select',
    ('doc_signatures', 'DELETE'):    'signature_delete',
    ('form_templates', 'SELECT'):    ('own_or_admin', 'owner_id'),
    ('form_templates', 'DELETE'):    ('own_or_admin', 'owner_id'),
    ('form_templates', 'INSERT'):    ('own_only', 'owner_id'),
    ('custom_form_records', 'INSERT'): ('own_only', 'submitted_by'),
    ('doc_signatures', 'INSERT'):    ('own_only', 'profile_id'),
    ('letters', 'INSERT'):           ('own_only', 'sender_id'),
    # دو سیاست روی همین عملیات بود (مدیر «یا» صاحب امضا) — با هم ترکیب شد
    ('user_signatures', 'ALL'):      ('admin_or_own', 'profile_id'),
    ('notifications', 'SELECT'):     'notif_select',
    ('profiles', 'SELECT'):          'profile_self_or_admin',
    ('profiles', 'UPDATE'):          'profile_self_or_admin',
}

rules = collections.defaultdict(dict)

for m in pol_re.finditer(sql):
    _name, table, cmd, using, check = m.groups()
    expr = (using or check or '').strip()
    key = (table, cmd)

    if key in SPECIAL:
        spec = SPECIAL[key]
        if isinstance(spec, tuple):
            rules[table][cmd] = {'type': 'special', 'handler': spec[0], 'field': spec[1]}
        else:
            rules[table][cmd] = {'type': 'special', 'handler': spec}
        continue

    if expr == 'false':
        rules[table][cmd] = {'type': 'deny'}
        continue

    # «OR» باید به‌عنوان عملگر تشخیص داده شود، نه بخشی از نام ستون
    # (مثلاً sales_orders نباید OR حساب شود)
    has_or = re.search(r'\bOR\b', expr, re.I) is not None

    pm = page_re.search(expr)
    if pm and not has_or:
        pages = re.findall(r"'([\w]+)'::text", pm.group(1))
        rules[table][cmd] = {'type': 'page', 'pages': pages,
                             'module': pm.group(2), 'level': pm.group(3)}
        continue

    hm = perm_re.search(expr)
    if hm and not has_or:
        rules[table][cmd] = {'type': 'module', 'module': hm.group(1), 'level': hm.group(2)}
        continue

    if 'is_current_user_admin()' in expr and not has_or:
        rules[table][cmd] = {'type': 'admin'}
        continue

    if expr in ('(auth.uid() IS NOT NULL)', 'auth.uid() IS NOT NULL'):
        rules[table][cmd] = {'type': 'login'}
        continue

    # هر چیز دیگری: امن‌ترین حالت — فقط مدیر سیستم
    rules[table][cmd] = {'type': 'admin', 'note': 'fallback: ' + expr[:120]}

# جدول‌هایی که اصلاً سیاستی ندارند → فقط سرور (مثل bot_config)
all_tables = set(re.findall(r'CREATE TABLE public\.(\w+)', sql))
for t in sorted(all_tables - set(rules)):
    rules[t] = {'SELECT': {'type': 'deny'}, 'INSERT': {'type': 'deny'},
                'UPDATE': {'type': 'deny'}, 'DELETE': {'type': 'deny'},
                '_note': 'بدون سیاست در نسخه اصلی → فقط سمت سرور'}


def php_val(v, indent=0):
    pad = '    ' * indent
    if isinstance(v, dict):
        items = []
        for k, val in v.items():
            if k.startswith('_'):
                continue
            items.append(f"{pad}    '{k}' => {php_val(val, indent + 1)}")
        return "[\n" + ",\n".join(items) + f"\n{pad}]"
    if isinstance(v, list):
        return "[" + ", ".join("'" + str(x).replace("\\", "\\\\").replace("'", "\\'") + "'"
                               for x in v) + "]"
    if isinstance(v, bool):
        return 'true' if v else 'false'
    esc = str(v).replace("\\", "\\\\").replace("'", "\\'")
    return f"'{esc}'"


lines = ["""<?php
/**
 * قوانین دسترسی — ترجمه‌ی خودکار از RLS پستگرس
 *
 * ⚠️ این فایل را دستی ویرایش نکنید.
 *    با اجرای deploy/php-mysql/build-policies.py دوباره ساخته می‌شود.
 *
 * معنی هر نوع:
 *   page    → دسترسی بر اساس صفحه‌ها و ماژول (مثل has_page_perm)
 *   module  → دسترسی بر اساس ماژول (مثل has_perm)
 *   admin   → فقط مدیر سیستم
 *   login   → هر کاربر واردشده
 *   deny    → از طریق API مستقیم ممنوع (فقط توابع گردش کار)
 *   special → منطق ویژه‌ی سطر-به-سطر (در lib.php پیاده شده)
 */

return ["""]

for table in sorted(rules):
    lines.append(f"    '{table}' => {php_val(rules[table], 1)},")

lines.append("];")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(lines) + "\n", encoding='utf-8')

stats = collections.Counter()
for t, cmds in rules.items():
    for c, r in cmds.items():
        if isinstance(r, dict) and 'type' in r:
            stats[r['type']] += 1

print(f'✅ ساخته شد: {OUT.relative_to(ROOT)}')
print(f'   جدول‌ها: {len(rules)}')
for k, v in sorted(stats.items()):
    print(f'   {k:8s}: {v}')
