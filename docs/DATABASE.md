# ساختار دیتابیس

پایگاه داده: **PostgreSQL** روی Supabase — ۴۸ جدول با کنترل دسترسی سطرمحور (RLS).

---

## اصول طراحی

| اصل | توضیح |
|---|---|
| نام‌گذاری | جدول‌ها و ستون‌ها `snake_case` — سمت جاوااسکریپت `camelCase` (تبدیل خودکار در `DataService`) |
| کلید اصلی | `uuid` با `gen_random_uuid()` |
| امنیت | RLS روی همه‌ی جدول‌ها فعال است |
| عملیات حساس | فقط از طریق توابع `SECURITY DEFINER` |
| گردش کار | ستون‌های مشترک `status` / `current_step` / `escalated` / `submitted_by` / `rejection_note` |

---

## جدول‌ها بر اساس ماژول

### هسته و دسترسی
| جدول | کاربرد |
|---|---|
| `profiles` | کاربران، نقش، سطح دسترسی (`perms` به‌صورت jsonb) |
| `org_roles` | سمت‌های سازمانی (قابل افزودن از رابط کاربری) |
| `settings` | تنظیمات کلیدی-مقداری |
| `activity_log` | لاگ فعالیت کاربران |
| `notifications` | اعلان‌ها (پل ارتباطی با تلگرام) |

### گردش کار و امضا
| جدول | کاربرد |
|---|---|
| `workflow_templates` | مراحل تأیید هر ماژول (`module`, `step_order`, `approver_role`) |
| `approvals` | سابقه‌ی تأیید/رد هر سند |
| `user_signatures` | تصویر امضای هر کاربر |
| `doc_signatures` | امضای اسناد (چه کسی، کدام سند، چه زمانی) |

### تولید
| جدول | کاربرد |
|---|---|
| `daily_reports` | گزارش تولید روزانه (۲۶ ستون) |
| `sheeter_reports` | گزارش شیتر/گیوتین |
| `production_stops` | توقفات (نوع، مدت، علت، خط) |
| `packaging_reports` | گزارش بسته‌بندی + کنترل کیفی |

### انبار و تأمین
`papers` · `inventory` · `rawmats` · `pack_presets` · `suppliers` · `purchase_orders` · `goods_requests`

### برنامه‌ریزی
`formulas` · `bom_history`

### فروش
`customers` · `sales_orders` · `sales_deliveries` · `invoices`

### حسابداری و خزانه
`acc_accounts` · `acc_vouchers` · `acc_voucher_lines` · `treasury_accounts` · `treasury_checks` · `treasury_transactions`

### منابع انسانی
`hr_employees` · `hr_contracts` · `hr_shifts` · `hr_attendance` · `hr_leaves` · `hr_payroll_items` · `hr_payslips`

### فرم‌ساز
| جدول | کاربرد |
|---|---|
| `custom_forms` | تعریف فرم (فیلدها در `fields` jsonb، `batch_mode`) |
| `custom_form_records` | رکوردهای ثبت‌شده |
| `form_templates` | قالب‌های ذخیره‌شده کاربر |

### ربات تلگرام
| جدول | کاربرد | نکته امنیتی |
|---|---|---|
| `bot_config` | توکن ربات، کلید و آدرس هوش مصنوعی | **بدون policy** — فقط `service_role` |
| `bot_users` | کاربران مجاز ربات |
| `bot_sessions` | وضعیت ورود مرحله‌ای |
| `bot_log` | تاریخچه پرسش و پاسخ |

---

## کنترل دسترسی (RLS)

### توابع کمکی

```sql
-- سطح دسترسی ماژول: 'none' | 'view' | 'edit'
has_perm(module text, min_level text) → boolean

-- سطح دسترسی صفحه‌محور (اولویت با تنظیم صفحه است)
has_page_perm(pages text[], module text, min_level text) → boolean

-- بررسی نقش کاربر جاری
current_user_has_role(check_role text) → boolean
```

### الگوی استاندارد policy

```sql
ALTER TABLE public.<table> ENABLE ROW LEVEL SECURITY;

CREATE POLICY <t>_select ON public.<table> FOR SELECT
  USING (has_page_perm(ARRAY['<page>'], '<module>', 'view'));

CREATE POLICY <t>_insert ON public.<table> FOR INSERT
  WITH CHECK (has_page_perm(ARRAY['<page>'], '<module>', 'edit'));

CREATE POLICY <t>_update ON public.<table> FOR UPDATE
  USING (
    has_perm('management','edit')                                  -- مدیر سیستم
    OR (submitted_by = auth.uid()
        AND status = ANY(ARRAY['draft','rejected']))               -- ثبت‌کننده تا قبل از تأیید
    OR (current_step = 1 AND current_user_has_role('production_planning'))
    OR (current_step = 2 AND current_user_has_role('ceo'))
  );

CREATE POLICY <t>_delete ON public.<table> FOR DELETE
  USING (has_perm('management','edit'));
```

---

## توابع امن (`SECURITY DEFINER`)

همه با `SET search_path = public` و دسترسی گرفته‌شده از `anon`.

### گردش کار
| تابع | کاربرد |
|---|---|
| `approve_daily_report(uuid, text)` | تأیید گزارش تولید و انتقال به مرحله‌ی بعد |
| `reject_daily_report(uuid, text)` | رد گزارش با ثبت دلیل |
| `resubmit_daily_report(uuid)` | ارسال مجدد پس از رد |
| `approve_packaging_report(uuid, text)` | تأیید گزارش بسته‌بندی |
| `reject_packaging_report(uuid, text)` | رد گزارش بسته‌بندی |
| `resubmit_packaging_report(uuid)` | ارسال مجدد |
| `approve_hr_leave` / `reject_hr_leave` | تأیید/رد مرخصی |
| `set_module_workflow(text, jsonb)` | **ویرایش گردش کار هر ماژول** (فقط مدیر سیستم) |
| `set_custom_form_workflow(text, jsonb)` | گردش کار فرم‌های ساخته‌شده |
| `run_escalations()` | ارجاع خودکار اسناد معطل به مدیرعامل |

### سایر
| تابع | کاربرد |
|---|---|
| `submit_custom_form(uuid, jsonb)` | ثبت رکورد فرم سفارشی |
| `post_voucher` / `unpost_voucher` | ثبت/برگشت سند حسابداری |
| `acknowledge_letter(uuid, text)` | تأیید دریافت نامه |
| `bot_readonly_sql(text)` | اجرای `SELECT` محدود برای ربات |
| `forward_notification_to_telegram()` | تریگر ارسال اعلان به تلگرام |

> منطق تأیید در تابع بررسی می‌کند که کاربر یا **مدیر سیستم** باشد، یا **نقشش با `approver_role` مرحله‌ی جاری بخواند**، یا سند به مدیرعامل ارجاع شده باشد.

---

## زمان‌بندی‌ها (pg_cron)

| نام | زمان‌بندی (UTC) | معادل تهران | کار |
|---|---|---|---|
| `nightly-erp-backup` | `30 22 * * *` | ۰۲:۰۰ بامداد | بک‌آپ کامل روی Storage |
| `bot-daily-report-noon-tehran` | `30 8 * * *` | ۱۲:۰۰ ظهر | ارسال گزارش روزانه در تلگرام |
| `escalate-stale-approvals` | `0 * * * *` | هر ساعت | ارجاع اسناد معطل |

> زمان‌بندی cron با UTC محاسبه می‌شود. تهران `UTC+3:30` است.

---

## گرفتن خروجی از ساختار فعلی

```bash
# فقط ساختار (بدون داده)
pg_dump "postgresql://postgres:[PASS]@db.[REF].supabase.co:5432/postgres" \
  --schema-only --no-owner --no-privileges -f schema.sql

# ساختار + داده
pg_dump "postgresql://postgres:[PASS]@db.[REF].supabase.co:5432/postgres" \
  --no-owner --no-privileges -Fc -f full.dump
```

> رشته‌ی اتصال از داشبورد Supabase: **Project Settings → Database → Connection string**

---

## نکات نگهداری

- پیش از تغییر ساختار، حتماً بک‌آپ بگیرید
- ستون جدید را با `ADD COLUMN IF NOT EXISTS` اضافه کنید تا اجرای مکرر مشکل‌ساز نشود
- پس از افزودن جدول جدید:
  1. RLS را فعال و policy بنویسید
  2. جدول را به `TABLE_MAP` در `index.html` اضافه کنید
  3. جدول را به آرایه‌ی `TABLES` در تابع `daily-backup` اضافه کنید
