@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title پشتیبان‌گیری از دیتابیس ERP

REM ============================================================
REM  پشتیبان‌گیری کامل از دیتابیس
REM  این فایل را می‌توانید در Task Scheduler ویندوز زمان‌بندی کنید
REM  تا هر شب خودکار اجرا شود.
REM ============================================================

set "BACKUP_DIR=C:\ERP-Backups"
set "PGHOST=localhost"
set "PGPORT=5432"
set "PGUSER=postgres"
set "PGDATABASE=erp_sanatsabz"
REM رمز را اینجا بگذارید تا اجرای خودکار بدون سوال انجام شود:
set "PGPASSWORD=YOUR_PASSWORD_HERE"

set "PGDUMP="
for %%V in (17 16 15 14) do (
  if exist "C:\Program Files\PostgreSQL\%%V\bin\pg_dump.exe" (
    set "PGDUMP=C:\Program Files\PostgreSQL\%%V\bin\pg_dump.exe"
    goto :found
  )
)
echo [خطا] pg_dump.exe پیدا نشد.
exit /b 1

:found
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set DT=%%I
set "STAMP=%DT:~0,4%-%DT:~4,2%-%DT:~6,2%_%DT:~8,2%-%DT:~10,2%"
set "OUTFILE=%BACKUP_DIR%\erp_%STAMP%.dump"

echo در حال پشتیبان‌گیری به: %OUTFILE%
"!PGDUMP!" -h %PGHOST% -p %PGPORT% -U %PGUSER% -d %PGDATABASE% --no-owner --no-privileges -Fc -f "%OUTFILE%"

if %errorlevel%==0 (
  echo [OK] پشتیبان‌گیری انجام شد.

  REM حذف پشتیبان‌های قدیمی‌تر از ۳۰ روز
  forfiles /p "%BACKUP_DIR%" /m *.dump /d -30 /c "cmd /c del @path" 2>nul
  echo [OK] پشتیبان‌های قدیمی‌تر از ۳۰ روز پاک شدند.
) else (
  echo [خطا] پشتیبان‌گیری ناموفق بود.
)

set PGPASSWORD=
exit /b %errorlevel%
