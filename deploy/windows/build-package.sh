#!/usr/bin/env bash
# =====================================================================
# ساخت پکیج نصب ویندوز
#
# فایل‌های اصلی (index.html، vendor، اسکیمای دیتابیس، توابع سرور) از
# محل اصلی خودشان در مخزن برداشته می‌شوند تا هیچ‌وقت نسخه‌ی تکراری و
# قدیمی در پکیج نماند.
#
# اجرا از ریشه‌ی مخزن:   bash deploy/windows/build-package.sh
# =====================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$REPO_ROOT/deploy/windows"
OUT_DIR="${1:-$REPO_ROOT/dist}"
STAGE="$OUT_DIR/sanat-sabz-erp-windows"
ZIP_PATH="$OUT_DIR/sanat-sabz-erp-windows.zip"

echo "→ پاک‌سازی محل ساخت"
rm -rf "$STAGE" "$ZIP_PATH"
mkdir -p "$STAGE"/{app,database,iis,docker,scripts,edge-functions}

echo "→ کپی سامانه (index.html + vendor)"
cp "$REPO_ROOT/index.html" "$STAGE/app/index.html"
cp -r "$REPO_ROOT/vendor" "$STAGE/app/vendor"
rm -f "$STAGE/app/vendor/README.md"

echo "→ کپی اسکیمای دیتابیس"
cp "$REPO_ROOT/supabase/migrations/0001_full_schema.sql" "$STAGE/database/01_full_schema.sql"
cp "$SRC/database/00_compat_plain_postgres.sql" "$STAGE/database/"
cp "$SRC/database/02_first_admin.sql"           "$STAGE/database/"
cp "$SRC/database/README.md"                    "$STAGE/database/"

echo "→ ساخت نسخه‌ی PostgreSQL ویندوزی از اسکیما"
python3 - "$REPO_ROOT" "$STAGE" <<'PY'
import sys, pathlib
repo, stage = sys.argv[1], sys.argv[2]
src = pathlib.Path(repo, 'supabase/migrations/0001_full_schema.sql').read_text(encoding='utf-8')

replacements = [
    ('create extension if not exists "pg_cron";',
     '-- create extension if not exists "pg_cron";   <- روی PostgreSQL ویندوزی موجود نیست (زمان‌بندی با Task Scheduler)'),
    ('create extension if not exists "pg_net";',
     '-- create extension if not exists "pg_net";    <- روی PostgreSQL ویندوزی موجود نیست (توابع جایگزین در فایل 00 ساخته می‌شوند)'),
]
out = src
for old, new in replacements:
    if old not in out:
        raise SystemExit(f'ERROR: الگو پیدا نشد: {old}')
    out = out.replace(old, new)

header = """-- =====================================================================
-- نسخه‌ی مخصوص PostgreSQL معمولی روی ویندوز (بدون Supabase)
-- =====================================================================
-- این فایل خودکار از 01_full_schema.sql ساخته شده است.
-- تنها تفاوت: افزونه‌های pg_cron و pg_net که روی نصب ویندوزی موجود
-- نیستند، غیرفعال شده‌اند.
--
-- پیش‌نیاز: ابتدا 00_compat_plain_postgres.sql را اجرا کنید.
-- =====================================================================

"""
pathlib.Path(stage, 'database/01b_full_schema_plain_postgres.sql').write_text(header + out, encoding='utf-8')
print('   ساخته شد: 01b_full_schema_plain_postgres.sql')
PY

echo "→ کپی تنظیمات IIS و Docker و اسکریپت‌ها"
cp "$SRC/iis/web.config"   "$STAGE/iis/"
cp "$SRC/docker/README.md" "$STAGE/docker/"
cp "$SRC/scripts/"*.bat    "$STAGE/scripts/"

echo "→ کپی توابع سمت سرور"
cp -r "$REPO_ROOT/supabase/functions/." "$STAGE/edge-functions/"

echo "→ کپی راهنماها"
cp "$SRC/INSTALL-WINDOWS.md" "$STAGE/"
cp "$SRC/README-FIRST.txt"   "$STAGE/"

echo "→ تبدیل خط‌پایان فایل‌های متنی به فرمت ویندوز (CRLF)"
find "$STAGE" -type f \( -name '*.txt' -o -name '*.bat' -o -name '*.md' -o -name '*.config' \) -print0 |
  while IFS= read -r -d '' f; do
    # اگر از قبل CRLF نیست، تبدیل کن
    sed -i 's/\r$//' "$f"
    sed -i 's/$/\r/' "$f"
  done

echo "→ فشرده‌سازی"
(cd "$OUT_DIR" && zip -qr "$(basename "$ZIP_PATH")" "$(basename "$STAGE")")

echo
echo "✅ پکیج ساخته شد:"
echo "   $ZIP_PATH"
du -h "$ZIP_PATH" | cut -f1 | sed 's/^/   حجم: /'
echo
echo "محتویات:"
(cd "$STAGE" && find . -type f | sort | sed 's/^\./   /')
