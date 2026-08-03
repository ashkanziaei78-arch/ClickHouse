# ربات تلگرام «سبزینه»

دستیار هوشمند گزارش‌گیری که مستقیم به دیتابیس وصل است و به زبان طبیعی فارسی پاسخ می‌دهد.

---

## قابلیت‌ها

- **ورود امن مرحله‌ای** — نام کاربری، سپس رمز (پیام رمز بلافاصله پاک می‌شود)
- **گزارش‌های آماده** با دکمه: تولید، فروش، انبار، خزانه، منابع انسانی، مالی، چک‌ها
- **پرسش آزاد** — «تولید هفته‌ی گذشته چقدر بود؟» و پاسخ از داده‌ی واقعی
- **۹ نمودار** به‌صورت تصویر
- **دکمه‌های بازه‌ی زمانی** زیر هر گزارش (دیروز / هفته / ماه)
- **گزارش خودکار ساعت ۱۲ ظهر** برای همه‌ی کاربران فعال
- **ارسال اعلان‌های سایت** به تلگرام

---

## معماری

```
تلگرام ──webhook──► telegram-bot (Edge Function)
                          │
                          ├─► bot_config    توکن و کلیدها
                          ├─► bot_users     کنترل دسترسی
                          ├─► دیتابیس ERP   داده‌ی گزارش‌ها
                          └─► هوش مصنوعی    تفسیر پرسش (سازگار با OpenAI)
```

### چرا `bot_config` به‌جای متغیر محیطی؟
توکن ربات و کلید هوش مصنوعی در جدولی نگهداری می‌شوند که **RLS دارد ولی هیچ policy ندارد** — یعنی هیچ کاربری (حتی وارد‌شده) نمی‌تواند بخواندش؛ فقط `service_role` که در توابع سرور اجرا می‌شود دسترسی دارد.

---

## راه‌اندازی

### ۱. ساخت ربات
در تلگرام به [@BotFather](https://t.me/BotFather) پیام دهید:
```
/newbot
```
توکن دریافتی را نگه دارید.

### ۲. ساخت جدول تنظیمات

```sql
CREATE TABLE IF NOT EXISTS public.bot_config(
  id text PRIMARY KEY DEFAULT 'main',
  telegram_token text,
  webhook_secret text,
  ai_base_url text,
  ai_api_key text,
  ai_model text,
  updated_at timestamptz DEFAULT now()
);

-- RLS فعال، بدون هیچ policy → فقط service_role
ALTER TABLE public.bot_config ENABLE ROW LEVEL SECURITY;

INSERT INTO public.bot_config(id, telegram_token, webhook_secret, ai_base_url, ai_api_key, ai_model)
VALUES (
  'main',
  '<توکن ربات>',
  '<یک رشته تصادفی طولانی>',
  'https://api.groq.com/openai/v1',
  '<کلید هوش مصنوعی>',
  'llama-3.3-70b-versatile'
)
ON CONFLICT (id) DO UPDATE SET
  telegram_token = EXCLUDED.telegram_token,
  webhook_secret = EXCLUDED.webhook_secret;
```

### ۳. جدول‌های جانبی

```sql
CREATE TABLE IF NOT EXISTS public.bot_users(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  telegram_chat_id text UNIQUE NOT NULL,
  profile_id uuid REFERENCES public.profiles(id),
  display_name text,
  role_label text,
  active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.bot_sessions(
  chat_id text PRIMARY KEY,
  step text,
  temp_username text,
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.bot_log(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  telegram_chat_id text,
  question text,
  answer text,
  tool_calls jsonb,
  created_at timestamptz DEFAULT now()
);
```

### ۴. دیپلوی توابع

```bash
supabase functions deploy telegram-bot     --no-verify-jwt
supabase functions deploy bot-daily-report --no-verify-jwt
supabase functions deploy telegram-notify  --no-verify-jwt
```

> `--no-verify-jwt` لازم است چون تلگرام JWT نمی‌فرستد. امنیت از طریق هدر `X-Telegram-Bot-Api-Secret-Token` تأمین می‌شود.

### ۵. ثبت وب‌هوک

```
https://api.telegram.org/bot<TOKEN>/setWebhook
  ?url=https://<REF>.supabase.co/functions/v1/telegram-bot
  &secret_token=<همان webhook_secret>
```

بررسی وضعیت:
```
https://api.telegram.org/bot<TOKEN>/getWebhookInfo
```

### ۶. تعریف دستورات (اختیاری)

```json
POST https://api.telegram.org/bot<TOKEN>/setMyCommands
{
  "commands": [
    {"command": "start",   "description": "شروع و ورود"},
    {"command": "tolid",   "description": "گزارش تولید"},
    {"command": "forush",  "description": "گزارش فروش"},
    {"command": "anbar",   "description": "وضعیت انبار"},
    {"command": "khazane", "description": "خزانه"},
    {"command": "manabe",  "description": "منابع انسانی"},
    {"command": "mali",    "description": "سود و زیان"},
    {"command": "chek",    "description": "چک‌ها"},
    {"command": "logout",  "description": "خروج"}
  ]
}
```

### ۷. زمان‌بندی گزارش روزانه

```sql
SELECT cron.schedule(
  'bot-daily-report-noon-tehran',
  '30 8 * * *',                       -- ۱۲:۰۰ تهران
  $$ SELECT net.http_get(
       'https://<REF>.supabase.co/functions/v1/bot-daily-report?key=<webhook_secret>'
     ); $$
);
```

---

## هوش مصنوعی

تابع با هر سرویس **سازگار با OpenAI** کار می‌کند.

| سرویس | `ai_base_url` | مدل پیشنهادی |
|---|---|---|
| Groq (رایگان) | `https://api.groq.com/openai/v1` | `llama-3.3-70b-versatile` |
| OpenAI | `https://api.openai.com/v1` | `gpt-4o-mini` |

اگر `ai_api_key` خالی باشد، ربات فقط با دکمه‌ها کار می‌کند (پرسش آزاد غیرفعال می‌شود).

### ابزارهای در اختیار هوش مصنوعی
`report_production` · `report_sales` · `report_inventory` · `report_treasury` · `report_hr` · `report_financial` · `sql_query`

`sql_query` از تابع محافظت‌شده‌ی `bot_readonly_sql` استفاده می‌کند که فقط `SELECT` را می‌پذیرد.

---

## مدیریت کاربران ربات

از داخل سایت: **مدیریت ← ربات تلگرام**

- مشاهده‌ی کاربران متصل
- فعال/غیرفعال کردن دسترسی

کاربر با همان نام کاربری و رمز ERP وارد ربات می‌شود؛ سطح دسترسی‌اش همان است.

---

## عیب‌یابی

| نشانه | علت | راه‌حل |
|---|---|---|
| ربات پاسخ نمی‌دهد | وب‌هوک ثبت نشده | `getWebhookInfo` را بررسی کنید |
| خطای ۴۰۱ | عدم تطابق `secret_token` | مقدار را با `bot_config` یکسان کنید |
| «بخش سوال آزاد فعال نیست» | `ai_api_key` خالی است | کلید را در `bot_config` وارد کنید |
| گزارش‌ها صفر است | داده‌ای در آن بازه نیست | بازه را عوض کنید |
| نمودار نمی‌آید | QuickChart در دسترس نیست | اتصال شبکه‌ی سرور را بررسی کنید |
| گزارش خودکار نمی‌آید | cron ثبت نشده | `SELECT * FROM cron.job;` |

### مشاهده‌ی لاگ
```bash
supabase functions logs telegram-bot --tail
```

---

## امنیت

- توکن‌ها فقط در `bot_config` (غیرقابل خواندن توسط کاربران)
- تأیید هویت وب‌هوک با `X-Telegram-Bot-Api-Secret-Token`
- پیام حاوی رمز بلافاصله از چت حذف می‌شود
- ربات فقط عملیات **خواندنی** انجام می‌دهد
- فقط کاربران فعالِ تأییدشده پاسخ می‌گیرند
