@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title ساخت کاربر مدیر سیستم - پیشگامان صنعت سبز

echo.
echo ============================================================
echo    ساخت اولین کاربر (مدیر سیستم)
echo ============================================================
echo.
echo توجه: این مرحله فقط روی Supabase (ابری یا Docker) کار می‌کند،
echo چون کاربر باید در سیستم احراز هویت ساخته شود.
echo.

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
echo [خطا] psql.exe پیدا نشد. اول PostgreSQL را نصب کنید.
pause
exit /b 1

:found
set /p PGHOST=آدرس سرور دیتابیس [پیش‌فرض localhost]:
if "!PGHOST!"=="" set PGHOST=localhost
set /p PGPORT=پورت [پیش‌فرض 5432]:
if "!PGPORT!"=="" set PGPORT=5432
set /p PGUSER=نام کاربری دیتابیس [پیش‌فرض postgres]:
if "!PGUSER!"=="" set PGUSER=postgres
set /p PGDATABASE=نام دیتابیس [پیش‌فرض postgres]:
if "!PGDATABASE!"=="" set PGDATABASE=postgres
echo.
set /p PGPASSWORD=رمز عبور کاربر !PGUSER!:
echo.

echo ------------------------------------------------------------
echo قبل از ادامه: فایل database\02_first_admin.sql را باز کنید
echo و نام کاربری و رمز دلخواه را داخلش بنویسید، سپس ذخیره کنید.
echo ------------------------------------------------------------
echo.
pause

"!PSQL!" -h !PGHOST! -p !PGPORT! -U !PGUSER! -d !PGDATABASE! -v ON_ERROR_STOP=1 -f "%~dp0..\database\02_first_admin.sql"

if %errorlevel%==0 (
  echo.
  echo ============================================================
  echo    کاربر مدیر سیستم ساخته شد
  echo ============================================================
  echo حالا می‌توانید با همان نام کاربری و رمز وارد سامانه شوید.
) else (
  echo.
  echo [خطا] ساخت کاربر ناموفق بود. متن خطای بالا را بخوانید.
)

echo.
set PGPASSWORD=
pause
