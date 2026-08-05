-- =====================================================================
-- سامانه ERP «پیشگامان صنعت سبز» — ساختار کامل دیتابیس (بدون داده)
-- تولید خودکار از روی دیتابیس عملیاتی — Postgres 17 / Supabase
-- =====================================================================
--
-- این فایل یک SQL «واقعی» است، برگرفته از ساختار زنده‌ی دیتابیس فعلی
-- (جدول‌ها، کلیدها، ایندکس‌ها، RLS، توابع امن و تریگرها) — نه بازنویسی
-- دستی. اجرای آن روی یک Postgres خالی، دقیقاً همین ساختار را می‌سازد،
-- بدون هیچ داده‌ی کسب‌وکاری (بدون کاربر، بدون گزارش، بدون رکورد) —
-- آماده برای اینکه کاربران واقعی از صفر اطلاعات را وارد کنند.
--
-- ⚠️ پیش‌نیاز مهم: این اسکریپت به schema به نام «auth» با جدول
-- auth.users و تابع auth.uid() نیاز دارد. این ساختار فقط توسط
-- Supabase (ابری یا خودمیزبان روی سرور خودتان) فراهم می‌شود؛ روی یک
-- Postgres ساده یا MySQL اجرا نمی‌شود. برای نصب Supabase خودمیزبان به
-- docs/DEPLOYMENT.md → سناریوی ۲ مراجعه کنید.
--
-- ترتیب اجرا: extensions → tables → constraints → indexes → RLS →
-- functions → triggers → policies → grants → seed (فقط تنظیمات پایه،
-- بدون داده‌ی کسب‌وکاری)
-- =====================================================================


-- #######################################################################
-- 1) EXTENSIONS
-- #######################################################################
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";
create extension if not exists "pg_cron";
create extension if not exists "pg_net";


-- #######################################################################
-- 2) TABLES
-- #######################################################################

CREATE TABLE public.acc_accounts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  code text NOT NULL,
  name text NOT NULL,
  level text NOT NULL DEFAULT 'kol'::text,
  parent_id uuid,
  acc_type text NOT NULL DEFAULT 'asset'::text,
  nature text DEFAULT 'debit'::text,
  active boolean DEFAULT true,
  note text,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.acc_voucher_lines (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  voucher_id uuid NOT NULL,
  account_id uuid,
  account_code text,
  account_name text,
  description text,
  debit numeric DEFAULT 0,
  credit numeric DEFAULT 0,
  tafsili_type text,
  tafsili_id uuid,
  tafsili_name text,
  line_no integer DEFAULT 0);

CREATE TABLE public.acc_vouchers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  number text,
  voucher_date date NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'draft'::text,
  source text DEFAULT 'manual'::text,
  source_id uuid,
  created_by uuid,
  posted_by uuid,
  posted_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.activity_log (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  actor_id uuid,
  action text NOT NULL,
  icon text,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.approvals (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  module text NOT NULL,
  record_id uuid NOT NULL,
  step_order integer NOT NULL,
  approver_id uuid,
  action text NOT NULL,
  note text,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.bom_history (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name text,
  final_price numeric,
  detail jsonb,
  bom_date date DEFAULT CURRENT_DATE,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.bot_config (
  id text NOT NULL DEFAULT 'main'::text,
  telegram_token text,
  webhook_secret text,
  ai_base_url text,
  ai_api_key text,
  ai_model text,
  updated_at timestamp with time zone DEFAULT now());

CREATE TABLE public.bot_log (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  telegram_chat_id text,
  question text,
  answer text,
  tool_calls jsonb,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.bot_sessions (
  chat_id text NOT NULL,
  step text,
  temp_username text,
  updated_at timestamp with time zone DEFAULT now());

CREATE TABLE public.bot_users (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  telegram_chat_id text NOT NULL,
  display_name text,
  role_label text,
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  profile_id uuid);

CREATE TABLE public.custom_form_records (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  form_id uuid,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text DEFAULT 'submitted'::text,
  current_step integer DEFAULT 1,
  submitted_by uuid,
  rejection_note text,
  created_at timestamp with time zone DEFAULT now(),
  escalated boolean DEFAULT false);

CREATE TABLE public.custom_forms (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  slug text NOT NULL,
  title text NOT NULL,
  description text,
  icon text DEFAULT '📄'::text,
  fields jsonb NOT NULL DEFAULT '[]'::jsonb,
  active boolean DEFAULT true,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  batch_mode boolean NOT NULL DEFAULT false);

CREATE TABLE public.customers (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  phone text,
  address text,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.daily_reports (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  date date NOT NULL,
  production numeric DEFAULT 0,
  waste numeric DEFAULT 0,
  downtime numeric DEFAULT 0,
  shift text,
  operator text,
  note text,
  formula_id uuid,
  day_name text,
  row_number text,
  roll_code text,
  meterage numeric DEFAULT 0,
  width_cm numeric DEFAULT 0,
  blade_spec text,
  material_temp numeric DEFAULT 0,
  motor_load_pct numeric DEFAULT 0,
  status text DEFAULT 'draft'::text,
  current_step integer DEFAULT 0,
  submitted_by uuid,
  rejection_note text,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  escalated boolean DEFAULT false,
  downtime_reason text,
  line text);

CREATE TABLE public.doc_signatures (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  module text NOT NULL,
  record_id text NOT NULL,
  profile_id uuid NOT NULL,
  role_label text,
  note text,
  signed_at timestamp with time zone NOT NULL DEFAULT now());

CREATE TABLE public.form_templates (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  owner_id uuid,
  form_type text NOT NULL,
  name text NOT NULL,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.formulas (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  grammage numeric,
  materials jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.goods_requests (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  req_date date NOT NULL DEFAULT CURRENT_DATE,
  requester_id uuid,
  department text,
  usage_location text,
  items jsonb NOT NULL DEFAULT '[]'::jsonb,
  status text DEFAULT 'pending_warehouse'::text,
  warehouse_approver_id uuid,
  warehouse_approved_at timestamp with time zone,
  receiver_id uuid,
  receiver_confirmed_at timestamp with time zone,
  rejection_note text,
  created_at timestamp with time zone DEFAULT now(),
  escalated boolean DEFAULT false);

CREATE TABLE public.hr_attendance (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL,
  att_date date NOT NULL,
  shift_id uuid,
  check_in time without time zone,
  check_out time without time zone,
  status text NOT NULL DEFAULT 'present'::text,
  overtime_min integer DEFAULT 0,
  delay_min integer DEFAULT 0,
  note text,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.hr_contracts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL,
  doc_type text NOT NULL DEFAULT 'contract'::text,
  title text,
  start_date date,
  end_date date,
  base_salary numeric DEFAULT 0,
  housing_allow numeric DEFAULT 0,
  food_allow numeric DEFAULT 0,
  child_allow numeric DEFAULT 0,
  other_allow numeric DEFAULT 0,
  note text,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.hr_employees (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  employee_code text,
  first_name text NOT NULL,
  last_name text NOT NULL,
  father_name text,
  national_id text,
  birth_date date,
  hire_date date,
  department text,
  "position" text,
  manager_id uuid,
  profile_id uuid,
  phone text,
  address text,
  education text,
  marital_status text,
  children_count integer DEFAULT 0,
  insurance_no text,
  bank_sheba text,
  note text,
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.hr_leaves (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL,
  kind text NOT NULL DEFAULT 'leave_daily'::text,
  from_date date NOT NULL,
  to_date date,
  from_time time without time zone,
  to_time time without time zone,
  reason text,
  status text NOT NULL DEFAULT 'submitted'::text,
  current_step integer DEFAULT 1,
  submitted_by uuid,
  rejection_note text,
  escalated boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.hr_payroll_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL,
  period text NOT NULL,
  item_type text NOT NULL,
  hours numeric,
  amount numeric DEFAULT 0,
  note text,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.hr_payslips (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL,
  period text NOT NULL,
  base_salary numeric DEFAULT 0,
  allowances numeric DEFAULT 0,
  overtime_amount numeric DEFAULT 0,
  bonus_amount numeric DEFAULT 0,
  deductions numeric DEFAULT 0,
  gross numeric DEFAULT 0,
  net numeric DEFAULT 0,
  detail jsonb,
  status text DEFAULT 'final'::text,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.hr_shifts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  start_time time without time zone,
  end_time time without time zone,
  note text);

CREATE TABLE public.inventory (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  paper_id uuid,
  sheets numeric DEFAULT 0,
  location text,
  min_stock numeric DEFAULT 0,
  alert_level numeric DEFAULT 0,
  updated_at timestamp with time zone DEFAULT now());

CREATE TABLE public.invoices (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  customer_id uuid,
  items jsonb NOT NULL DEFAULT '[]'::jsonb,
  total numeric DEFAULT 0,
  paid numeric DEFAULT 0,
  status text DEFAULT 'unpaid'::text,
  date date,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  number text,
  order_id uuid,
  customer_name text,
  invoice_date date,
  discount numeric DEFAULT 0,
  vat_pct numeric DEFAULT 0,
  vat_amount numeric DEFAULT 0,
  subtotal numeric DEFAULT 0,
  voucher_id uuid,
  note text);

CREATE TABLE public.letters (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  subject text NOT NULL,
  body text NOT NULL,
  sender_id uuid,
  recipient_id uuid,
  status text DEFAULT 'sent'::text,
  margin_note text,
  acknowledged_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  profile_id uuid,
  title text NOT NULL,
  body text,
  kind text,
  sent boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.org_roles (
  role_key text NOT NULL,
  label text NOT NULL,
  sort_order integer NOT NULL DEFAULT 100,
  builtin boolean NOT NULL DEFAULT false,
  active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now());

CREATE TABLE public.pack_presets (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  items jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.packaging_reports (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  report_date date,
  shift text,
  thickness text,
  pallet_weight numeric,
  pallet_serial text,
  net_weight numeric,
  dimensions text,
  qc_powder text,
  qc_spot text,
  qc_wave text,
  note text,
  status text NOT NULL DEFAULT 'submitted'::text,
  current_step integer NOT NULL DEFAULT 1,
  escalated boolean NOT NULL DEFAULT false,
  submitted_by uuid,
  rejection_note text,
  created_at timestamp with time zone NOT NULL DEFAULT now());

CREATE TABLE public.papers (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  code text,
  width numeric NOT NULL,
  length numeric NOT NULL,
  height numeric DEFAULT 0,
  thickness numeric DEFAULT 0,
  density numeric DEFAULT 0,
  dim_mode integer DEFAULT 2,
  sample_count numeric NOT NULL,
  sample_weight numeric NOT NULL,
  note text,
  reg_date date,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.production_stops (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  stop_date date NOT NULL,
  line text,
  shift text,
  stop_type text NOT NULL DEFAULT 'production'::text,
  duration_min integer NOT NULL DEFAULT 0,
  reason text,
  note text,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.profiles (
  id uuid NOT NULL,
  username text NOT NULL,
  name text,
  role_label text,
  role text,
  is_admin boolean DEFAULT false,
  color text DEFAULT '#10D970'::text,
  avatar text DEFAULT '👤'::text,
  active boolean DEFAULT true,
  perms jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.purchase_orders (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  supplier_id uuid,
  item text NOT NULL,
  qty numeric DEFAULT 0,
  price numeric DEFAULT 0,
  total numeric DEFAULT 0,
  date date,
  status text DEFAULT 'pending'::text,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.rawmats (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  stock numeric DEFAULT 0,
  price numeric DEFAULT 0,
  min_stock numeric DEFAULT 0,
  supplier_id uuid,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.sales_deliveries (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  number text,
  order_id uuid,
  customer_id uuid,
  customer_name text,
  delivery_date date NOT NULL,
  items jsonb DEFAULT '[]'::jsonb,
  warehouse text,
  note text,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.sales_orders (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  number text,
  doc_type text NOT NULL DEFAULT 'proforma'::text,
  customer_id uuid,
  customer_name text,
  order_date date NOT NULL,
  items jsonb DEFAULT '[]'::jsonb,
  discount numeric DEFAULT 0,
  vat_pct numeric DEFAULT 0,
  vat_amount numeric DEFAULT 0,
  subtotal numeric DEFAULT 0,
  total numeric DEFAULT 0,
  status text NOT NULL DEFAULT 'open'::text,
  note text,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.settings (
  key text NOT NULL,
  value jsonb);

CREATE TABLE public.sheeter_reports (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  date date NOT NULL,
  shift text,
  operators text,
  thickness numeric DEFAULT 0,
  dims_before text,
  dims_after text,
  pallet_count numeric DEFAULT 0,
  sheet_count numeric DEFAULT 0,
  pallet_weight numeric DEFAULT 0,
  waste numeric DEFAULT 0,
  work_duration text,
  downtime numeric DEFAULT 0,
  downtime_reason text,
  note text,
  status text DEFAULT 'draft'::text,
  current_step integer DEFAULT 0,
  submitted_by uuid,
  rejection_note text,
  escalated boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  line text);

CREATE TABLE public.suppliers (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  category text,
  contact text,
  phone text,
  city text,
  rating integer,
  note text,
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.treasury_accounts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  kind text NOT NULL DEFAULT 'cash'::text,
  bank_name text,
  account_no text,
  sheba text,
  opening_balance numeric DEFAULT 0,
  acc_account_id uuid,
  active boolean DEFAULT true,
  note text,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.treasury_checks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  direction text NOT NULL DEFAULT 'received'::text,
  amount numeric NOT NULL DEFAULT 0,
  due_date date,
  issue_date date,
  bank_name text,
  serial text,
  party_type text,
  party_id uuid,
  party_name text,
  treasury_account_id uuid,
  status text NOT NULL DEFAULT 'in_hand'::text,
  note text,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.treasury_transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  direction text NOT NULL DEFAULT 'receipt'::text,
  trans_date date NOT NULL,
  amount numeric NOT NULL DEFAULT 0,
  method text DEFAULT 'cash'::text,
  treasury_account_id uuid,
  check_id uuid,
  party_type text,
  party_id uuid,
  party_name text,
  description text,
  voucher_id uuid,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now());

CREATE TABLE public.user_signatures (
  profile_id uuid NOT NULL,
  image text NOT NULL,
  updated_at timestamp with time zone NOT NULL DEFAULT now());

CREATE TABLE public.workflow_templates (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  module text NOT NULL,
  step_order integer NOT NULL,
  approver_role text NOT NULL,
  step_label text);


-- #######################################################################
-- 3) CONSTRAINTS (PRIMARY KEY / UNIQUE / FOREIGN KEY / CHECK)
-- #######################################################################

ALTER TABLE ONLY public.acc_accounts ADD CONSTRAINT acc_accounts_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.acc_voucher_lines ADD CONSTRAINT acc_voucher_lines_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.acc_vouchers ADD CONSTRAINT acc_vouchers_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.activity_log ADD CONSTRAINT activity_log_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.approvals ADD CONSTRAINT approvals_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.bom_history ADD CONSTRAINT bom_history_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.bot_config ADD CONSTRAINT bot_config_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.bot_log ADD CONSTRAINT bot_log_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.bot_sessions ADD CONSTRAINT bot_sessions_pkey PRIMARY KEY (chat_id);
ALTER TABLE ONLY public.bot_users ADD CONSTRAINT bot_users_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.custom_form_records ADD CONSTRAINT custom_form_records_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.custom_forms ADD CONSTRAINT custom_forms_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.customers ADD CONSTRAINT customers_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.daily_reports ADD CONSTRAINT daily_reports_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.doc_signatures ADD CONSTRAINT doc_signatures_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.form_templates ADD CONSTRAINT form_templates_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.formulas ADD CONSTRAINT formulas_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.goods_requests ADD CONSTRAINT goods_requests_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.hr_attendance ADD CONSTRAINT hr_attendance_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.hr_contracts ADD CONSTRAINT hr_contracts_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.hr_employees ADD CONSTRAINT hr_employees_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.hr_leaves ADD CONSTRAINT hr_leaves_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.hr_payroll_items ADD CONSTRAINT hr_payroll_items_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.hr_payslips ADD CONSTRAINT hr_payslips_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.hr_shifts ADD CONSTRAINT hr_shifts_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.inventory ADD CONSTRAINT inventory_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.invoices ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.letters ADD CONSTRAINT letters_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.notifications ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.org_roles ADD CONSTRAINT org_roles_pkey PRIMARY KEY (role_key);
ALTER TABLE ONLY public.pack_presets ADD CONSTRAINT pack_presets_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.packaging_reports ADD CONSTRAINT packaging_reports_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.papers ADD CONSTRAINT papers_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.production_stops ADD CONSTRAINT production_stops_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.profiles ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.purchase_orders ADD CONSTRAINT purchase_orders_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.rawmats ADD CONSTRAINT rawmats_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.sales_deliveries ADD CONSTRAINT sales_deliveries_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.sales_orders ADD CONSTRAINT sales_orders_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.settings ADD CONSTRAINT settings_pkey PRIMARY KEY (key);
ALTER TABLE ONLY public.sheeter_reports ADD CONSTRAINT sheeter_reports_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.suppliers ADD CONSTRAINT suppliers_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.treasury_accounts ADD CONSTRAINT treasury_accounts_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.treasury_checks ADD CONSTRAINT treasury_checks_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.treasury_transactions ADD CONSTRAINT treasury_transactions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.user_signatures ADD CONSTRAINT user_signatures_pkey PRIMARY KEY (profile_id);
ALTER TABLE ONLY public.workflow_templates ADD CONSTRAINT workflow_templates_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.acc_accounts ADD CONSTRAINT acc_accounts_code_key UNIQUE (code);
ALTER TABLE ONLY public.bot_users ADD CONSTRAINT bot_users_telegram_chat_id_key UNIQUE (telegram_chat_id);
ALTER TABLE ONLY public.custom_forms ADD CONSTRAINT custom_forms_slug_key UNIQUE (slug);
ALTER TABLE ONLY public.doc_signatures ADD CONSTRAINT doc_signatures_module_record_id_profile_id_key UNIQUE (module, record_id, profile_id);
ALTER TABLE ONLY public.hr_payslips ADD CONSTRAINT hr_payslips_employee_id_period_key UNIQUE (employee_id, period);
ALTER TABLE ONLY public.profiles ADD CONSTRAINT profiles_username_key UNIQUE (username);
ALTER TABLE ONLY public.workflow_templates ADD CONSTRAINT workflow_templates_module_step_order_key UNIQUE (module, step_order);
ALTER TABLE ONLY public.approvals ADD CONSTRAINT approvals_action_check CHECK ((action = ANY (ARRAY['approved'::text, 'rejected'::text])));
ALTER TABLE ONLY public.acc_accounts ADD CONSTRAINT acc_accounts_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES acc_accounts(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.acc_voucher_lines ADD CONSTRAINT acc_voucher_lines_account_id_fkey FOREIGN KEY (account_id) REFERENCES acc_accounts(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.acc_voucher_lines ADD CONSTRAINT acc_voucher_lines_voucher_id_fkey FOREIGN KEY (voucher_id) REFERENCES acc_vouchers(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.activity_log ADD CONSTRAINT activity_log_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES profiles(id);
ALTER TABLE ONLY public.approvals ADD CONSTRAINT approvals_approver_id_fkey FOREIGN KEY (approver_id) REFERENCES profiles(id);
ALTER TABLE ONLY public.bom_history ADD CONSTRAINT bom_history_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);
ALTER TABLE ONLY public.bot_users ADD CONSTRAINT bot_users_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.custom_form_records ADD CONSTRAINT custom_form_records_form_id_fkey FOREIGN KEY (form_id) REFERENCES custom_forms(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.custom_form_records ADD CONSTRAINT custom_form_records_submitted_by_fkey FOREIGN KEY (submitted_by) REFERENCES profiles(id);
ALTER TABLE ONLY public.custom_forms ADD CONSTRAINT custom_forms_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);
ALTER TABLE ONLY public.daily_reports ADD CONSTRAINT daily_reports_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);
ALTER TABLE ONLY public.daily_reports ADD CONSTRAINT daily_reports_formula_id_fkey FOREIGN KEY (formula_id) REFERENCES formulas(id);
ALTER TABLE ONLY public.daily_reports ADD CONSTRAINT daily_reports_submitted_by_fkey FOREIGN KEY (submitted_by) REFERENCES profiles(id);
ALTER TABLE ONLY public.doc_signatures ADD CONSTRAINT doc_signatures_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.form_templates ADD CONSTRAINT form_templates_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES profiles(id);
ALTER TABLE ONLY public.formulas ADD CONSTRAINT formulas_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);
ALTER TABLE ONLY public.goods_requests ADD CONSTRAINT goods_requests_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES profiles(id);
ALTER TABLE ONLY public.goods_requests ADD CONSTRAINT goods_requests_requester_id_fkey FOREIGN KEY (requester_id) REFERENCES profiles(id);
ALTER TABLE ONLY public.goods_requests ADD CONSTRAINT goods_requests_warehouse_approver_id_fkey FOREIGN KEY (warehouse_approver_id) REFERENCES profiles(id);
ALTER TABLE ONLY public.hr_attendance ADD CONSTRAINT hr_attendance_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr_employees(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.hr_attendance ADD CONSTRAINT hr_attendance_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES hr_shifts(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.hr_contracts ADD CONSTRAINT hr_contracts_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr_employees(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.hr_employees ADD CONSTRAINT hr_employees_manager_id_fkey FOREIGN KEY (manager_id) REFERENCES hr_employees(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.hr_employees ADD CONSTRAINT hr_employees_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.hr_leaves ADD CONSTRAINT hr_leaves_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr_employees(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.hr_payroll_items ADD CONSTRAINT hr_payroll_items_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr_employees(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.hr_payslips ADD CONSTRAINT hr_payslips_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr_employees(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.inventory ADD CONSTRAINT inventory_paper_id_fkey FOREIGN KEY (paper_id) REFERENCES papers(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.invoices ADD CONSTRAINT invoices_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);
ALTER TABLE ONLY public.invoices ADD CONSTRAINT invoices_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customers(id);
ALTER TABLE ONLY public.letters ADD CONSTRAINT letters_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES profiles(id);
ALTER TABLE ONLY public.letters ADD CONSTRAINT letters_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES profiles(id);
ALTER TABLE ONLY public.pack_presets ADD CONSTRAINT pack_presets_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);
ALTER TABLE ONLY public.papers ADD CONSTRAINT papers_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);
ALTER TABLE ONLY public.profiles ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.purchase_orders ADD CONSTRAINT purchase_orders_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);
ALTER TABLE ONLY public.purchase_orders ADD CONSTRAINT purchase_orders_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES suppliers(id);
ALTER TABLE ONLY public.rawmats ADD CONSTRAINT rawmats_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES suppliers(id);
ALTER TABLE ONLY public.sales_deliveries ADD CONSTRAINT sales_deliveries_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.sales_deliveries ADD CONSTRAINT sales_deliveries_order_id_fkey FOREIGN KEY (order_id) REFERENCES sales_orders(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.sales_orders ADD CONSTRAINT sales_orders_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.sheeter_reports ADD CONSTRAINT sheeter_reports_submitted_by_fkey FOREIGN KEY (submitted_by) REFERENCES profiles(id);
ALTER TABLE ONLY public.treasury_accounts ADD CONSTRAINT treasury_accounts_acc_account_id_fkey FOREIGN KEY (acc_account_id) REFERENCES acc_accounts(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.treasury_checks ADD CONSTRAINT treasury_checks_treasury_account_id_fkey FOREIGN KEY (treasury_account_id) REFERENCES treasury_accounts(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.treasury_transactions ADD CONSTRAINT treasury_transactions_check_id_fkey FOREIGN KEY (check_id) REFERENCES treasury_checks(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.treasury_transactions ADD CONSTRAINT treasury_transactions_treasury_account_id_fkey FOREIGN KEY (treasury_account_id) REFERENCES treasury_accounts(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.treasury_transactions ADD CONSTRAINT treasury_transactions_voucher_id_fkey FOREIGN KEY (voucher_id) REFERENCES acc_vouchers(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.user_signatures ADD CONSTRAINT user_signatures_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;


-- #######################################################################
-- 4) INDEXES
-- #######################################################################

CREATE INDEX acc_vlines_account ON public.acc_voucher_lines USING btree (account_id);
CREATE INDEX acc_vlines_voucher ON public.acc_voucher_lines USING btree (voucher_id);
CREATE INDEX acc_vouchers_date ON public.acc_vouchers USING btree (voucher_date);
CREATE INDEX doc_signatures_lookup ON public.doc_signatures USING btree (module, record_id);
CREATE INDEX hr_attendance_emp_date ON public.hr_attendance USING btree (employee_id, att_date);
CREATE INDEX hr_payroll_emp_period ON public.hr_payroll_items USING btree (employee_id, period);
CREATE INDEX idx_activity_log_created ON public.activity_log USING btree (created_at DESC);
CREATE INDEX idx_bom_history_date ON public.bom_history USING btree (bom_date);
CREATE INDEX idx_daily_reports_date ON public.daily_reports USING btree (date);
CREATE INDEX idx_inventory_paper ON public.inventory USING btree (paper_id);
CREATE INDEX idx_invoices_customer ON public.invoices USING btree (customer_id);
CREATE INDEX idx_po_supplier ON public.purchase_orders USING btree (supplier_id);
CREATE INDEX idx_rawmats_supplier ON public.rawmats USING btree (supplier_id);
CREATE INDEX production_stops_date ON public.production_stops USING btree (stop_date);
CREATE INDEX treasury_checks_due ON public.treasury_checks USING btree (due_date);
CREATE INDEX treasury_trans_date ON public.treasury_transactions USING btree (trans_date);


-- #######################################################################
-- 5) ROW LEVEL SECURITY — فعال‌سازی
-- #######################################################################

ALTER TABLE public.acc_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.acc_voucher_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.acc_vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bom_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_form_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doc_signatures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.form_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.formulas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goods_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_leaves ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_payroll_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_payslips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.letters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.org_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pack_presets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.packaging_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.papers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.production_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rawmats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sheeter_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.treasury_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.treasury_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.treasury_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_signatures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflow_templates ENABLE ROW LEVEL SECURITY;


-- #######################################################################
-- 6) FUNCTIONS (SECURITY DEFINER)
-- #######################################################################

CREATE OR REPLACE FUNCTION public.has_perm(module text, min_level text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare user_perms jsonb; is_admin boolean; level text;
begin
  select perms, profiles.is_admin into user_perms, is_admin from profiles where id = auth.uid();
  if is_admin then return true; end if;
  level := user_perms ->> module;
  if level is null then return false; end if;
  if min_level = 'view' then return level in ('view','edit');
  elsif min_level = 'edit' then return level = 'edit';
  end if;
  return false;
end;
$function$;

CREATE OR REPLACE FUNCTION public.has_page_perm(pages text[], module text, min_level text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE user_perms jsonb; is_adm boolean; lvl text; p text; best text := NULL;
BEGIN
  SELECT perms, profiles.is_admin INTO user_perms, is_adm FROM profiles WHERE id = auth.uid();
  IF is_adm THEN RETURN true; END IF;
  IF user_perms IS NULL THEN RETURN false; END IF;
  FOREACH p IN ARRAY pages LOOP
    lvl := user_perms ->> p;
    IF lvl = 'edit' THEN best := 'edit';
    ELSIF lvl = 'view' AND (best IS NULL OR best = 'none') THEN best := 'view';
    ELSIF lvl = 'none' AND best IS NULL THEN best := 'none';
    END IF;
  END LOOP;
  IF best IS NULL THEN best := user_perms ->> module; END IF;
  IF best IS NULL OR best = 'none' THEN RETURN false; END IF;
  IF min_level = 'view' THEN RETURN best IN ('view','edit');
  ELSIF min_level = 'edit' THEN RETURN best = 'edit';
  END IF;
  RETURN false;
END$function$;

CREATE OR REPLACE FUNCTION public.current_user_has_role(check_role text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(is_admin,false) or role = check_role from profiles where id = auth.uid();
$function$;

CREATE OR REPLACE FUNCTION public.is_current_user_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(is_admin, false) from profiles where id = auth.uid();
$function$;

CREATE OR REPLACE FUNCTION public.can_approve_goods_warehouse()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(is_admin,false) or coalesce((perms->>'approve_goods_warehouse')::boolean,false)
  from profiles where id = auth.uid();
$function$;

CREATE OR REPLACE FUNCTION public.acknowledge_letter(p_id uuid, p_margin_note text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_letter record;
begin
  select * into v_letter from letters where id=p_id;
  if v_letter is null then return json_build_object('error','نامه پیدا نشد'); end if;
  if v_letter.recipient_id <> auth.uid() then return json_build_object('error','فقط مخاطب نامه می‌تواند تایید کند'); end if;
  update letters set status='acknowledged', acknowledged_at=now(), margin_note=coalesce(p_margin_note, margin_note) where id=p_id;
  return json_build_object('success', true);
end;
$function$;

CREATE OR REPLACE FUNCTION public.approve_custom_record(p_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_rec record; v_form record; v_step record; v_next record; v_role text; v_is_admin boolean;
begin
  select role, is_admin into v_role, v_is_admin from profiles where id=auth.uid();
  select * into v_rec from custom_form_records where id=p_id;
  if v_rec is null then return json_build_object('error','رکورد پیدا نشد'); end if;
  if v_rec.status <> 'submitted' then return json_build_object('error','این رکورد در وضعیت قابل تایید نیست'); end if;
  select * into v_form from custom_forms where id=v_rec.form_id;
  select * into v_step from workflow_templates where module=v_form.slug and step_order=v_rec.current_step;
  if v_step is null then return json_build_object('error','مرحله گردش کار پیدا نشد'); end if;
  if not (coalesce(v_is_admin,false) or v_role=v_step.approver_role or (v_rec.escalated and v_role='ceo')) then
    return json_build_object('error','اجازه تایید این مرحله را ندارید');
  end if;
  insert into approvals(module,record_id,step_order,approver_id,action) values (v_form.slug,p_id,v_rec.current_step,auth.uid(),'approved');
  select * into v_next from workflow_templates where module=v_form.slug and step_order=v_rec.current_step+1;
  if v_next is null then update custom_form_records set status='approved', current_step=0 where id=p_id;
  else update custom_form_records set current_step=v_next.step_order, escalated=false where id=p_id; end if;
  return json_build_object('success', true);
end;
$function$;

CREATE OR REPLACE FUNCTION public.approve_daily_report(p_id uuid, p_note text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_report record; v_step record; v_next record; v_role text; v_is_admin boolean;
begin
  select role, is_admin into v_role, v_is_admin from profiles where id = auth.uid();
  select * into v_report from daily_reports where id = p_id;
  if v_report is null then return json_build_object('error','رکورد پیدا نشد'); end if;
  if v_report.status <> 'submitted' then return json_build_object('error','این گزارش در وضعیت قابل تایید نیست'); end if;
  select * into v_step from workflow_templates where module='daily_reports' and step_order = v_report.current_step;
  if v_step is null then return json_build_object('error','مرحله گردش کار پیدا نشد'); end if;
  if not (coalesce(v_is_admin,false) or v_role = v_step.approver_role or (v_report.escalated and v_role='ceo')) then
    return json_build_object('error','اجازه تایید این مرحله را ندارید');
  end if;
  insert into approvals(module,record_id,step_order,approver_id,action) values ('daily_reports', p_id, v_report.current_step, auth.uid(), 'approved');
  select * into v_next from workflow_templates where module='daily_reports' and step_order = v_report.current_step + 1;
  if v_next is null then update daily_reports set status='approved', current_step=0 where id=p_id;
  else update daily_reports set current_step = v_next.step_order, escalated=false where id=p_id; end if;
  return json_build_object('success', true);
end;
$function$;

CREATE OR REPLACE FUNCTION public.approve_goods_request_warehouse(p_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_req record; v_ok boolean; v_role text;
begin
  select role into v_role from profiles where id=auth.uid();
  select * into v_req from goods_requests where id=p_id;
  if v_req is null then return json_build_object('error','رکورد پیدا نشد'); end if;
  if v_req.status <> 'pending_warehouse' then return json_build_object('error','این درخواست در وضعیت قابل تایید انبار نیست'); end if;
  select can_approve_goods_warehouse() into v_ok;
  if not (v_ok or (v_req.escalated and v_role='ceo')) then return json_build_object('error','اجازه تایید انبار را ندارید'); end if;
  update goods_requests set status='pending_receiver', warehouse_approver_id=auth.uid(), warehouse_approved_at=now(), escalated=false where id=p_id;
  return json_build_object('success', true);
end;
$function$;

CREATE OR REPLACE FUNCTION public.approve_hr_leave(p_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_rec record; v_step record; v_next record; v_role text; v_is_admin boolean;
begin
  select role, is_admin into v_role, v_is_admin from profiles where id=auth.uid();
  select * into v_rec from hr_leaves where id=p_id;
  if v_rec is null then return json_build_object('error','رکورد پیدا نشد'); end if;
  if v_rec.status <> 'submitted' then return json_build_object('error','این درخواست در وضعیت قابل تایید نیست'); end if;
  select * into v_step from workflow_templates where module='hr_leaves' and step_order=v_rec.current_step;
  if v_step is null then return json_build_object('error','مرحله گردش کار پیدا نشد'); end if;
  if not (coalesce(v_is_admin,false) or v_role=v_step.approver_role or (v_rec.escalated and v_role='ceo')) then
    return json_build_object('error','اجازه تایید این مرحله را ندارید');
  end if;
  insert into approvals(module,record_id,step_order,approver_id,action) values ('hr_leaves',p_id,v_rec.current_step,auth.uid(),'approved');
  select * into v_next from workflow_templates where module='hr_leaves' and step_order=v_rec.current_step+1;
  if v_next is null then update hr_leaves set status='approved', current_step=0 where id=p_id;
  else update hr_leaves set current_step=v_next.step_order, escalated=false where id=p_id; end if;
  return json_build_object('success', true);
end;$function$;

CREATE OR REPLACE FUNCTION public.approve_packaging_report(p_id uuid, p_note text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_report record; v_step record; v_next record; v_role text; v_is_admin boolean;
begin
  select role, is_admin into v_role, v_is_admin from profiles where id = auth.uid();
  select * into v_report from packaging_reports where id = p_id;
  if v_report is null then return json_build_object('error','رکورد پیدا نشد'); end if;
  if v_report.status <> 'submitted' then return json_build_object('error','این گزارش در وضعیت قابل تایید نیست'); end if;
  select * into v_step from workflow_templates where module='packaging' and step_order = v_report.current_step;
  if v_step is null then return json_build_object('error','مرحله گردش کار پیدا نشد'); end if;
  if not (coalesce(v_is_admin,false) or v_role = v_step.approver_role or (v_report.escalated and v_role='ceo')) then
    return json_build_object('error','اجازه تایید این مرحله را ندارید');
  end if;
  insert into approvals(module,record_id,step_order,approver_id,action) values ('packaging', p_id, v_report.current_step, auth.uid(), 'approved');
  select * into v_next from workflow_templates where module='packaging' and step_order = v_report.current_step + 1;
  if v_next is null then update packaging_reports set status='approved', current_step=0 where id=p_id;
  else update packaging_reports set current_step = v_next.step_order, escalated=false where id=p_id; end if;
  return json_build_object('success', true);
end;$function$;

CREATE OR REPLACE FUNCTION public.approve_sheeter_report(p_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_rec record; v_step record; v_next record; v_role text; v_is_admin boolean;
begin
  select role, is_admin into v_role, v_is_admin from profiles where id=auth.uid();
  select * into v_rec from sheeter_reports where id=p_id;
  if v_rec is null then return json_build_object('error','رکورد پیدا نشد'); end if;
  if v_rec.status <> 'submitted' then return json_build_object('error','این رکورد در وضعیت قابل تایید نیست'); end if;
  select * into v_step from workflow_templates where module='sheeter_reports' and step_order=v_rec.current_step;
  if v_step is null then return json_build_object('error','مرحله گردش کار پیدا نشد'); end if;
  if not (coalesce(v_is_admin,false) or v_role=v_step.approver_role or (v_rec.escalated and v_role='ceo')) then
    return json_build_object('error','اجازه تایید این مرحله را ندارید');
  end if;
  insert into approvals(module,record_id,step_order,approver_id,action) values ('sheeter_reports',p_id,v_rec.current_step,auth.uid(),'approved');
  select * into v_next from workflow_templates where module='sheeter_reports' and step_order=v_rec.current_step+1;
  if v_next is null then update sheeter_reports set status='approved', current_step=0 where id=p_id;
  else update sheeter_reports set current_step=v_next.step_order, escalated=false where id=p_id; end if;
  return json_build_object('success', true);
end;
$function$;

CREATE OR REPLACE FUNCTION public.bot_readonly_sql(p_sql text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare result jsonb; low text := lower(regexp_replace(p_sql,'\s+',' ','g'));
begin
  if p_sql is null or length(trim(p_sql))=0 then raise exception 'empty'; end if;
  if position(';' in rtrim(trim(p_sql),';')) > 0 then raise exception 'only a single statement is allowed'; end if;
  if low !~ '^\s*(select|with)\s' then raise exception 'only SELECT queries are allowed'; end if;
  if low ~ '\y(insert|update|delete|drop|alter|truncate|grant|revoke|create|comment|copy|vacuum|call|do|merge)\y' then
    raise exception 'write/DDL keywords are not allowed';
  end if;
  if low ~ '\y(auth|storage|vault|pg_catalog|information_schema|pg_)\.' then
    raise exception 'access to system schemas is not allowed';
  end if;
  perform set_config('statement_timeout','6000', true);
  perform set_config('transaction_read_only','on', true);
  execute 'select coalesce(jsonb_agg(t), ''[]''::jsonb) from ('||p_sql||') t limit 500' into result;
  return result;
end$function$;

CREATE OR REPLACE FUNCTION public.confirm_goods_request_receipt(p_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_req record;
begin
  select * into v_req from goods_requests where id=p_id;
  if v_req is null then return json_build_object('error','رکورد پیدا نشد'); end if;
  if v_req.status <> 'pending_receiver' then return json_build_object('error','این درخواست در وضعیت قابل تحویل نیست'); end if;
  if v_req.receiver_id <> auth.uid() then return json_build_object('error','فقط تحویل‌گیرنده تعیین‌شده می‌تواند تایید کند'); end if;
  update goods_requests set status='delivered', receiver_confirmed_at=now() where id=p_id;
  return json_build_object('success', true);
end;
$function$;

-- ⚠️ توجه: این تابع در محیط اصلی آدرس Edge Function را هاردکد داشت.
-- بعد از دیپلوی روی پروژه/سرور جدید، حتماً <YOUR_PROJECT_URL> را با
-- آدرس واقعی telegram-notify جایگزین کنید (یا از یک تنظیم در جدول
-- settings بخوانید) — وگرنه اعلان‌های تلگرام کار نمی‌کنند.
CREATE OR REPLACE FUNCTION public.forward_notification_to_telegram()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_secret text;
begin
  select webhook_secret into v_secret from bot_config where id='main';
  if v_secret is null then return NEW; end if;
  perform net.http_post(
    url := '<YOUR_PROJECT_URL>/functions/v1/telegram-notify?key='||v_secret,
    body := jsonb_build_object('id', NEW.id),
    headers := '{"Content-Type":"application/json"}'::jsonb
  );
  return NEW;
end$function$;

CREATE OR REPLACE FUNCTION public.notif_on_check_bounce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if NEW.status='bounced' and coalesce(OLD.status,'')<>'bounced' then
    insert into notifications(profile_id,title,body,kind)
    values (null,'⚠️ چک برگشتی', 'مبلغ '||to_char(NEW.amount,'FM999,999,999,999')||' ریال — '||coalesce(NEW.party_name,'—'),'check');
  end if;
  return NEW;
end$function$;

CREATE OR REPLACE FUNCTION public.notif_on_letter()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into notifications(profile_id,title,body,kind)
  values (NEW.recipient_id,'📨 نامه داخلی جدید', coalesce('موضوع: '||NEW.subject,'یک نامه جدید دریافت کردید'),'letter');
  return NEW;
end$function$;

CREATE OR REPLACE FUNCTION public.notif_on_submit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t text; b text;
begin
  if TG_TABLE_NAME='daily_reports' then t:='📈 گزارش تولید جدید'; b:='یک گزارش تولید در انتظار تایید ثبت شد';
  elsif TG_TABLE_NAME='sheeter_reports' then t:='✂️ گزارش شیتر جدید'; b:='یک گزارش شیتر در انتظار تایید ثبت شد';
  elsif TG_TABLE_NAME='goods_requests' then t:='📝 درخواست کالای جدید'; b:=coalesce('واحد: '||NEW.department,'درخواست کالا از انبار');
  elsif TG_TABLE_NAME='hr_leaves' then t:='🌴 درخواست مرخصی/ماموریت جدید'; b:='در انتظار تایید';
  elsif TG_TABLE_NAME='custom_form_records' then t:='📄 فرم جدید در انتظار تایید'; b:='یک رکورد فرم‌ساز ثبت شد';
  else t:='🔔 رکورد جدید'; b:=null; end if;
  insert into notifications(profile_id,title,body,kind) values (null,t,b,'submit');
  return NEW;
end$function$;

CREATE OR REPLACE FUNCTION public.post_voucher(p_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_deb numeric; v_cred numeric; v_status text;
begin
  if not has_page_perm(ARRAY['acc_vouchers'],'accounting','edit') then
    return json_build_object('error','دسترسی ندارید');
  end if;
  select status into v_status from acc_vouchers where id=p_id;
  if v_status is null then return json_build_object('error','سند پیدا نشد'); end if;
  select coalesce(sum(debit),0), coalesce(sum(credit),0) into v_deb, v_cred
    from acc_voucher_lines where voucher_id=p_id;
  if round(v_deb,2) <> round(v_cred,2) then
    return json_build_object('error','سند تراز نیست: بدهکار='||v_deb||' بستانکار='||v_cred);
  end if;
  if v_deb = 0 then return json_build_object('error','سند بدون مبلغ است'); end if;
  update acc_vouchers set status='posted', posted_by=auth.uid(), posted_at=now() where id=p_id;
  return json_build_object('success', true);
end;$function$;

CREATE OR REPLACE FUNCTION public.reject_custom_record(p_id uuid, p_note text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_rec record; v_form record; v_step record; v_role text; v_is_admin boolean;
begin
  select role, is_admin into v_role, v_is_admin from profiles where id=auth.uid();
  select * into v_rec from custom_form_records where id=p_id;
  if v_rec is null then return json_build_object('error','رکورد پیدا نشد'); end if;
  if v_rec.status <> 'submitted' then return json_build_object('error','این رکورد در وضعیت قابل رد نیست'); end if;
  select * into v_form from custom_forms where id=v_rec.form_id;
  select * into v_step from workflow_templates where module=v_form.slug and step_order=v_rec.current_step;
  if v_step is null then return json_build_object('error','مرحله گردش کار پیدا نشد'); end if;
  if not (coalesce(v_is_admin,false) or v_role=v_step.approver_role or (v_rec.escalated and v_role='ceo')) then
    return json_build_object('error','اجازه رد این مرحله را ندارید');
  end if;
  insert into approvals(module,record_id,step_order,approver_id,action,note) values (v_form.slug,p_id,v_rec.current_step,auth.uid(),'rejected',p_note);
  update custom_form_records set status='rejected', rejection_note=p_note where id=p_id;
  return json_build_object('success', true);
end;
$function$;

CREATE OR REPLACE FUNCTION public.reject_daily_report(p_id uuid, p_note text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_report record; v_step record; v_role text; v_is_admin boolean;
begin
  select role, is_admin into v_role, v_is_admin from profiles where id = auth.uid();
  select * into v_report from daily_reports where id = p_id;
  if v_report is null then return json_build_object('error','رکورد پیدا نشد'); end if;
  if v_report.status <> 'submitted' then return json_build_object('error','این گزارش در وضعیت قابل رد نیست'); end if;
  select * into v_step from workflow_templates where module='daily_reports' and step_order = v_report.current_step;
  if v_step is null then return json_build_object('error','مرحله گردش کار پیدا نشد'); end if;
  if not (coalesce(v_is_admin,false) or v_role = v_step.approver_role or (v_report.escalated and v_role='ceo')) then
    return json_build_object('error','اجازه رد این مرحله را ندارید');
  end if;
  insert into approvals(module,record_id,step_order,approver_id,action,note) values ('daily_reports', p_id, v_report.current_step, auth.uid(), 'rejected', p_note);
  update daily_reports set status='rejected', rejection_note=p_note where id=p_id;
  return json_build_object('success', true);
end;
$function$;

CREATE OR REPLACE FUNCTION public.reject_goods_request(p_id uuid, p_note text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_req record; v_ok boolean;
begin
  select * into v_req from goods_requests where id=p_id;
  if v_req is null then return json_build_object('error','رکورد پیدا نشد'); end if;
  select can_approve_goods_warehouse() into v_ok;
  if not v_ok and v_req.status<>'pending_warehouse' then return json_build_object('error','اجازه رد ندارید'); end if;
  update goods_requests set status='rejected', rejection_note=p_note where id=p_id;
  return json_build_object('success', true);
end;
$function$;

CREATE OR REPLACE FUNCTION public.reject_hr_leave(p_id uuid, p_note text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_rec record; v_step record; v_role text; v_is_admin boolean;
begin
  select role, is_admin into v_role, v_is_admin from profiles where id=auth.uid();
  select * into v_rec from hr_leaves where id=p_id;
  if v_rec is null then return json_build_object('error','رکورد پیدا نشد'); end if;
  if v_rec.status <> 'submitted' then return json_build_object('error','این درخواست در وضعیت قابل رد نیست'); end if;
  select * into v_step from workflow_templates where module='hr_leaves' and step_order=v_rec.current_step;
  if v_step is null then return json_build_object('error','مرحله گردش کار پیدا نشد'); end if;
  if not (coalesce(v_is_admin,false) or v_role=v_step.approver_role or (v_rec.escalated and v_role='ceo')) then
    return json_build_object('error','اجازه رد این مرحله را ندارید');
  end if;
  insert into approvals(module,record_id,step_order,approver_id,action,note) values ('hr_leaves',p_id,v_rec.current_step,auth.uid(),'rejected',p_note);
  update hr_leaves set status='rejected', rejection_note=p_note where id=p_id;
  return json_build_object('success', true);
end;$function$;

CREATE OR REPLACE FUNCTION public.reject_packaging_report(p_id uuid, p_note text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_report record; v_step record; v_role text; v_is_admin boolean;
begin
  select role, is_admin into v_role, v_is_admin from profiles where id = auth.uid();
  select * into v_report from packaging_reports where id = p_id;
  if v_report is null then return json_build_object('error','رکورد پیدا نشد'); end if;
  if v_report.status <> 'submitted' then return json_build_object('error','این گزارش در وضعیت قابل رد نیست'); end if;
  select * into v_step from workflow_templates where module='packaging' and step_order = v_report.current_step;
  if v_step is null then return json_build_object('error','مرحله گردش کار پیدا نشد'); end if;
  if not (coalesce(v_is_admin,false) or v_role = v_step.approver_role or (v_report.escalated and v_role='ceo')) then
    return json_build_object('error','اجازه رد این مرحله را ندارید');
  end if;
  insert into approvals(module,record_id,step_order,approver_id,action,note) values ('packaging', p_id, v_report.current_step, auth.uid(), 'rejected', p_note);
  update packaging_reports set status='rejected', rejection_note=p_note where id=p_id;
  return json_build_object('success', true);
end;$function$;

CREATE OR REPLACE FUNCTION public.reject_sheeter_report(p_id uuid, p_note text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_rec record; v_step record; v_role text; v_is_admin boolean;
begin
  select role, is_admin into v_role, v_is_admin from profiles where id=auth.uid();
  select * into v_rec from sheeter_reports where id=p_id;
  if v_rec is null then return json_build_object('error','رکورد پیدا نشد'); end if;
  if v_rec.status <> 'submitted' then return json_build_object('error','این رکورد در وضعیت قابل رد نیست'); end if;
  select * into v_step from workflow_templates where module='sheeter_reports' and step_order=v_rec.current_step;
  if v_step is null then return json_build_object('error','مرحله گردش کار پیدا نشد'); end if;
  if not (coalesce(v_is_admin,false) or v_role=v_step.approver_role or (v_rec.escalated and v_role='ceo')) then
    return json_build_object('error','اجازه رد این مرحله را ندارید');
  end if;
  insert into approvals(module,record_id,step_order,approver_id,action,note) values ('sheeter_reports',p_id,v_rec.current_step,auth.uid(),'rejected',p_note);
  update sheeter_reports set status='rejected', rejection_note=p_note where id=p_id;
  return json_build_object('success', true);
end;
$function$;

CREATE OR REPLACE FUNCTION public.resubmit_daily_report(p_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_report record; v_first_step record;
begin
  select * into v_report from daily_reports where id = p_id;
  if v_report is null then return json_build_object('error','رکورد پیدا نشد'); end if;
  if v_report.status <> 'rejected' then return json_build_object('error','فقط گزارش رد شده قابل ارسال دوباره است'); end if;
  if v_report.submitted_by <> auth.uid() and not (select coalesce(is_admin,false) from profiles where id=auth.uid()) then
    return json_build_object('error','فقط ثبت‌کننده اصلی می‌تواند دوباره ارسال کند');
  end if;
  select * into v_first_step from workflow_templates where module='daily_reports' order by step_order asc limit 1;
  update daily_reports set status='submitted', current_step=coalesce(v_first_step.step_order,0), rejection_note=null where id=p_id;
  return json_build_object('success', true);
end;
$function$;

CREATE OR REPLACE FUNCTION public.resubmit_packaging_report(p_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_report record;
begin
  select * into v_report from packaging_reports where id = p_id;
  if v_report is null then return json_build_object('error','رکورد پیدا نشد'); end if;
  if v_report.submitted_by <> auth.uid() and not coalesce((select is_admin from profiles where id=auth.uid()),false) then
    return json_build_object('error','اجازه ارسال مجدد ندارید'); end if;
  if v_report.status <> 'rejected' then return json_build_object('error','فقط گزارش ردشده قابل ارسال مجدد است'); end if;
  update packaging_reports set status='submitted', current_step=1, escalated=false, rejection_note=null where id=p_id;
  return json_build_object('success', true);
end;$function$;

CREATE OR REPLACE FUNCTION public.resubmit_sheeter_report(p_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_rec record; v_first_step record;
begin
  select * into v_rec from sheeter_reports where id=p_id;
  if v_rec is null then return json_build_object('error','رکورد پیدا نشد'); end if;
  if v_rec.status <> 'rejected' then return json_build_object('error','فقط رکورد رد‌شده قابل ارسال دوباره است'); end if;
  if v_rec.submitted_by <> auth.uid() and not (select coalesce(is_admin,false) from profiles where id=auth.uid()) then
    return json_build_object('error','فقط ثبت‌کننده اصلی می‌تواند دوباره ارسال کند');
  end if;
  select * into v_first_step from workflow_templates where module='sheeter_reports' order by step_order asc limit 1;
  update sheeter_reports set status='submitted', current_step=coalesce(v_first_step.step_order,0), rejection_note=null where id=p_id;
  return json_build_object('success', true);
end;
$function$;

CREATE OR REPLACE FUNCTION public.run_escalations()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update daily_reports set escalated=true
    where status='submitted' and escalated=false and created_at < now() - interval '24 hours';
  update goods_requests set escalated=true
    where status in ('pending_warehouse','pending_receiver') and escalated=false and created_at < now() - interval '24 hours';
  update custom_form_records set escalated=true
    where status='submitted' and escalated=false and created_at < now() - interval '24 hours';
  update sheeter_reports set escalated=true
    where status='submitted' and escalated=false and created_at < now() - interval '24 hours';
  update hr_leaves set escalated=true
    where status='submitted' and escalated=false and created_at < now() - interval '24 hours';
end;$function$;

CREATE OR REPLACE FUNCTION public.set_custom_form_workflow(p_slug text, p_steps jsonb)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_is_admin boolean; v_step jsonb;
begin
  select coalesce(is_admin,false) into v_is_admin from profiles where id=auth.uid();
  if not v_is_admin then return json_build_object('error','فقط ادمین می‌تواند گردش کار را تنظیم کند'); end if;
  delete from workflow_templates where module=p_slug;
  for v_step in select * from jsonb_array_elements(p_steps) loop
    insert into workflow_templates(module,step_order,approver_role,step_label)
      values (p_slug, (v_step->>'stepOrder')::int, v_step->>'approverRole', v_step->>'stepLabel');
  end loop;
  return json_build_object('success', true);
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_module_workflow(p_module text, p_steps jsonb)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_step jsonb; v_order int := 0;
begin
  if not has_perm('management','edit') then
    return json_build_object('error','فقط مدیر سیستم می‌تواند گردش کار را تغییر دهد');
  end if;
  if p_module is null or length(trim(p_module))=0 then
    return json_build_object('error','ماژول نامعتبر است');
  end if;
  delete from workflow_templates where module = p_module;
  for v_step in select * from jsonb_array_elements(coalesce(p_steps,'[]'::jsonb))
  loop
    if coalesce(v_step->>'approverRole','') <> '' then
      v_order := v_order + 1;
      insert into workflow_templates(module, step_order, approver_role, step_label)
      values (p_module, v_order, v_step->>'approverRole', nullif(v_step->>'stepLabel',''));
    end if;
  end loop;
  return json_build_object('success',true,'steps',v_order);
end;$function$;

CREATE OR REPLACE FUNCTION public.submit_custom_form(p_form_id uuid, p_data jsonb)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_form record; v_first_step record; v_rec_id uuid;
begin
  select * into v_form from custom_forms where id=p_form_id and active=true;
  if v_form is null then return json_build_object('error','فرم پیدا نشد یا غیرفعال است'); end if;
  select * into v_first_step from workflow_templates where module=v_form.slug order by step_order asc limit 1;
  insert into custom_form_records(form_id,data,status,current_step,submitted_by)
    values (p_form_id, p_data, 'submitted', coalesce(v_first_step.step_order,0), auth.uid())
    returning id into v_rec_id;
  if v_first_step is null then update custom_form_records set status='approved' where id=v_rec_id; end if;
  return json_build_object('success', true, 'id', v_rec_id);
end;
$function$;

CREATE OR REPLACE FUNCTION public.unpost_voucher(p_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not has_page_perm(ARRAY['acc_vouchers'],'accounting','edit') then
    return json_build_object('error','دسترسی ندارید');
  end if;
  update acc_vouchers set status='draft', posted_by=null, posted_at=null where id=p_id;
  return json_build_object('success', true);
end;$function$;


-- #######################################################################
-- 7) TRIGGERS
-- #######################################################################

CREATE TRIGGER trg_notif_cf AFTER INSERT ON public.custom_form_records FOR EACH ROW WHEN ((new.status = 'submitted'::text)) EXECUTE FUNCTION notif_on_submit();
CREATE TRIGGER trg_notif_daily AFTER INSERT ON public.daily_reports FOR EACH ROW WHEN ((new.status = 'submitted'::text)) EXECUTE FUNCTION notif_on_submit();
CREATE TRIGGER trg_notif_goods AFTER INSERT ON public.goods_requests FOR EACH ROW EXECUTE FUNCTION notif_on_submit();
CREATE TRIGGER trg_notif_leave AFTER INSERT ON public.hr_leaves FOR EACH ROW WHEN ((new.status = 'submitted'::text)) EXECUTE FUNCTION notif_on_submit();
CREATE TRIGGER trg_notif_letter AFTER INSERT ON public.letters FOR EACH ROW EXECUTE FUNCTION notif_on_letter();
CREATE TRIGGER trg_forward_notification AFTER INSERT ON public.notifications FOR EACH ROW EXECUTE FUNCTION forward_notification_to_telegram();
CREATE TRIGGER trg_notif_sheeter AFTER INSERT ON public.sheeter_reports FOR EACH ROW WHEN ((new.status = 'submitted'::text)) EXECUTE FUNCTION notif_on_submit();
CREATE TRIGGER trg_notif_check AFTER UPDATE ON public.treasury_checks FOR EACH ROW EXECUTE FUNCTION notif_on_check_bounce();


-- #######################################################################
-- 8) RLS POLICIES
-- #######################################################################

CREATE POLICY acc_accounts_del ON public.acc_accounts AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['acc_chart'::text], 'accounting'::text, 'edit'::text));
CREATE POLICY acc_accounts_ins ON public.acc_accounts AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['acc_chart'::text], 'accounting'::text, 'edit'::text));
CREATE POLICY acc_accounts_sel ON public.acc_accounts AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['acc_chart'::text, 'acc_vouchers'::text, 'acc_ledger'::text, 'acc_trial'::text], 'accounting'::text, 'view'::text));
CREATE POLICY acc_accounts_upd ON public.acc_accounts AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['acc_chart'::text], 'accounting'::text, 'edit'::text));
CREATE POLICY acc_vlines_del ON public.acc_voucher_lines AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['acc_vouchers'::text], 'accounting'::text, 'edit'::text));
CREATE POLICY acc_vlines_ins ON public.acc_voucher_lines AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['acc_vouchers'::text], 'accounting'::text, 'edit'::text));
CREATE POLICY acc_vlines_sel ON public.acc_voucher_lines AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['acc_vouchers'::text, 'acc_ledger'::text, 'acc_trial'::text], 'accounting'::text, 'view'::text));
CREATE POLICY acc_vlines_upd ON public.acc_voucher_lines AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['acc_vouchers'::text], 'accounting'::text, 'edit'::text));
CREATE POLICY acc_vouchers_del ON public.acc_vouchers AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['acc_vouchers'::text], 'accounting'::text, 'edit'::text));
CREATE POLICY acc_vouchers_ins ON public.acc_vouchers AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['acc_vouchers'::text], 'accounting'::text, 'edit'::text));
CREATE POLICY acc_vouchers_sel ON public.acc_vouchers AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['acc_vouchers'::text, 'acc_ledger'::text, 'acc_trial'::text], 'accounting'::text, 'view'::text));
CREATE POLICY acc_vouchers_upd ON public.acc_vouchers AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['acc_vouchers'::text], 'accounting'::text, 'edit'::text));
CREATE POLICY actlog_insert ON public.activity_log AS PERMISSIVE FOR INSERT TO public WITH CHECK ((auth.uid() IS NOT NULL));
CREATE POLICY actlog_select ON public.activity_log AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['actlog'::text], 'management'::text, 'view'::text));
CREATE POLICY approvals_insert ON public.approvals AS PERMISSIVE FOR INSERT TO public WITH CHECK ((auth.uid() IS NOT NULL));
CREATE POLICY approvals_read ON public.approvals AS PERMISSIVE FOR SELECT TO public USING ((auth.uid() IS NOT NULL));
CREATE POLICY planning_delete_bh ON public.bom_history AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['bom'::text], 'planning'::text, 'edit'::text));
CREATE POLICY planning_insert_bh ON public.bom_history AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['bom'::text], 'planning'::text, 'edit'::text));
CREATE POLICY planning_select_bh ON public.bom_history AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['bom'::text, 'pricehist'::text], 'planning'::text, 'view'::text));
CREATE POLICY planning_update_bh ON public.bom_history AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['bom'::text], 'planning'::text, 'edit'::text));
CREATE POLICY bot_log_admin_sel ON public.bot_log AS PERMISSIVE FOR SELECT TO public USING (is_current_user_admin());
CREATE POLICY bot_users_admin_del ON public.bot_users AS PERMISSIVE FOR DELETE TO public USING (is_current_user_admin());
CREATE POLICY bot_users_admin_ins ON public.bot_users AS PERMISSIVE FOR INSERT TO public WITH CHECK (is_current_user_admin());
CREATE POLICY bot_users_admin_sel ON public.bot_users AS PERMISSIVE FOR SELECT TO public USING (is_current_user_admin());
CREATE POLICY bot_users_admin_upd ON public.bot_users AS PERMISSIVE FOR UPDATE TO public USING (is_current_user_admin());
CREATE POLICY custom_records_insert ON public.custom_form_records AS PERMISSIVE FOR INSERT TO public WITH CHECK ((submitted_by = auth.uid()));
CREATE POLICY custom_records_select ON public.custom_form_records AS PERMISSIVE FOR SELECT TO public USING ((auth.uid() IS NOT NULL));
CREATE POLICY custom_records_update_none ON public.custom_form_records AS PERMISSIVE FOR UPDATE TO public USING (false);
CREATE POLICY custom_forms_admin_delete ON public.custom_forms AS PERMISSIVE FOR DELETE TO public USING (is_current_user_admin());
CREATE POLICY custom_forms_admin_update ON public.custom_forms AS PERMISSIVE FOR UPDATE TO public USING (is_current_user_admin());
CREATE POLICY custom_forms_admin_write ON public.custom_forms AS PERMISSIVE FOR INSERT TO public WITH CHECK (is_current_user_admin());
CREATE POLICY custom_forms_select ON public.custom_forms AS PERMISSIVE FOR SELECT TO public USING ((auth.uid() IS NOT NULL));
CREATE POLICY sales_delete_cust ON public.customers AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['customers'::text, 'sales'::text], 'sales'::text, 'edit'::text));
CREATE POLICY sales_insert_cust ON public.customers AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['customers'::text, 'sales'::text, 'sales_orders'::text], 'sales'::text, 'edit'::text));
CREATE POLICY sales_select_cust ON public.customers AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['customers'::text, 'sales'::text, 'sales_orders'::text, 'sales_delivery'::text, 'sales_aging'::text], 'sales'::text, 'view'::text));
CREATE POLICY sales_update_cust ON public.customers AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['customers'::text, 'sales'::text, 'sales_orders'::text], 'sales'::text, 'edit'::text));
CREATE POLICY dr_delete ON public.daily_reports AS PERMISSIVE FOR DELETE TO public USING (has_perm('management'::text, 'edit'::text));
CREATE POLICY dr_insert ON public.daily_reports AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['daily'::text], 'production'::text, 'edit'::text));
CREATE POLICY dr_select ON public.daily_reports AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['daily'::text], 'production'::text, 'view'::text));
CREATE POLICY dr_update ON public.daily_reports AS PERMISSIVE FOR UPDATE TO public USING ((has_perm('management'::text, 'edit'::text) OR ((submitted_by = auth.uid()) AND (status = ANY (ARRAY['draft'::text, 'rejected'::text]))) OR ((current_step = 1) AND current_user_has_role('production_planning'::text)) OR ((current_step = 2) AND current_user_has_role('ceo'::text))));
CREATE POLICY dsig_delete ON public.doc_signatures AS PERMISSIVE FOR DELETE TO public USING (((profile_id = auth.uid()) OR has_perm('management'::text, 'edit'::text)));
CREATE POLICY dsig_insert_self ON public.doc_signatures AS PERMISSIVE FOR INSERT TO public WITH CHECK ((profile_id = auth.uid()));
CREATE POLICY dsig_read ON public.doc_signatures AS PERMISSIVE FOR SELECT TO public USING ((auth.uid() IS NOT NULL));
CREATE POLICY templates_delete ON public.form_templates AS PERMISSIVE FOR DELETE TO public USING (((owner_id = auth.uid()) OR is_current_user_admin()));
CREATE POLICY templates_insert ON public.form_templates AS PERMISSIVE FOR INSERT TO public WITH CHECK ((owner_id = auth.uid()));
CREATE POLICY templates_select ON public.form_templates AS PERMISSIVE FOR SELECT TO public USING (((owner_id = auth.uid()) OR is_current_user_admin()));
CREATE POLICY planning_delete_f ON public.formulas AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['formulas'::text], 'planning'::text, 'edit'::text));
CREATE POLICY planning_insert_f ON public.formulas AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['formulas'::text], 'planning'::text, 'edit'::text));
CREATE POLICY planning_select_f ON public.formulas AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['formulas'::text, 'compare'::text, 'bom'::text], 'planning'::text, 'view'::text));
CREATE POLICY planning_update_f ON public.formulas AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['formulas'::text], 'planning'::text, 'edit'::text));
CREATE POLICY gr_delete ON public.goods_requests AS PERMISSIVE FOR DELETE TO public USING (has_perm('management'::text, 'edit'::text));
CREATE POLICY gr_insert ON public.goods_requests AS PERMISSIVE FOR INSERT TO public WITH CHECK ((auth.uid() IS NOT NULL));
CREATE POLICY gr_select ON public.goods_requests AS PERMISSIVE FOR SELECT TO public USING ((auth.uid() IS NOT NULL));
CREATE POLICY gr_update_none ON public.goods_requests AS PERMISSIVE FOR UPDATE TO public USING (false);
CREATE POLICY hr_att_delete ON public.hr_attendance AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['hr_attendance'::text], 'hr'::text, 'edit'::text));
CREATE POLICY hr_att_insert ON public.hr_attendance AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['hr_attendance'::text], 'hr'::text, 'edit'::text));
CREATE POLICY hr_att_select ON public.hr_attendance AS PERMISSIVE FOR SELECT TO public USING ((has_page_perm(ARRAY['hr_attendance'::text, 'hr_payslips'::text], 'hr'::text, 'view'::text) OR (EXISTS ( SELECT 1
   FROM hr_employees e
  WHERE ((e.id = hr_attendance.employee_id) AND (e.profile_id = auth.uid()))))));
CREATE POLICY hr_att_update ON public.hr_attendance AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['hr_attendance'::text], 'hr'::text, 'edit'::text));
CREATE POLICY hr_con_delete ON public.hr_contracts AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['hr_contracts'::text], 'hr'::text, 'edit'::text));
CREATE POLICY hr_con_insert ON public.hr_contracts AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['hr_contracts'::text], 'hr'::text, 'edit'::text));
CREATE POLICY hr_con_select ON public.hr_contracts AS PERMISSIVE FOR SELECT TO public USING ((has_page_perm(ARRAY['hr_contracts'::text, 'hr_payslips'::text], 'hr'::text, 'view'::text) OR (EXISTS ( SELECT 1
   FROM hr_employees e
  WHERE ((e.id = hr_contracts.employee_id) AND (e.profile_id = auth.uid()))))));
CREATE POLICY hr_con_update ON public.hr_contracts AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['hr_contracts'::text], 'hr'::text, 'edit'::text));
CREATE POLICY hr_emp_delete ON public.hr_employees AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['hr_employees'::text], 'hr'::text, 'edit'::text));
CREATE POLICY hr_emp_insert ON public.hr_employees AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['hr_employees'::text], 'hr'::text, 'edit'::text));
CREATE POLICY hr_emp_select ON public.hr_employees AS PERMISSIVE FOR SELECT TO public USING ((has_page_perm(ARRAY['hr_employees'::text, 'hr_org'::text, 'hr_contracts'::text, 'hr_attendance'::text, 'hr_leaves'::text, 'hr_payroll'::text, 'hr_payslips'::text], 'hr'::text, 'view'::text) OR (profile_id = auth.uid())));
CREATE POLICY hr_emp_update ON public.hr_employees AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['hr_employees'::text], 'hr'::text, 'edit'::text));
CREATE POLICY hr_leave_delete ON public.hr_leaves AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['hr_leaves'::text], 'hr'::text, 'edit'::text));
CREATE POLICY hr_leave_insert ON public.hr_leaves AS PERMISSIVE FOR INSERT TO public WITH CHECK (((submitted_by = auth.uid()) AND (has_page_perm(ARRAY['hr_leaves'::text], 'hr'::text, 'edit'::text) OR (EXISTS ( SELECT 1
   FROM hr_employees e
  WHERE ((e.id = hr_leaves.employee_id) AND (e.profile_id = auth.uid())))))));
CREATE POLICY hr_leave_select ON public.hr_leaves AS PERMISSIVE FOR SELECT TO public USING (((submitted_by = auth.uid()) OR has_page_perm(ARRAY['hr_leaves'::text], 'hr'::text, 'view'::text) OR (EXISTS ( SELECT 1
   FROM hr_employees e
  WHERE ((e.id = hr_leaves.employee_id) AND (e.profile_id = auth.uid()))))));
CREATE POLICY hr_leave_update_none ON public.hr_leaves AS PERMISSIVE FOR UPDATE TO public USING (false);
CREATE POLICY hr_pay_delete ON public.hr_payroll_items AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['hr_payroll'::text], 'hr'::text, 'edit'::text));
CREATE POLICY hr_pay_insert ON public.hr_payroll_items AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['hr_payroll'::text], 'hr'::text, 'edit'::text));
CREATE POLICY hr_pay_select ON public.hr_payroll_items AS PERMISSIVE FOR SELECT TO public USING ((has_page_perm(ARRAY['hr_payroll'::text, 'hr_payslips'::text], 'hr'::text, 'view'::text) OR (EXISTS ( SELECT 1
   FROM hr_employees e
  WHERE ((e.id = hr_payroll_items.employee_id) AND (e.profile_id = auth.uid()))))));
CREATE POLICY hr_pay_update ON public.hr_payroll_items AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['hr_payroll'::text], 'hr'::text, 'edit'::text));
CREATE POLICY hr_slip_delete ON public.hr_payslips AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['hr_payslips'::text], 'hr'::text, 'edit'::text));
CREATE POLICY hr_slip_insert ON public.hr_payslips AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['hr_payslips'::text], 'hr'::text, 'edit'::text));
CREATE POLICY hr_slip_select ON public.hr_payslips AS PERMISSIVE FOR SELECT TO public USING ((has_page_perm(ARRAY['hr_payslips'::text], 'hr'::text, 'view'::text) OR (EXISTS ( SELECT 1
   FROM hr_employees e
  WHERE ((e.id = hr_payslips.employee_id) AND (e.profile_id = auth.uid()))))));
CREATE POLICY hr_slip_update ON public.hr_payslips AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['hr_payslips'::text], 'hr'::text, 'edit'::text));
CREATE POLICY hr_shift_delete ON public.hr_shifts AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['hr_shifts'::text], 'hr'::text, 'edit'::text));
CREATE POLICY hr_shift_insert ON public.hr_shifts AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['hr_shifts'::text], 'hr'::text, 'edit'::text));
CREATE POLICY hr_shift_select ON public.hr_shifts AS PERMISSIVE FOR SELECT TO public USING ((auth.uid() IS NOT NULL));
CREATE POLICY hr_shift_update ON public.hr_shifts AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['hr_shifts'::text], 'hr'::text, 'edit'::text));
CREATE POLICY warehouse_delete_inv ON public.inventory AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['inventory'::text], 'warehouse'::text, 'edit'::text));
CREATE POLICY warehouse_insert_inv ON public.inventory AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['inventory'::text, 'newpaper'::text], 'warehouse'::text, 'edit'::text));
CREATE POLICY warehouse_select_inv ON public.inventory AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['inventory'::text], 'warehouse'::text, 'view'::text));
CREATE POLICY warehouse_update_inv ON public.inventory AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['inventory'::text, 'newpaper'::text], 'warehouse'::text, 'edit'::text));
CREATE POLICY sales_delete_inv ON public.invoices AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['sales'::text], 'sales'::text, 'edit'::text));
CREATE POLICY sales_insert_inv ON public.invoices AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['sales'::text], 'sales'::text, 'edit'::text));
CREATE POLICY sales_select_inv ON public.invoices AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['sales'::text, 'sales_orders'::text, 'sales_aging'::text], 'sales'::text, 'view'::text));
CREATE POLICY sales_update_inv ON public.invoices AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['sales'::text], 'sales'::text, 'edit'::text));
CREATE POLICY letters_insert ON public.letters AS PERMISSIVE FOR INSERT TO public WITH CHECK ((sender_id = auth.uid()));
CREATE POLICY letters_select ON public.letters AS PERMISSIVE FOR SELECT TO public USING (((sender_id = auth.uid()) OR (recipient_id = auth.uid()) OR has_perm('management'::text, 'edit'::text)));
CREATE POLICY letters_update_none ON public.letters AS PERMISSIVE FOR UPDATE TO public USING (false);
CREATE POLICY notif_insert ON public.notifications AS PERMISSIVE FOR INSERT TO public WITH CHECK ((auth.uid() IS NOT NULL));
CREATE POLICY notif_select ON public.notifications AS PERMISSIVE FOR SELECT TO public USING (((profile_id = auth.uid()) OR is_current_user_admin()));
CREATE POLICY org_roles_read ON public.org_roles AS PERMISSIVE FOR SELECT TO public USING ((auth.uid() IS NOT NULL));
CREATE POLICY org_roles_write ON public.org_roles AS PERMISSIVE FOR ALL TO public USING (has_perm('management'::text, 'edit'::text)) WITH CHECK (has_perm('management'::text, 'edit'::text));
CREATE POLICY planning_delete_pk ON public.pack_presets AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['packaging'::text], 'planning'::text, 'edit'::text));
CREATE POLICY planning_insert_pk ON public.pack_presets AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['packaging'::text], 'planning'::text, 'edit'::text));
CREATE POLICY planning_select_pk ON public.pack_presets AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['packaging'::text], 'planning'::text, 'view'::text));
CREATE POLICY planning_update_pk ON public.pack_presets AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['packaging'::text], 'planning'::text, 'edit'::text));
CREATE POLICY pk_delete ON public.packaging_reports AS PERMISSIVE FOR DELETE TO public USING (has_perm('management'::text, 'edit'::text));
CREATE POLICY pk_insert ON public.packaging_reports AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['packreport'::text], 'production'::text, 'edit'::text));
CREATE POLICY pk_select ON public.packaging_reports AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['packreport'::text], 'production'::text, 'view'::text));
CREATE POLICY pk_update ON public.packaging_reports AS PERMISSIVE FOR UPDATE TO public USING ((has_perm('management'::text, 'edit'::text) OR ((submitted_by = auth.uid()) AND (status = ANY (ARRAY['draft'::text, 'rejected'::text]))) OR ((current_step = 1) AND current_user_has_role('production_planning'::text)) OR ((current_step = 2) AND current_user_has_role('ceo'::text))));
CREATE POLICY warehouse_delete_p ON public.papers AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['papers'::text], 'warehouse'::text, 'edit'::text));
CREATE POLICY warehouse_insert_p ON public.papers AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['papers'::text, 'newpaper'::text], 'warehouse'::text, 'edit'::text));
CREATE POLICY warehouse_select_p ON public.papers AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['papers'::text, 'newpaper'::text, 'inventory'::text], 'warehouse'::text, 'view'::text));
CREATE POLICY warehouse_update_p ON public.papers AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['papers'::text, 'newpaper'::text], 'warehouse'::text, 'edit'::text));
CREATE POLICY stops_delete ON public.production_stops AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['stops'::text], 'production'::text, 'edit'::text));
CREATE POLICY stops_insert ON public.production_stops AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['stops'::text], 'production'::text, 'edit'::text));
CREATE POLICY stops_select ON public.production_stops AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['stops'::text], 'production'::text, 'view'::text));
CREATE POLICY stops_update ON public.production_stops AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['stops'::text], 'production'::text, 'edit'::text));
CREATE POLICY profiles_delete_admin ON public.profiles AS PERMISSIVE FOR DELETE TO public USING (is_current_user_admin());
CREATE POLICY profiles_insert_admin ON public.profiles AS PERMISSIVE FOR INSERT TO public WITH CHECK (is_current_user_admin());
CREATE POLICY profiles_select_self ON public.profiles AS PERMISSIVE FOR SELECT TO public USING (((id = auth.uid()) OR is_current_user_admin()));
CREATE POLICY profiles_update_admin ON public.profiles AS PERMISSIVE FOR UPDATE TO public USING (((id = auth.uid()) OR is_current_user_admin()));
CREATE POLICY supply_delete_po ON public.purchase_orders AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['purchase'::text], 'supply'::text, 'edit'::text));
CREATE POLICY supply_insert_po ON public.purchase_orders AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['purchase'::text], 'supply'::text, 'edit'::text));
CREATE POLICY supply_select_po ON public.purchase_orders AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['purchase'::text], 'supply'::text, 'view'::text));
CREATE POLICY supply_update_po ON public.purchase_orders AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['purchase'::text], 'supply'::text, 'edit'::text));
CREATE POLICY warehouse_delete_rm ON public.rawmats AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['rawmat'::text], 'warehouse'::text, 'edit'::text));
CREATE POLICY warehouse_insert_rm ON public.rawmats AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['rawmat'::text], 'warehouse'::text, 'edit'::text));
CREATE POLICY warehouse_select_rm ON public.rawmats AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['rawmat'::text], 'warehouse'::text, 'view'::text));
CREATE POLICY warehouse_update_rm ON public.rawmats AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['rawmat'::text], 'warehouse'::text, 'edit'::text));
CREATE POLICY sd_del ON public.sales_deliveries AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['sales_delivery'::text], 'sales'::text, 'edit'::text));
CREATE POLICY sd_ins ON public.sales_deliveries AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['sales_delivery'::text], 'sales'::text, 'edit'::text));
CREATE POLICY sd_sel ON public.sales_deliveries AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['sales_delivery'::text, 'sales'::text], 'sales'::text, 'view'::text));
CREATE POLICY sd_upd ON public.sales_deliveries AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['sales_delivery'::text], 'sales'::text, 'edit'::text));
CREATE POLICY so_del ON public.sales_orders AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['sales_orders'::text], 'sales'::text, 'edit'::text));
CREATE POLICY so_ins ON public.sales_orders AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['sales_orders'::text], 'sales'::text, 'edit'::text));
CREATE POLICY so_sel ON public.sales_orders AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['sales_orders'::text, 'sales_delivery'::text, 'sales'::text, 'sales_aging'::text], 'sales'::text, 'view'::text));
CREATE POLICY so_upd ON public.sales_orders AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['sales_orders'::text], 'sales'::text, 'edit'::text));
CREATE POLICY settings_select ON public.settings AS PERMISSIVE FOR SELECT TO public USING ((auth.uid() IS NOT NULL));
CREATE POLICY settings_update ON public.settings AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['target'::text], 'management'::text, 'edit'::text));
CREATE POLICY settings_upsert ON public.settings AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['target'::text], 'management'::text, 'edit'::text));
CREATE POLICY sheeter_delete ON public.sheeter_reports AS PERMISSIVE FOR DELETE TO public USING (has_perm('management'::text, 'edit'::text));
CREATE POLICY sheeter_insert ON public.sheeter_reports AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['sheeter'::text], 'production'::text, 'edit'::text));
CREATE POLICY sheeter_select ON public.sheeter_reports AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['sheeter'::text], 'production'::text, 'view'::text));
CREATE POLICY sheeter_update ON public.sheeter_reports AS PERMISSIVE FOR UPDATE TO public USING ((has_perm('management'::text, 'edit'::text) OR ((submitted_by = auth.uid()) AND (status = ANY (ARRAY['draft'::text, 'rejected'::text])))));
CREATE POLICY supply_delete_sup ON public.suppliers AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['suppliers'::text], 'supply'::text, 'edit'::text));
CREATE POLICY supply_insert_sup ON public.suppliers AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['suppliers'::text], 'supply'::text, 'edit'::text));
CREATE POLICY supply_select_sup ON public.suppliers AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['suppliers'::text], 'supply'::text, 'view'::text));
CREATE POLICY supply_update_sup ON public.suppliers AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['suppliers'::text], 'supply'::text, 'edit'::text));
CREATE POLICY tr_acc_del ON public.treasury_accounts AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['tr_accounts'::text], 'treasury'::text, 'edit'::text));
CREATE POLICY tr_acc_ins ON public.treasury_accounts AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['tr_accounts'::text], 'treasury'::text, 'edit'::text));
CREATE POLICY tr_acc_sel ON public.treasury_accounts AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['tr_accounts'::text, 'tr_checks'::text, 'tr_trans'::text], 'treasury'::text, 'view'::text));
CREATE POLICY tr_acc_upd ON public.treasury_accounts AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['tr_accounts'::text], 'treasury'::text, 'edit'::text));
CREATE POLICY tr_chk_del ON public.treasury_checks AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['tr_checks'::text], 'treasury'::text, 'edit'::text));
CREATE POLICY tr_chk_ins ON public.treasury_checks AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['tr_checks'::text], 'treasury'::text, 'edit'::text));
CREATE POLICY tr_chk_sel ON public.treasury_checks AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['tr_checks'::text, 'tr_trans'::text], 'treasury'::text, 'view'::text));
CREATE POLICY tr_chk_upd ON public.treasury_checks AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['tr_checks'::text], 'treasury'::text, 'edit'::text));
CREATE POLICY tr_trn_del ON public.treasury_transactions AS PERMISSIVE FOR DELETE TO public USING (has_page_perm(ARRAY['tr_trans'::text], 'treasury'::text, 'edit'::text));
CREATE POLICY tr_trn_ins ON public.treasury_transactions AS PERMISSIVE FOR INSERT TO public WITH CHECK (has_page_perm(ARRAY['tr_trans'::text], 'treasury'::text, 'edit'::text));
CREATE POLICY tr_trn_sel ON public.treasury_transactions AS PERMISSIVE FOR SELECT TO public USING (has_page_perm(ARRAY['tr_trans'::text, 'tr_checks'::text], 'treasury'::text, 'view'::text));
CREATE POLICY tr_trn_upd ON public.treasury_transactions AS PERMISSIVE FOR UPDATE TO public USING (has_page_perm(ARRAY['tr_trans'::text], 'treasury'::text, 'edit'::text));
CREATE POLICY usig_admin ON public.user_signatures AS PERMISSIVE FOR ALL TO public USING (has_perm('management'::text, 'edit'::text)) WITH CHECK (has_perm('management'::text, 'edit'::text));
CREATE POLICY usig_read ON public.user_signatures AS PERMISSIVE FOR SELECT TO public USING ((auth.uid() IS NOT NULL));
CREATE POLICY usig_write_self ON public.user_signatures AS PERMISSIVE FOR ALL TO public USING ((profile_id = auth.uid())) WITH CHECK ((profile_id = auth.uid()));
CREATE POLICY workflow_templates_read ON public.workflow_templates AS PERMISSIVE FOR SELECT TO public USING ((auth.uid() IS NOT NULL));


-- #######################################################################
-- 9) GRANTS
-- #######################################################################

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.bot_readonly_sql(text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.run_escalations() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.forward_notification_to_telegram() TO anon;
GRANT EXECUTE ON FUNCTION public.notif_on_check_bounce() TO anon;
GRANT EXECUTE ON FUNCTION public.notif_on_letter() TO anon;
GRANT EXECUTE ON FUNCTION public.notif_on_submit() TO anon;


-- #######################################################################
-- 10) SEED — فقط تنظیمات پایه، بدون هیچ داده‌ی کسب‌وکاری
-- (بدون کاربر، بدون گزارش تولید، بدون فاکتور و ... — این‌ها را کاربران
--  واقعی از صفر وارد می‌کنند)
-- #######################################################################

INSERT INTO public.org_roles (role_key, label, sort_order, builtin, active) VALUES
  ('ceo',                  'مدیرعامل',           10, true, true),
  ('production_manager',   'مدیرتولید',          20, true, true),
  ('production_planning',  'برنامه‌ریزی تولید',   30, true, true),
  ('sales_manager',        'مدیرفروش',           40, true, true),
  ('commercial',           'بازرگانی',           50, true, true),
  ('finance',              'مالی',               60, true, true),
  ('warehouse_keeper',     'انباردار',           70, true, true),
  ('system_admin',         'مدیرسیستم',          80, true, true)
ON CONFLICT (role_key) DO NOTHING;

INSERT INTO public.workflow_templates (module, step_order, approver_role, step_label) VALUES
  ('daily_reports',   1, 'production_planning', 'تایید برنامه‌ریزی تولید'),
  ('daily_reports',   2, 'ceo',                  'تایید نهایی مدیرعامل'),
  ('sheeter_reports', 1, 'production_planning', 'تایید برنامه‌ریزی تولید'),
  ('sheeter_reports', 2, 'ceo',                  'تایید نهایی مدیرعامل'),
  ('packaging',       1, 'production_planning', 'برنامه‌ریزی تولید'),
  ('packaging',       2, 'ceo',                  'مدیرعامل'),
  ('hr_leaves',       1, 'ceo',                  'تایید مدیرعامل')
ON CONFLICT (module, step_order) DO NOTHING;

INSERT INTO public.settings (key, value) VALUES
  ('lang',  '"fa"'::jsonb),
  ('theme', '"dark"'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- سطر پیکربندی ربات تلگرام (خالی) — بعداً از داخل سایت پر می‌شود:
-- مدیریت ← ربات تلگرام
INSERT INTO public.bot_config (id) VALUES ('main') ON CONFLICT (id) DO NOTHING;


-- #######################################################################
-- 11) قدم بعدی — ساخت اولین کاربر (مدیر سیستم)
-- #######################################################################
-- این اسکریپت عمداً هیچ کاربری نمی‌سازد. برای ساخت اولین مدیر سیستم:
--
--   ۱. اگر از Supabase (ابری یا خودمیزبان) استفاده می‌کنید، از پنل
--      Authentication → Add User یک کاربر با ایمیل دلخواه بسازید،
--      یا Edge Function موجود در supabase/functions/admin-users را
--      دیپلوی کرده و از داخل سایت (مدیریت ← مدیریت کاربران) اولین
--      کاربر را بسازید.
--   ۲. سپس یک ردیف در profiles بسازید که id آن دقیقاً همان id کاربر
--      ساخته‌شده در auth.users باشد:
--
--   INSERT INTO public.profiles (id, username, name, role, role_label, is_admin, perms)
--   VALUES (
--     '<UUID کاربر از auth.users>',
--     'admin',
--     'مدیر سیستم',
--     'system_admin',
--     'مدیرسیستم',
--     true,
--     '{}'::jsonb
--   );
--
-- پس از این مرحله می‌توانید با این کاربر وارد سایت شوید و بقیه‌ی
-- کاربران، سمت‌ها و داده‌ها را از داخل خود سامانه اضافه کنید.
-- =====================================================================
