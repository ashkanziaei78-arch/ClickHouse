-- =====================================================================
-- سامانه ERP «پیشگامان صنعت سبز» — ساختار دیتابیس برای PostgreSQL
-- =====================================================================
-- این فایل خودکار از اسکیمای اصلی ساخته شده است.
-- مخصوص هاست یا سروری که PostgreSQL دارد (بدون Supabase).
--
-- روش اجرا:
--   psql -U کاربر -d نام_دیتابیس -f pgsql_schema.sql
--   یا در pgAdmin: Query Tool → باز کردن همین فایل → اجرا
--
-- نکته: کنترل دسترسی (که در نسخه‌ی سوپابیس با RLS بود) اینجا در
-- لایه‌ی PHP انجام می‌شود؛ پس هرگز دیتابیس را مستقیم روی اینترنت باز نکنید.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";


-- ---------------------------------------------------------- جدول‌ها

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


-- ---------------------------------------------- کلیدها و محدودیت‌ها

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


-- ------------------------------------------------------- ایندکس‌ها

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


-- --------------------------- جدول‌های مخصوص نسخه‌ی PHP (جایگزین Auth) ---

-- رمز کاربران (هش‌شده با bcrypt در PHP — رمز خام هرگز ذخیره نمی‌شود)
CREATE TABLE IF NOT EXISTS public.app_users (
  id            uuid PRIMARY KEY,
  username      text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  failed_tries  integer NOT NULL DEFAULT 0,
  locked_until  timestamp,
  created_at    timestamp NOT NULL DEFAULT (now() at time zone 'utc')
);

-- نشست‌های فعال کاربران
CREATE TABLE IF NOT EXISTS public.app_sessions (
  token      char(64) PRIMARY KEY,
  user_id    uuid NOT NULL,
  created_at timestamp NOT NULL DEFAULT (now() at time zone 'utc'),
  expires_at timestamp NOT NULL,
  ip         varchar(45)
);

CREATE INDEX IF NOT EXISTS app_sessions_user ON public.app_sessions (user_id);
CREATE INDEX IF NOT EXISTS app_sessions_exp  ON public.app_sessions (expires_at);


-- ------------------------------ داده‌ی پایه (بدون داده‌ی کسب‌وکاری) ---

INSERT INTO public.org_roles (role_key, label, sort_order, builtin, active) VALUES
  ('ceo','مدیرعامل',10,true,true),
  ('production_manager','مدیرتولید',20,true,true),
  ('production_planning','برنامه‌ریزی تولید',30,true,true),
  ('sales_manager','مدیرفروش',40,true,true),
  ('commercial','بازرگانی',50,true,true),
  ('finance','مالی',60,true,true),
  ('warehouse_keeper','انباردار',70,true,true),
  ('system_admin','مدیرسیستم',80,true,true)
ON CONFLICT (role_key) DO NOTHING;

INSERT INTO public.workflow_templates (module, step_order, approver_role, step_label) VALUES
  ('daily_reports',   1, 'production_planning', 'تایید برنامه‌ریزی تولید'),
  ('daily_reports',   2, 'ceo',                 'تایید نهایی مدیرعامل'),
  ('sheeter_reports', 1, 'production_planning', 'تایید برنامه‌ریزی تولید'),
  ('sheeter_reports', 2, 'ceo',                 'تایید نهایی مدیرعامل'),
  ('packaging',       1, 'production_planning', 'برنامه‌ریزی تولید'),
  ('packaging',       2, 'ceo',                 'مدیرعامل'),
  ('hr_leaves',       1, 'ceo',                 'تایید مدیرعامل')
ON CONFLICT (module, step_order) DO NOTHING;

INSERT INTO public.settings (key, value) VALUES
  ('lang',  '"fa"'::jsonb),
  ('theme', '"dark"'::jsonb)
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.bot_config (id) VALUES ('main') ON CONFLICT (id) DO NOTHING;

