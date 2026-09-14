#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ساخت نسخه‌ی index.html مخصوص هاست شخصی (PHP + MySQL)

کاری که می‌کند:
  ۱) کتابخانه‌ی supabase-js را با erp-api.js (لایه‌ی اتصال به PHP) عوض می‌کند
  ۲) آدرس و کلید سوپابیس را حذف می‌کند
  ۳) بقیه‌ی ۸۰۰۰ خط کد دست‌نخورده می‌ماند

خروجی: dist/php-mysql/index.html
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / 'index.html'
OUT_DIR = ROOT / 'dist' / 'php-mysql'
OUT = OUT_DIR / 'index.html'

html = SRC.read_text(encoding='utf-8')
orig_len = len(html)
changes = []

# ---------------------------------------------- ۱) جایگزینی کتابخانه سوپابیس
sb_tag = re.search(
    r'<script src="vendor/supabase\.min\.js"></script>\s*\n'
    r'<script>window\.supabase\|\|document\.write\([^\n]*\n', html)
if sb_tag:
    html = html.replace(sb_tag.group(0),
        '<!-- لایه‌ی اتصال به بک‌اند PHP (جایگزین supabase-js) -->\n'
        '<script src="erp-api.js"></script>\n')
    changes.append('کتابخانه supabase-js → erp-api.js')
else:
    # اگر ساختار تغییر کرده بود، حداقل خود فایل را عوض کن
    if 'vendor/supabase.min.js' in html:
        html = html.replace('vendor/supabase.min.js', 'erp-api.js')
        changes.append('مسیر supabase.min.js → erp-api.js')
    else:
        sys.exit('ERROR: تگ کتابخانه سوپابیس پیدا نشد — ساختار index.html عوض شده')

# --------------------------------------------------- ۲) حذف آدرس و کلید ابری
cfg = re.search(
    r"const SUPABASE_URL\s*=\s*'[^']*';\s*\n"
    r"const SUPABASE_ANON_KEY\s*=\s*'[^']*';\s*\n", html)
if cfg:
    html = html.replace(cfg.group(0),
        "// نسخه‌ی هاست شخصی: داده‌ها از api/ روی همین دامنه خوانده می‌شوند\n"
        "// اگر پوشه‌ی api جای دیگری است، فقط خط زیر را عوض کنید:\n"
        "window.ERP_API_BASE = 'api';\n"
        "const SUPABASE_URL = '';\n"
        "const SUPABASE_ANON_KEY = '';\n")
    changes.append('حذف آدرس و کلید سوپابیس')
else:
    sys.exit('ERROR: خطوط تنظیمات سوپابیس پیدا نشد')

# ------------------------------- ۳) نشانه‌گذاری نسخه برای تشخیص در عیب‌یابی
html = html.replace('<title>', '<!-- نسخه: هاست شخصی PHP + MySQL -->\n<title>', 1)

OUT_DIR.mkdir(parents=True, exist_ok=True)
OUT.write_text(html, encoding='utf-8')

print(f'✅ ساخته شد: {OUT.relative_to(ROOT)}')
print(f'   حجم: {orig_len:,} → {len(html):,} بایت')
for c in changes:
    print(f'   • {c}')
