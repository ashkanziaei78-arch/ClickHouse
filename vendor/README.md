# کتابخانه‌های محلی

این فایل‌ها نسخه‌ی محلی وابستگی‌های سامانه هستند تا روی سرورهایی که به CDN
دسترسی ندارند هم برنامه کامل بالا بیاید.

`index.html` ابتدا این فایل‌ها را می‌خواند؛ اگر پیدا نشدند، خودکار به
`cdn.jsdelivr.net` برمی‌گردد. یعنی این پوشه اختیاری ولی **به‌شدت توصیه‌شده** است.

| فایل | کتابخانه | نسخه | مجوز |
|---|---|---|---|
| `chart.umd.js` | Chart.js | 4.5.1 | MIT |
| `xlsx.full.min.js` | SheetJS Community | 0.18.5 | Apache-2.0 |
| `supabase.min.js` | supabase-js | 2.112.0 | MIT |
| `fonts/Vazirmatn.woff2` | Vazirmatn (variable) | 33.0.3 | SIL OFL 1.1 |

متن کامل مجوزها در همین پوشه قرار دارد.

## به‌روزرسانی

```bash
npm pack chart.js@4 xlsx@0.18.5 @supabase/supabase-js@2 vazirmatn@33
# سپس فایل‌های dist را در همین پوشه جایگزین کنید
```

> نسخه‌ی جدید Chart.js را حتماً یک‌بار روی داشبورد تست کنید.
