-- =====================================================================
-- سامانه ERP «پیشگامان صنعت سبز» — ساختار دیتابیس برای MySQL / MariaDB
-- =====================================================================
-- این فایل خودکار از اسکیمای اصلی PostgreSQL ساخته شده است.
-- مناسب هاست‌های معمولی (cPanel / دایرکت‌ادمین) با MySQL یا MariaDB.
--
-- روش اجرا در cPanel:
--   phpMyAdmin → دیتابیس خود را انتخاب کنید → سربرگ Import →
--   همین فایل را انتخاب و اجرا کنید.
--
-- نکته: کنترل دسترسی (که در نسخه‌ی PostgreSQL با RLS انجام می‌شد)
-- اینجا در لایه‌ی PHP پیاده شده است؛ چون MySQL چنین امکانی ندارد.
-- پس هیچ‌وقت به دیتابیس مستقیم از بیرون دسترسی ندهید.
-- =====================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';

CREATE TABLE IF NOT EXISTS `acc_accounts` (
  `id` CHAR(36) NOT NULL,
  `code` VARCHAR(191) NOT NULL,
  `name` TEXT NOT NULL,
  `level` TEXT NOT NULL DEFAULT 'kol',
  `parent_id` CHAR(36),
  `acc_type` TEXT NOT NULL DEFAULT 'asset',
  `nature` TEXT DEFAULT 'debit',
  `active` TINYINT(1) DEFAULT 1,
  `note` TEXT,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `acc_accounts_code_key` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `acc_voucher_lines` (
  `id` CHAR(36) NOT NULL,
  `voucher_id` CHAR(36) NOT NULL,
  `account_id` CHAR(36),
  `account_code` TEXT,
  `account_name` TEXT,
  `description` TEXT,
  `debit` DECIMAL(18,4) DEFAULT 0,
  `credit` DECIMAL(18,4) DEFAULT 0,
  `tafsili_type` TEXT,
  `tafsili_id` CHAR(36),
  `tafsili_name` TEXT,
  `line_no` INT DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `acc_vouchers` (
  `id` CHAR(36) NOT NULL,
  `number` TEXT,
  `voucher_date` DATE NOT NULL,
  `description` TEXT,
  `status` TEXT NOT NULL DEFAULT 'draft',
  `source` TEXT DEFAULT 'manual',
  `source_id` CHAR(36),
  `created_by` CHAR(36),
  `posted_by` CHAR(36),
  `posted_at` DATETIME,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `activity_log` (
  `id` CHAR(36) NOT NULL,
  `actor_id` CHAR(36),
  `action` TEXT NOT NULL,
  `icon` TEXT,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `approvals` (
  `id` CHAR(36) NOT NULL,
  `module` TEXT NOT NULL,
  `record_id` CHAR(36) NOT NULL,
  `step_order` INT NOT NULL,
  `approver_id` CHAR(36),
  `action` TEXT NOT NULL,
  `note` TEXT,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bom_history` (
  `id` CHAR(36) NOT NULL,
  `name` TEXT,
  `final_price` DECIMAL(18,4),
  `detail` JSON,
  `bom_date` DATE,
  `created_by` CHAR(36),
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bot_config` (
  `id` VARCHAR(191) NOT NULL DEFAULT 'main',
  `telegram_token` TEXT,
  `webhook_secret` TEXT,
  `ai_base_url` TEXT,
  `ai_api_key` TEXT,
  `ai_model` TEXT,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bot_log` (
  `id` CHAR(36) NOT NULL,
  `telegram_chat_id` TEXT,
  `question` TEXT,
  `answer` TEXT,
  `tool_calls` JSON,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bot_sessions` (
  `chat_id` VARCHAR(191) NOT NULL,
  `step` TEXT,
  `temp_username` TEXT,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`chat_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bot_users` (
  `id` CHAR(36) NOT NULL,
  `telegram_chat_id` VARCHAR(191) NOT NULL,
  `display_name` TEXT,
  `role_label` TEXT,
  `active` TINYINT(1) DEFAULT 1,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `profile_id` CHAR(36),
  PRIMARY KEY (`id`),
  UNIQUE KEY `bot_users_telegram_chat_id_key` (`telegram_chat_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `custom_form_records` (
  `id` CHAR(36) NOT NULL,
  `form_id` CHAR(36),
  `data` JSON NOT NULL,
  `status` TEXT DEFAULT 'submitted',
  `current_step` INT DEFAULT 1,
  `submitted_by` CHAR(36),
  `rejection_note` TEXT,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `escalated` TINYINT(1) DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `custom_forms` (
  `id` CHAR(36) NOT NULL,
  `slug` VARCHAR(191) NOT NULL,
  `title` TEXT NOT NULL,
  `description` TEXT,
  `icon` TEXT DEFAULT '📄',
  `fields` JSON NOT NULL,
  `active` TINYINT(1) DEFAULT 1,
  `created_by` CHAR(36),
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `batch_mode` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `custom_forms_slug_key` (`slug`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `customers` (
  `id` CHAR(36) NOT NULL,
  `name` TEXT NOT NULL,
  `phone` TEXT,
  `address` TEXT,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `daily_reports` (
  `id` CHAR(36) NOT NULL,
  `date` DATE NOT NULL,
  `production` DECIMAL(18,4) DEFAULT 0,
  `waste` DECIMAL(18,4) DEFAULT 0,
  `downtime` DECIMAL(18,4) DEFAULT 0,
  `shift` TEXT,
  `operator` TEXT,
  `note` TEXT,
  `formula_id` CHAR(36),
  `day_name` TEXT,
  `row_number` TEXT,
  `roll_code` TEXT,
  `meterage` DECIMAL(18,4) DEFAULT 0,
  `width_cm` DECIMAL(18,4) DEFAULT 0,
  `blade_spec` TEXT,
  `material_temp` DECIMAL(18,4) DEFAULT 0,
  `motor_load_pct` DECIMAL(18,4) DEFAULT 0,
  `status` TEXT DEFAULT 'draft',
  `current_step` INT DEFAULT 0,
  `submitted_by` CHAR(36),
  `rejection_note` TEXT,
  `created_by` CHAR(36),
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `escalated` TINYINT(1) DEFAULT 0,
  `downtime_reason` TEXT,
  `line` TEXT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `doc_signatures` (
  `id` CHAR(36) NOT NULL,
  `module` VARCHAR(191) NOT NULL,
  `record_id` VARCHAR(191) NOT NULL,
  `profile_id` CHAR(36) NOT NULL,
  `role_label` TEXT,
  `note` TEXT,
  `signed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `doc_signatures_module_record_id_profile_id_key` (`module`, `record_id`, `profile_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `form_templates` (
  `id` CHAR(36) NOT NULL,
  `owner_id` CHAR(36),
  `form_type` TEXT NOT NULL,
  `name` TEXT NOT NULL,
  `data` JSON NOT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `formulas` (
  `id` CHAR(36) NOT NULL,
  `name` TEXT NOT NULL,
  `grammage` DECIMAL(18,4),
  `materials` JSON NOT NULL,
  `created_by` CHAR(36),
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `goods_requests` (
  `id` CHAR(36) NOT NULL,
  `req_date` DATE NOT NULL,
  `requester_id` CHAR(36),
  `department` TEXT,
  `usage_location` TEXT,
  `items` JSON NOT NULL,
  `status` TEXT DEFAULT 'pending_warehouse',
  `warehouse_approver_id` CHAR(36),
  `warehouse_approved_at` DATETIME,
  `receiver_id` CHAR(36),
  `receiver_confirmed_at` DATETIME,
  `rejection_note` TEXT,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `escalated` TINYINT(1) DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `hr_attendance` (
  `id` CHAR(36) NOT NULL,
  `employee_id` CHAR(36) NOT NULL,
  `att_date` DATE NOT NULL,
  `shift_id` CHAR(36),
  `check_in` TIME,
  `check_out` TIME,
  `status` TEXT NOT NULL DEFAULT 'present',
  `overtime_min` INT DEFAULT 0,
  `delay_min` INT DEFAULT 0,
  `note` TEXT,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `hr_contracts` (
  `id` CHAR(36) NOT NULL,
  `employee_id` CHAR(36) NOT NULL,
  `doc_type` TEXT NOT NULL DEFAULT 'contract',
  `title` TEXT,
  `start_date` DATE,
  `end_date` DATE,
  `base_salary` DECIMAL(18,4) DEFAULT 0,
  `housing_allow` DECIMAL(18,4) DEFAULT 0,
  `food_allow` DECIMAL(18,4) DEFAULT 0,
  `child_allow` DECIMAL(18,4) DEFAULT 0,
  `other_allow` DECIMAL(18,4) DEFAULT 0,
  `note` TEXT,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `hr_employees` (
  `id` CHAR(36) NOT NULL,
  `employee_code` TEXT,
  `first_name` TEXT NOT NULL,
  `last_name` TEXT NOT NULL,
  `father_name` TEXT,
  `national_id` TEXT,
  `birth_date` DATE,
  `hire_date` DATE,
  `department` TEXT,
  `position` TEXT,
  `manager_id` CHAR(36),
  `profile_id` CHAR(36),
  `phone` TEXT,
  `address` TEXT,
  `education` TEXT,
  `marital_status` TEXT,
  `children_count` INT DEFAULT 0,
  `insurance_no` TEXT,
  `bank_sheba` TEXT,
  `note` TEXT,
  `active` TINYINT(1) DEFAULT 1,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `hr_leaves` (
  `id` CHAR(36) NOT NULL,
  `employee_id` CHAR(36) NOT NULL,
  `kind` TEXT NOT NULL DEFAULT 'leave_daily',
  `from_date` DATE NOT NULL,
  `to_date` DATE,
  `from_time` TIME,
  `to_time` TIME,
  `reason` TEXT,
  `status` TEXT NOT NULL DEFAULT 'submitted',
  `current_step` INT DEFAULT 1,
  `submitted_by` CHAR(36),
  `rejection_note` TEXT,
  `escalated` TINYINT(1) DEFAULT 0,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `hr_payroll_items` (
  `id` CHAR(36) NOT NULL,
  `employee_id` CHAR(36) NOT NULL,
  `period` VARCHAR(191) NOT NULL,
  `item_type` TEXT NOT NULL,
  `hours` DECIMAL(18,4),
  `amount` DECIMAL(18,4) DEFAULT 0,
  `note` TEXT,
  `created_by` CHAR(36),
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `hr_payslips` (
  `id` CHAR(36) NOT NULL,
  `employee_id` CHAR(36) NOT NULL,
  `period` VARCHAR(191) NOT NULL,
  `base_salary` DECIMAL(18,4) DEFAULT 0,
  `allowances` DECIMAL(18,4) DEFAULT 0,
  `overtime_amount` DECIMAL(18,4) DEFAULT 0,
  `bonus_amount` DECIMAL(18,4) DEFAULT 0,
  `deductions` DECIMAL(18,4) DEFAULT 0,
  `gross` DECIMAL(18,4) DEFAULT 0,
  `net` DECIMAL(18,4) DEFAULT 0,
  `detail` JSON,
  `status` TEXT DEFAULT 'final',
  `created_by` CHAR(36),
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `hr_payslips_employee_id_period_key` (`employee_id`, `period`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `hr_shifts` (
  `id` CHAR(36) NOT NULL,
  `name` TEXT NOT NULL,
  `start_time` TIME,
  `end_time` TIME,
  `note` TEXT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `inventory` (
  `id` CHAR(36) NOT NULL,
  `paper_id` CHAR(36),
  `sheets` DECIMAL(18,4) DEFAULT 0,
  `location` TEXT,
  `min_stock` DECIMAL(18,4) DEFAULT 0,
  `alert_level` DECIMAL(18,4) DEFAULT 0,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `invoices` (
  `id` CHAR(36) NOT NULL,
  `customer_id` CHAR(36),
  `items` JSON NOT NULL,
  `total` DECIMAL(18,4) DEFAULT 0,
  `paid` DECIMAL(18,4) DEFAULT 0,
  `status` TEXT DEFAULT 'unpaid',
  `date` DATE,
  `created_by` CHAR(36),
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `number` TEXT,
  `order_id` CHAR(36),
  `customer_name` TEXT,
  `invoice_date` DATE,
  `discount` DECIMAL(18,4) DEFAULT 0,
  `vat_pct` DECIMAL(18,4) DEFAULT 0,
  `vat_amount` DECIMAL(18,4) DEFAULT 0,
  `subtotal` DECIMAL(18,4) DEFAULT 0,
  `voucher_id` CHAR(36),
  `note` TEXT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `letters` (
  `id` CHAR(36) NOT NULL,
  `subject` TEXT NOT NULL,
  `body` TEXT NOT NULL,
  `sender_id` CHAR(36),
  `recipient_id` CHAR(36),
  `status` TEXT DEFAULT 'sent',
  `margin_note` TEXT,
  `acknowledged_at` DATETIME,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `notifications` (
  `id` CHAR(36) NOT NULL,
  `profile_id` CHAR(36),
  `title` TEXT NOT NULL,
  `body` TEXT,
  `kind` TEXT,
  `sent` TINYINT(1) DEFAULT 0,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `org_roles` (
  `role_key` VARCHAR(191) NOT NULL,
  `label` TEXT NOT NULL,
  `sort_order` INT NOT NULL DEFAULT 100,
  `builtin` TINYINT(1) NOT NULL DEFAULT 0,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`role_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pack_presets` (
  `id` CHAR(36) NOT NULL,
  `name` TEXT NOT NULL,
  `items` JSON NOT NULL,
  `created_by` CHAR(36),
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `packaging_reports` (
  `id` CHAR(36) NOT NULL,
  `report_date` DATE,
  `shift` TEXT,
  `thickness` TEXT,
  `pallet_weight` DECIMAL(18,4),
  `pallet_serial` TEXT,
  `net_weight` DECIMAL(18,4),
  `dimensions` TEXT,
  `qc_powder` TEXT,
  `qc_spot` TEXT,
  `qc_wave` TEXT,
  `note` TEXT,
  `status` TEXT NOT NULL DEFAULT 'submitted',
  `current_step` INT NOT NULL DEFAULT 1,
  `escalated` TINYINT(1) NOT NULL DEFAULT 0,
  `submitted_by` CHAR(36),
  `rejection_note` TEXT,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `papers` (
  `id` CHAR(36) NOT NULL,
  `name` TEXT NOT NULL,
  `code` TEXT,
  `width` DECIMAL(18,4) NOT NULL,
  `length` DECIMAL(18,4) NOT NULL,
  `height` DECIMAL(18,4) DEFAULT 0,
  `thickness` DECIMAL(18,4) DEFAULT 0,
  `density` DECIMAL(18,4) DEFAULT 0,
  `dim_mode` INT DEFAULT 2,
  `sample_count` DECIMAL(18,4) NOT NULL,
  `sample_weight` DECIMAL(18,4) NOT NULL,
  `note` TEXT,
  `reg_date` DATE,
  `created_by` CHAR(36),
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `production_stops` (
  `id` CHAR(36) NOT NULL,
  `stop_date` DATE NOT NULL,
  `line` TEXT,
  `shift` TEXT,
  `stop_type` TEXT NOT NULL DEFAULT 'production',
  `duration_min` INT NOT NULL DEFAULT 0,
  `reason` TEXT,
  `note` TEXT,
  `created_by` CHAR(36),
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `profiles` (
  `id` CHAR(36) NOT NULL,
  `username` VARCHAR(191) NOT NULL,
  `name` TEXT,
  `role_label` TEXT,
  `role` TEXT,
  `is_admin` TINYINT(1) DEFAULT 0,
  `color` TEXT DEFAULT '#10D970',
  `avatar` TEXT DEFAULT '👤',
  `active` TINYINT(1) DEFAULT 1,
  `perms` JSON,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `profiles_username_key` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `purchase_orders` (
  `id` CHAR(36) NOT NULL,
  `supplier_id` CHAR(36),
  `item` TEXT NOT NULL,
  `qty` DECIMAL(18,4) DEFAULT 0,
  `price` DECIMAL(18,4) DEFAULT 0,
  `total` DECIMAL(18,4) DEFAULT 0,
  `date` DATE,
  `status` TEXT DEFAULT 'pending',
  `created_by` CHAR(36),
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rawmats` (
  `id` CHAR(36) NOT NULL,
  `name` TEXT NOT NULL,
  `stock` DECIMAL(18,4) DEFAULT 0,
  `price` DECIMAL(18,4) DEFAULT 0,
  `min_stock` DECIMAL(18,4) DEFAULT 0,
  `supplier_id` CHAR(36),
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sales_deliveries` (
  `id` CHAR(36) NOT NULL,
  `number` TEXT,
  `order_id` CHAR(36),
  `customer_id` CHAR(36),
  `customer_name` TEXT,
  `delivery_date` DATE NOT NULL,
  `items` JSON,
  `warehouse` TEXT,
  `note` TEXT,
  `created_by` CHAR(36),
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sales_orders` (
  `id` CHAR(36) NOT NULL,
  `number` TEXT,
  `doc_type` TEXT NOT NULL DEFAULT 'proforma',
  `customer_id` CHAR(36),
  `customer_name` TEXT,
  `order_date` DATE NOT NULL,
  `items` JSON,
  `discount` DECIMAL(18,4) DEFAULT 0,
  `vat_pct` DECIMAL(18,4) DEFAULT 0,
  `vat_amount` DECIMAL(18,4) DEFAULT 0,
  `subtotal` DECIMAL(18,4) DEFAULT 0,
  `total` DECIMAL(18,4) DEFAULT 0,
  `status` TEXT NOT NULL DEFAULT 'open',
  `note` TEXT,
  `created_by` CHAR(36),
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `settings` (
  `key` VARCHAR(191) NOT NULL,
  `value` JSON,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sheeter_reports` (
  `id` CHAR(36) NOT NULL,
  `date` DATE NOT NULL,
  `shift` TEXT,
  `operators` TEXT,
  `thickness` DECIMAL(18,4) DEFAULT 0,
  `dims_before` TEXT,
  `dims_after` TEXT,
  `pallet_count` DECIMAL(18,4) DEFAULT 0,
  `sheet_count` DECIMAL(18,4) DEFAULT 0,
  `pallet_weight` DECIMAL(18,4) DEFAULT 0,
  `waste` DECIMAL(18,4) DEFAULT 0,
  `work_duration` TEXT,
  `downtime` DECIMAL(18,4) DEFAULT 0,
  `downtime_reason` TEXT,
  `note` TEXT,
  `status` TEXT DEFAULT 'draft',
  `current_step` INT DEFAULT 0,
  `submitted_by` CHAR(36),
  `rejection_note` TEXT,
  `escalated` TINYINT(1) DEFAULT 0,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `line` TEXT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `suppliers` (
  `id` CHAR(36) NOT NULL,
  `name` TEXT NOT NULL,
  `category` TEXT,
  `contact` TEXT,
  `phone` TEXT,
  `city` TEXT,
  `rating` INT,
  `note` TEXT,
  `active` TINYINT(1) DEFAULT 1,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `treasury_accounts` (
  `id` CHAR(36) NOT NULL,
  `name` TEXT NOT NULL,
  `kind` TEXT NOT NULL DEFAULT 'cash',
  `bank_name` TEXT,
  `account_no` TEXT,
  `sheba` TEXT,
  `opening_balance` DECIMAL(18,4) DEFAULT 0,
  `acc_account_id` CHAR(36),
  `active` TINYINT(1) DEFAULT 1,
  `note` TEXT,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `treasury_checks` (
  `id` CHAR(36) NOT NULL,
  `direction` TEXT NOT NULL DEFAULT 'received',
  `amount` DECIMAL(18,4) NOT NULL DEFAULT 0,
  `due_date` DATE,
  `issue_date` DATE,
  `bank_name` TEXT,
  `serial` TEXT,
  `party_type` TEXT,
  `party_id` CHAR(36),
  `party_name` TEXT,
  `treasury_account_id` CHAR(36),
  `status` TEXT NOT NULL DEFAULT 'in_hand',
  `note` TEXT,
  `created_by` CHAR(36),
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `treasury_transactions` (
  `id` CHAR(36) NOT NULL,
  `direction` TEXT NOT NULL DEFAULT 'receipt',
  `trans_date` DATE NOT NULL,
  `amount` DECIMAL(18,4) NOT NULL DEFAULT 0,
  `method` TEXT DEFAULT 'cash',
  `treasury_account_id` CHAR(36),
  `check_id` CHAR(36),
  `party_type` TEXT,
  `party_id` CHAR(36),
  `party_name` TEXT,
  `description` TEXT,
  `voucher_id` CHAR(36),
  `created_by` CHAR(36),
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `user_signatures` (
  `profile_id` CHAR(36) NOT NULL,
  `image` TEXT NOT NULL,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`profile_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `workflow_templates` (
  `id` CHAR(36) NOT NULL,
  `module` VARCHAR(191) NOT NULL,
  `step_order` INT NOT NULL,
  `approver_role` TEXT NOT NULL,
  `step_label` TEXT,
  PRIMARY KEY (`id`),
  UNIQUE KEY `workflow_templates_module_step_order_key` (`module`, `step_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------- ایندکس‌ها (سرعت گزارش‌ها) ----------
CREATE INDEX `acc_vlines_account` ON `acc_voucher_lines` (`account_id`);
CREATE INDEX `acc_vlines_voucher` ON `acc_voucher_lines` (`voucher_id`);
CREATE INDEX `acc_vouchers_date` ON `acc_vouchers` (`voucher_date`);
CREATE INDEX `doc_signatures_lookup` ON `doc_signatures` (`module`, `record_id`);
CREATE INDEX `hr_attendance_emp_date` ON `hr_attendance` (`employee_id`, `att_date`);
CREATE INDEX `hr_payroll_emp_period` ON `hr_payroll_items` (`employee_id`, `period`);
CREATE INDEX `idx_activity_log_created` ON `activity_log` (`created_at` DESC);
CREATE INDEX `idx_bom_history_date` ON `bom_history` (`bom_date`);
CREATE INDEX `idx_daily_reports_date` ON `daily_reports` (`date`);
CREATE INDEX `idx_inventory_paper` ON `inventory` (`paper_id`);
CREATE INDEX `idx_invoices_customer` ON `invoices` (`customer_id`);
CREATE INDEX `idx_po_supplier` ON `purchase_orders` (`supplier_id`);
CREATE INDEX `idx_rawmats_supplier` ON `rawmats` (`supplier_id`);
CREATE INDEX `production_stops_date` ON `production_stops` (`stop_date`);
CREATE INDEX `treasury_checks_due` ON `treasury_checks` (`due_date`);
CREATE INDEX `treasury_trans_date` ON `treasury_transactions` (`trans_date`);

-- ---------- ارتباط جدول‌ها ----------
ALTER TABLE `acc_accounts` ADD CONSTRAINT `acc_accounts_parent_id_fkey` FOREIGN KEY (`parent_id`) REFERENCES `acc_accounts` (`id`) ON DELETE SET NULL;
ALTER TABLE `acc_voucher_lines` ADD CONSTRAINT `acc_voucher_lines_account_id_fkey` FOREIGN KEY (`account_id`) REFERENCES `acc_accounts` (`id`) ON DELETE SET NULL;
ALTER TABLE `acc_voucher_lines` ADD CONSTRAINT `acc_voucher_lines_voucher_id_fkey` FOREIGN KEY (`voucher_id`) REFERENCES `acc_vouchers` (`id`) ON DELETE CASCADE;
ALTER TABLE `activity_log` ADD CONSTRAINT `activity_log_actor_id_fkey` FOREIGN KEY (`actor_id`) REFERENCES `profiles` (`id`);
ALTER TABLE `approvals` ADD CONSTRAINT `approvals_approver_id_fkey` FOREIGN KEY (`approver_id`) REFERENCES `profiles` (`id`);
ALTER TABLE `bom_history` ADD CONSTRAINT `bom_history_created_by_fkey` FOREIGN KEY (`created_by`) REFERENCES `profiles` (`id`);
ALTER TABLE `bot_users` ADD CONSTRAINT `bot_users_profile_id_fkey` FOREIGN KEY (`profile_id`) REFERENCES `profiles` (`id`) ON DELETE SET NULL;
ALTER TABLE `custom_form_records` ADD CONSTRAINT `custom_form_records_form_id_fkey` FOREIGN KEY (`form_id`) REFERENCES `custom_forms` (`id`) ON DELETE CASCADE;
ALTER TABLE `custom_form_records` ADD CONSTRAINT `custom_form_records_submitted_by_fkey` FOREIGN KEY (`submitted_by`) REFERENCES `profiles` (`id`);
ALTER TABLE `custom_forms` ADD CONSTRAINT `custom_forms_created_by_fkey` FOREIGN KEY (`created_by`) REFERENCES `profiles` (`id`);
ALTER TABLE `daily_reports` ADD CONSTRAINT `daily_reports_created_by_fkey` FOREIGN KEY (`created_by`) REFERENCES `profiles` (`id`);
ALTER TABLE `daily_reports` ADD CONSTRAINT `daily_reports_formula_id_fkey` FOREIGN KEY (`formula_id`) REFERENCES `formulas` (`id`);
ALTER TABLE `daily_reports` ADD CONSTRAINT `daily_reports_submitted_by_fkey` FOREIGN KEY (`submitted_by`) REFERENCES `profiles` (`id`);
ALTER TABLE `doc_signatures` ADD CONSTRAINT `doc_signatures_profile_id_fkey` FOREIGN KEY (`profile_id`) REFERENCES `profiles` (`id`) ON DELETE CASCADE;
ALTER TABLE `form_templates` ADD CONSTRAINT `form_templates_owner_id_fkey` FOREIGN KEY (`owner_id`) REFERENCES `profiles` (`id`);
ALTER TABLE `formulas` ADD CONSTRAINT `formulas_created_by_fkey` FOREIGN KEY (`created_by`) REFERENCES `profiles` (`id`);
ALTER TABLE `goods_requests` ADD CONSTRAINT `goods_requests_receiver_id_fkey` FOREIGN KEY (`receiver_id`) REFERENCES `profiles` (`id`);
ALTER TABLE `goods_requests` ADD CONSTRAINT `goods_requests_requester_id_fkey` FOREIGN KEY (`requester_id`) REFERENCES `profiles` (`id`);
ALTER TABLE `goods_requests` ADD CONSTRAINT `goods_requests_warehouse_approver_id_fkey` FOREIGN KEY (`warehouse_approver_id`) REFERENCES `profiles` (`id`);
ALTER TABLE `hr_attendance` ADD CONSTRAINT `hr_attendance_employee_id_fkey` FOREIGN KEY (`employee_id`) REFERENCES `hr_employees` (`id`) ON DELETE CASCADE;
ALTER TABLE `hr_attendance` ADD CONSTRAINT `hr_attendance_shift_id_fkey` FOREIGN KEY (`shift_id`) REFERENCES `hr_shifts` (`id`) ON DELETE SET NULL;
ALTER TABLE `hr_contracts` ADD CONSTRAINT `hr_contracts_employee_id_fkey` FOREIGN KEY (`employee_id`) REFERENCES `hr_employees` (`id`) ON DELETE CASCADE;
ALTER TABLE `hr_employees` ADD CONSTRAINT `hr_employees_manager_id_fkey` FOREIGN KEY (`manager_id`) REFERENCES `hr_employees` (`id`) ON DELETE SET NULL;
ALTER TABLE `hr_employees` ADD CONSTRAINT `hr_employees_profile_id_fkey` FOREIGN KEY (`profile_id`) REFERENCES `profiles` (`id`) ON DELETE SET NULL;
ALTER TABLE `hr_leaves` ADD CONSTRAINT `hr_leaves_employee_id_fkey` FOREIGN KEY (`employee_id`) REFERENCES `hr_employees` (`id`) ON DELETE CASCADE;
ALTER TABLE `hr_payroll_items` ADD CONSTRAINT `hr_payroll_items_employee_id_fkey` FOREIGN KEY (`employee_id`) REFERENCES `hr_employees` (`id`) ON DELETE CASCADE;
ALTER TABLE `hr_payslips` ADD CONSTRAINT `hr_payslips_employee_id_fkey` FOREIGN KEY (`employee_id`) REFERENCES `hr_employees` (`id`) ON DELETE CASCADE;
ALTER TABLE `inventory` ADD CONSTRAINT `inventory_paper_id_fkey` FOREIGN KEY (`paper_id`) REFERENCES `papers` (`id`) ON DELETE CASCADE;
ALTER TABLE `invoices` ADD CONSTRAINT `invoices_created_by_fkey` FOREIGN KEY (`created_by`) REFERENCES `profiles` (`id`);
ALTER TABLE `invoices` ADD CONSTRAINT `invoices_customer_id_fkey` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`);
ALTER TABLE `letters` ADD CONSTRAINT `letters_recipient_id_fkey` FOREIGN KEY (`recipient_id`) REFERENCES `profiles` (`id`);
ALTER TABLE `letters` ADD CONSTRAINT `letters_sender_id_fkey` FOREIGN KEY (`sender_id`) REFERENCES `profiles` (`id`);
ALTER TABLE `pack_presets` ADD CONSTRAINT `pack_presets_created_by_fkey` FOREIGN KEY (`created_by`) REFERENCES `profiles` (`id`);
ALTER TABLE `papers` ADD CONSTRAINT `papers_created_by_fkey` FOREIGN KEY (`created_by`) REFERENCES `profiles` (`id`);
ALTER TABLE `purchase_orders` ADD CONSTRAINT `purchase_orders_created_by_fkey` FOREIGN KEY (`created_by`) REFERENCES `profiles` (`id`);
ALTER TABLE `purchase_orders` ADD CONSTRAINT `purchase_orders_supplier_id_fkey` FOREIGN KEY (`supplier_id`) REFERENCES `suppliers` (`id`);
ALTER TABLE `rawmats` ADD CONSTRAINT `rawmats_supplier_id_fkey` FOREIGN KEY (`supplier_id`) REFERENCES `suppliers` (`id`);
ALTER TABLE `sales_deliveries` ADD CONSTRAINT `sales_deliveries_customer_id_fkey` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE SET NULL;
ALTER TABLE `sales_deliveries` ADD CONSTRAINT `sales_deliveries_order_id_fkey` FOREIGN KEY (`order_id`) REFERENCES `sales_orders` (`id`) ON DELETE SET NULL;
ALTER TABLE `sales_orders` ADD CONSTRAINT `sales_orders_customer_id_fkey` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE SET NULL;
ALTER TABLE `sheeter_reports` ADD CONSTRAINT `sheeter_reports_submitted_by_fkey` FOREIGN KEY (`submitted_by`) REFERENCES `profiles` (`id`);
ALTER TABLE `treasury_accounts` ADD CONSTRAINT `treasury_accounts_acc_account_id_fkey` FOREIGN KEY (`acc_account_id`) REFERENCES `acc_accounts` (`id`) ON DELETE SET NULL;
ALTER TABLE `treasury_checks` ADD CONSTRAINT `treasury_checks_treasury_account_id_fkey` FOREIGN KEY (`treasury_account_id`) REFERENCES `treasury_accounts` (`id`) ON DELETE SET NULL;
ALTER TABLE `treasury_transactions` ADD CONSTRAINT `treasury_transactions_check_id_fkey` FOREIGN KEY (`check_id`) REFERENCES `treasury_checks` (`id`) ON DELETE SET NULL;
ALTER TABLE `treasury_transactions` ADD CONSTRAINT `treasury_transactions_treasury_account_id_fkey` FOREIGN KEY (`treasury_account_id`) REFERENCES `treasury_accounts` (`id`) ON DELETE SET NULL;
ALTER TABLE `treasury_transactions` ADD CONSTRAINT `treasury_transactions_voucher_id_fkey` FOREIGN KEY (`voucher_id`) REFERENCES `acc_vouchers` (`id`) ON DELETE SET NULL;
ALTER TABLE `user_signatures` ADD CONSTRAINT `user_signatures_profile_id_fkey` FOREIGN KEY (`profile_id`) REFERENCES `profiles` (`id`) ON DELETE CASCADE;

-- ---------- جدول‌های مخصوص نسخه‌ی PHP (جایگزین Supabase Auth) ----------

-- رمز عبور کاربران (هش‌شده با bcrypt در PHP — رمز خام هرگز ذخیره نمی‌شود)
CREATE TABLE IF NOT EXISTS `app_users` (
  `id`            CHAR(36)     NOT NULL,
  `username`      VARCHAR(100) NOT NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `failed_tries`  INT          NOT NULL DEFAULT 0,
  `locked_until`  DATETIME     NULL,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `app_users_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- نشست‌های فعال (برای ورود کاربران)
CREATE TABLE IF NOT EXISTS `app_sessions` (
  `token`      CHAR(64)  NOT NULL,
  `user_id`    CHAR(36)  NOT NULL,
  `created_at` DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at` DATETIME  NOT NULL,
  `ip`         VARCHAR(45)  NULL,
  PRIMARY KEY (`token`),
  KEY `app_sessions_user` (`user_id`),
  KEY `app_sessions_exp`  (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------- داده‌ی پایه (بدون هیچ داده‌ی کسب‌وکاری) ----------

INSERT IGNORE INTO `org_roles` (`role_key`,`label`,`sort_order`,`builtin`,`active`,`created_at`) VALUES
  ('ceo','مدیرعامل',10,1,1,NOW()),
  ('production_manager','مدیرتولید',20,1,1,NOW()),
  ('production_planning','برنامه‌ریزی تولید',30,1,1,NOW()),
  ('sales_manager','مدیرفروش',40,1,1,NOW()),
  ('commercial','بازرگانی',50,1,1,NOW()),
  ('finance','مالی',60,1,1,NOW()),
  ('warehouse_keeper','انباردار',70,1,1,NOW()),
  ('system_admin','مدیرسیستم',80,1,1,NOW());

INSERT IGNORE INTO `workflow_templates` (`id`,`module`,`step_order`,`approver_role`,`step_label`) VALUES
  ('11111111-1111-4111-8111-000000000001','daily_reports',1,'production_planning','تایید برنامه‌ریزی تولید'),
  ('11111111-1111-4111-8111-000000000002','daily_reports',2,'ceo','تایید نهایی مدیرعامل'),
  ('11111111-1111-4111-8111-000000000003','sheeter_reports',1,'production_planning','تایید برنامه‌ریزی تولید'),
  ('11111111-1111-4111-8111-000000000004','sheeter_reports',2,'ceo','تایید نهایی مدیرعامل'),
  ('11111111-1111-4111-8111-000000000005','packaging',1,'production_planning','برنامه‌ریزی تولید'),
  ('11111111-1111-4111-8111-000000000006','packaging',2,'ceo','مدیرعامل'),
  ('11111111-1111-4111-8111-000000000007','hr_leaves',1,'ceo','تایید مدیرعامل');

INSERT IGNORE INTO `settings` (`key`,`value`) VALUES
  ('lang','"fa"'),
  ('theme','"dark"');

INSERT IGNORE INTO `bot_config` (`id`,`updated_at`) VALUES ('main', NOW());

SET FOREIGN_KEY_CHECKS = 1;
