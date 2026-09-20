#!/usr/bin/env bash
# =====================================================================
# ساخت پکیج کامل نصب روی هاست (PHP + MySQL یا PostgreSQL)
#
# اجرا از ریشه‌ی مخزن:  bash deploy/php-mysql/build-package.sh
# =====================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$REPO_ROOT/deploy/php-mysql"
OUT_DIR="$REPO_ROOT/dist"
STAGE="$OUT_DIR/sanat-sabz-erp-host"
ZIP_PATH="$OUT_DIR/sanat-sabz-erp-host.zip"

echo "→ ساخت فایل‌های تولیدی از منابع اصلی"
python3 "$SRC/build-mysql-schema.py"
python3 "$SRC/build-pgsql-schema.py"
python3 "$SRC/build-policies.py"
python3 "$SRC/build-frontend.py"

echo "→ آماده‌سازی پوشه"
rm -rf "$STAGE" "$ZIP_PATH"
mkdir -p "$STAGE"/{api,bot,database,uploads}

echo "→ کپی سامانه"
cp "$OUT_DIR/php-mysql/index.html" "$STAGE/index.html"
cp "$SRC/frontend/erp-api.js"      "$STAGE/erp-api.js"
cp -r "$REPO_ROOT/vendor"          "$STAGE/vendor"
rm -f "$STAGE/vendor/README.md"
rm -f "$STAGE/vendor/supabase.min.js"   # دیگر لازم نیست؛ جایش erp-api.js است

echo "→ کپی بک‌اند"
cp "$SRC/api/"*.php "$STAGE/api/"
cp "$SRC/api/.htaccess" "$STAGE/api/.htaccess"
rm -f "$STAGE/api/config.php"          # هرگز تنظیمات محلی را منتشر نکن

echo "→ کپی ربات تلگرام"
cp "$SRC/bot/telegram.php" "$STAGE/bot/telegram.php"

echo "→ کپی دیتابیس و نصاب"
cp "$SRC/database/mysql_schema.sql" "$STAGE/database/"
cp "$SRC/database/pgsql_schema.sql" "$STAGE/database/"
cp "$SRC/install.php"               "$STAGE/"
cp "$SRC/INSTALL.md"                "$STAGE/"
cp "$SRC/راهنمای-نصب.txt"            "$STAGE/"
cp "$SRC/راهنمای-ربات-تلگرام.txt"     "$STAGE/"

# پوشه‌ی آپلود باید وجود داشته باشد ولی خالی
cat > "$STAGE/uploads/.htaccess" <<'EOF'
# اجرای اسکریپت در پوشه‌ی آپلود ممنوع (جلوگیری از آپلود فایل مخرب)
<FilesMatch "\.(php|phtml|php5|php7|phar|cgi|pl)$">
    Require all denied
</FilesMatch>
Options -Indexes
EOF

cat > "$STAGE/README-FIRST.txt" <<'EOF'
===============================================================
  سامانه ERP - شرکت تعاونی تولیدی پیشگامان صنعت سبز
  نسخه هاست شخصی (PHP + MySQL یا PostgreSQL)
===============================================================

هیچ وابستگی به سرویس بیرونی ندارد.
سایت، دیتابیس، ورود کاربران و ربات تلگرام - همه روی هاست خودتان.

نصب در ۳ قدم:
---------------------------------------------------------------
  ۱) در پنل هاست یک دیتابیس بسازید (MySQL یا PostgreSQL)
  ۲) همه فایل های این زیپ را در public_html اکسترکت کنید
  ۳) در مرورگر باز کنید:  https://yourdomain.ir/install.php

بعد از نصب حتما فایل install.php را پاک کنید.

---------------------------------------------------------------
  کدام فایل را بخوانم؟
---------------------------------------------------------------
  راهنمای-نصب.txt            <-- از اینجا شروع کنید (فارسی ساده)
  راهنمای-ربات-تلگرام.txt     <-- راه اندازی ربات سبزینه
  INSTALL.md                 <-- راهنمای فنی تر

===============================================================
EOF

echo "→ تبدیل خط‌پایان فایل‌های متنی به فرمت ویندوز"
find "$STAGE" -maxdepth 1 -type f \( -name '*.txt' -o -name '*.md' \) -print0 |
  while IFS= read -r -d '' f; do sed -i 's/\r$//; s/$/\r/' "$f"; done

echo "→ فشرده‌سازی"
(cd "$OUT_DIR" && zip -qr "$(basename "$ZIP_PATH")" "$(basename "$STAGE")")

echo
echo "✅ پکیج ساخته شد: $ZIP_PATH"
du -h "$ZIP_PATH" | cut -f1 | sed 's/^/   حجم: /'
echo
(cd "$STAGE" && find . -type f | sort | sed 's/^\./   /')
