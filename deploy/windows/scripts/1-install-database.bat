@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title نصب دیتابیس ERP - پیشگامان صنعت سبز

echo.
echo ============================================================
echo    نصب ساختار دیتابیس ERP روی PostgreSQL ویندوز
echo ============================================================
echo.

REM --- پیدا کردن psql ---
set "PSQL="
for %%V in (17 16 15 14) do (
  if exist "C:\Program Files\PostgreSQL\%%V\bin\psql.exe" (
    set "PSQL=C:\Program Files\PostgreSQL\%%V\bin\psql.exe"
    goto :found
  )
)

where psql.exe >nul 2>&1
if %errorlevel%==0 (
  for /f "delims=" %%P in ('where psql.exe') do set "PSQL=%%P"
  goto :found
)

echo [خطا] فایل psql.exe پیدا نشد.
echo.
echo لطفا اول PostgreSQL را نصب کنید:
echo    https://www.postgresql.org/download/windows/
echo.
pause
exit /b 1

:found
echo [OK] PostgreSQL پیدا شد:
echo      !PSQL!
echo.

REM --- اطلاعات اتصال ---
set /p PGHOST=آدرس سرور دیتابیس [پیش‌فرض localhost]:
if "!PGHOST!"=="" set PGHOST=localhost

set /p PGPORT=پورت [پیش‌فرض 5432]:
if "!PGPORT!"=="" set PGPORT=5432

set /p PGUSER=نام کاربری دیتابیس [پیش‌فرض postgres]:
if "!PGUSER!"=="" set PGUSER=postgres

set /p PGDATABASE=نام دیتابیس [پیش‌فرض erp_sanatsabz]:
if "!PGDATABASE!"=="" set PGDATABASE=erp_sanatsabz

echo.
set /p PGPASSWORD=رمز عبور کاربر !PGUSER!:
echo.

set "BASE=%~dp0..\database"

echo ------------------------------------------------------------
echo مرحله ۱ از ۳: ساخت دیتابیس !PGDATABASE!
echo ------------------------------------------------------------
"!PSQL!" -h !PGHOST! -p !PGPORT! -U !PGUSER! -d postgres -c "CREATE DATABASE \"!PGDATABASE!\";" 2>nul
if %errorlevel%==0 (
  echo [OK] دیتابیس ساخته شد.
) else (
  echo [توجه] دیتابیس از قبل وجود داشت - ادامه می‌دهیم.
)
echo.

echo ------------------------------------------------------------
echo مرحله ۲ از ۳: نصب لایه سازگاری
echo ------------------------------------------------------------
"!PSQL!" -h !PGHOST! -p !PGPORT! -U !PGUSER! -d !PGDATABASE! -v ON_ERROR_STOP=1 -f "!BASE!\00_compat_plain_postgres.sql"
if not %errorlevel%==0 goto :failed
echo [OK] لایه سازگاری نصب شد.
echo.

echo ------------------------------------------------------------
echo مرحله ۳ از ۳: نصب ساختار اصلی (۴۷ جدول)
echo ------------------------------------------------------------
"!PSQL!" -h !PGHOST! -p !PGPORT! -U !PGUSER! -d !PGDATABASE! -v ON_ERROR_STOP=1 -f "!BASE!\01b_full_schema_plain_postgres.sql"
if not %errorlevel%==0 goto :failed

echo.
echo ============================================================
echo    نصب با موفقیت تمام شد
echo ============================================================
echo.
echo رشته اتصال برای Power BI:
echo    Server   : !PGHOST!:!PGPORT!
echo    Database : !PGDATABASE!
echo.
echo قدم بعدی: فایل راهنما (INSTALL-WINDOWS.md) را بخوانید.
echo.
set PGPASSWORD=
pause
exit /b 0

:failed
echo.
echo [خطا] نصب ناتمام ماند. متن خطای بالا را بخوانید.
echo.
set PGPASSWORD=
pause
exit /b 1
