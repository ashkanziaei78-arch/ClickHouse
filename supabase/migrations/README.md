# مهاجرت‌های دیتابیس

ساختار کامل و به‌روز دیتابیس روی پروژه‌ی Supabase قرار دارد.
برای گرفتن خروجی ساختار:

```bash
pg_dump "postgresql://postgres:[PASSWORD]@db.[REF].supabase.co:5432/postgres" \
  --schema-only --no-owner --no-privileges -f schema.sql
```

خلاصه‌ی جدول‌ها، policyها و توابع در [`../../docs/DATABASE.md`](../../docs/DATABASE.md) مستند شده است.

## هنگام افزودن جدول جدید
1. `ALTER TABLE ... ENABLE ROW LEVEL SECURITY;` و نوشتن policy
2. افزودن به `TABLE_MAP` در `index.html`
3. افزودن به آرایه‌ی `TABLES` در `supabase/functions/daily-backup/index.ts`
