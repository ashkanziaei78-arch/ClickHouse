<?php
/**
 * قوانین دسترسی — ترجمه‌ی خودکار از RLS پستگرس
 *
 * ⚠️ این فایل را دستی ویرایش نکنید.
 *    با اجرای deploy/php-mysql/build-policies.py دوباره ساخته می‌شود.
 *
 * معنی هر نوع:
 *   page    → دسترسی بر اساس صفحه‌ها و ماژول (مثل has_page_perm)
 *   module  → دسترسی بر اساس ماژول (مثل has_perm)
 *   admin   → فقط مدیر سیستم
 *   login   → هر کاربر واردشده
 *   deny    → از طریق API مستقیم ممنوع (فقط توابع گردش کار)
 *   special → منطق ویژه‌ی سطر-به-سطر (در lib.php پیاده شده)
 */

return [
    'acc_accounts' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['acc_chart'],
            'module' => 'accounting',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['acc_chart'],
            'module' => 'accounting',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['acc_chart', 'acc_vouchers', 'acc_ledger', 'acc_trial'],
            'module' => 'accounting',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['acc_chart'],
            'module' => 'accounting',
            'level' => 'edit'
        ]
    ],
    'acc_voucher_lines' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['acc_vouchers'],
            'module' => 'accounting',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['acc_vouchers'],
            'module' => 'accounting',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['acc_vouchers', 'acc_ledger', 'acc_trial'],
            'module' => 'accounting',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['acc_vouchers'],
            'module' => 'accounting',
            'level' => 'edit'
        ]
    ],
    'acc_vouchers' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['acc_vouchers'],
            'module' => 'accounting',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['acc_vouchers'],
            'module' => 'accounting',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['acc_vouchers', 'acc_ledger', 'acc_trial'],
            'module' => 'accounting',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['acc_vouchers'],
            'module' => 'accounting',
            'level' => 'edit'
        ]
    ],
    'activity_log' => [
        'INSERT' => [
            'type' => 'login'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['actlog'],
            'module' => 'management',
            'level' => 'view'
        ]
    ],
    'approvals' => [
        'INSERT' => [
            'type' => 'login'
        ],
        'SELECT' => [
            'type' => 'login'
        ]
    ],
    'bom_history' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['bom'],
            'module' => 'planning',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['bom'],
            'module' => 'planning',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['bom', 'pricehist'],
            'module' => 'planning',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['bom'],
            'module' => 'planning',
            'level' => 'edit'
        ]
    ],
    'bot_config' => [
        'SELECT' => [
            'type' => 'deny'
        ],
        'INSERT' => [
            'type' => 'deny'
        ],
        'UPDATE' => [
            'type' => 'deny'
        ],
        'DELETE' => [
            'type' => 'deny'
        ]
    ],
    'bot_log' => [
        'SELECT' => [
            'type' => 'admin'
        ]
    ],
    'bot_sessions' => [
        'SELECT' => [
            'type' => 'deny'
        ],
        'INSERT' => [
            'type' => 'deny'
        ],
        'UPDATE' => [
            'type' => 'deny'
        ],
        'DELETE' => [
            'type' => 'deny'
        ]
    ],
    'bot_users' => [
        'DELETE' => [
            'type' => 'admin'
        ],
        'INSERT' => [
            'type' => 'admin'
        ],
        'SELECT' => [
            'type' => 'admin'
        ],
        'UPDATE' => [
            'type' => 'admin'
        ]
    ],
    'custom_form_records' => [
        'INSERT' => [
            'type' => 'special',
            'handler' => 'own_only',
            'field' => 'submitted_by'
        ],
        'SELECT' => [
            'type' => 'login'
        ],
        'UPDATE' => [
            'type' => 'deny'
        ]
    ],
    'custom_forms' => [
        'DELETE' => [
            'type' => 'admin'
        ],
        'UPDATE' => [
            'type' => 'admin'
        ],
        'INSERT' => [
            'type' => 'admin'
        ],
        'SELECT' => [
            'type' => 'login'
        ]
    ],
    'customers' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['customers', 'sales'],
            'module' => 'sales',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['customers', 'sales', 'sales_orders'],
            'module' => 'sales',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['customers', 'sales', 'sales_orders', 'sales_delivery', 'sales_aging'],
            'module' => 'sales',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['customers', 'sales', 'sales_orders'],
            'module' => 'sales',
            'level' => 'edit'
        ]
    ],
    'daily_reports' => [
        'DELETE' => [
            'type' => 'module',
            'module' => 'management',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['daily'],
            'module' => 'production',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['daily'],
            'module' => 'production',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'special',
            'handler' => 'workflow_update'
        ]
    ],
    'doc_signatures' => [
        'DELETE' => [
            'type' => 'special',
            'handler' => 'signature_delete'
        ],
        'INSERT' => [
            'type' => 'special',
            'handler' => 'own_only',
            'field' => 'profile_id'
        ],
        'SELECT' => [
            'type' => 'login'
        ]
    ],
    'form_templates' => [
        'DELETE' => [
            'type' => 'special',
            'handler' => 'own_or_admin',
            'field' => 'owner_id'
        ],
        'INSERT' => [
            'type' => 'special',
            'handler' => 'own_only',
            'field' => 'owner_id'
        ],
        'SELECT' => [
            'type' => 'special',
            'handler' => 'own_or_admin',
            'field' => 'owner_id'
        ]
    ],
    'formulas' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['formulas'],
            'module' => 'planning',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['formulas'],
            'module' => 'planning',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['formulas', 'compare', 'bom'],
            'module' => 'planning',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['formulas'],
            'module' => 'planning',
            'level' => 'edit'
        ]
    ],
    'goods_requests' => [
        'DELETE' => [
            'type' => 'module',
            'module' => 'management',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'login'
        ],
        'SELECT' => [
            'type' => 'login'
        ],
        'UPDATE' => [
            'type' => 'deny'
        ]
    ],
    'hr_attendance' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['hr_attendance'],
            'module' => 'hr',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['hr_attendance'],
            'module' => 'hr',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'special',
            'handler' => 'hr_self_or_perm'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['hr_attendance'],
            'module' => 'hr',
            'level' => 'edit'
        ]
    ],
    'hr_contracts' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['hr_contracts'],
            'module' => 'hr',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['hr_contracts'],
            'module' => 'hr',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'special',
            'handler' => 'hr_self_or_perm'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['hr_contracts'],
            'module' => 'hr',
            'level' => 'edit'
        ]
    ],
    'hr_employees' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['hr_employees'],
            'module' => 'hr',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['hr_employees'],
            'module' => 'hr',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'special',
            'handler' => 'hr_self_or_perm'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['hr_employees'],
            'module' => 'hr',
            'level' => 'edit'
        ]
    ],
    'hr_leaves' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['hr_leaves'],
            'module' => 'hr',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'special',
            'handler' => 'hr_leave_insert'
        ],
        'SELECT' => [
            'type' => 'special',
            'handler' => 'hr_leave_select'
        ],
        'UPDATE' => [
            'type' => 'deny'
        ]
    ],
    'hr_payroll_items' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['hr_payroll'],
            'module' => 'hr',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['hr_payroll'],
            'module' => 'hr',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'special',
            'handler' => 'hr_self_or_perm'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['hr_payroll'],
            'module' => 'hr',
            'level' => 'edit'
        ]
    ],
    'hr_payslips' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['hr_payslips'],
            'module' => 'hr',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['hr_payslips'],
            'module' => 'hr',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'special',
            'handler' => 'hr_self_or_perm'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['hr_payslips'],
            'module' => 'hr',
            'level' => 'edit'
        ]
    ],
    'hr_shifts' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['hr_shifts'],
            'module' => 'hr',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['hr_shifts'],
            'module' => 'hr',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'login'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['hr_shifts'],
            'module' => 'hr',
            'level' => 'edit'
        ]
    ],
    'inventory' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['inventory'],
            'module' => 'warehouse',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['inventory', 'newpaper'],
            'module' => 'warehouse',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['inventory'],
            'module' => 'warehouse',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['inventory', 'newpaper'],
            'module' => 'warehouse',
            'level' => 'edit'
        ]
    ],
    'invoices' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['sales'],
            'module' => 'sales',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['sales'],
            'module' => 'sales',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['sales', 'sales_orders', 'sales_aging'],
            'module' => 'sales',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['sales'],
            'module' => 'sales',
            'level' => 'edit'
        ]
    ],
    'letters' => [
        'INSERT' => [
            'type' => 'special',
            'handler' => 'own_only',
            'field' => 'sender_id'
        ],
        'SELECT' => [
            'type' => 'special',
            'handler' => 'letters_select'
        ],
        'UPDATE' => [
            'type' => 'deny'
        ]
    ],
    'notifications' => [
        'INSERT' => [
            'type' => 'login'
        ],
        'SELECT' => [
            'type' => 'special',
            'handler' => 'notif_select'
        ]
    ],
    'org_roles' => [
        'SELECT' => [
            'type' => 'login'
        ],
        'ALL' => [
            'type' => 'module',
            'module' => 'management',
            'level' => 'edit'
        ]
    ],
    'pack_presets' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['packaging'],
            'module' => 'planning',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['packaging'],
            'module' => 'planning',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['packaging'],
            'module' => 'planning',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['packaging'],
            'module' => 'planning',
            'level' => 'edit'
        ]
    ],
    'packaging_reports' => [
        'DELETE' => [
            'type' => 'module',
            'module' => 'management',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['packreport'],
            'module' => 'production',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['packreport'],
            'module' => 'production',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'special',
            'handler' => 'workflow_update'
        ]
    ],
    'papers' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['papers'],
            'module' => 'warehouse',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['papers', 'newpaper'],
            'module' => 'warehouse',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['papers', 'newpaper', 'inventory'],
            'module' => 'warehouse',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['papers', 'newpaper'],
            'module' => 'warehouse',
            'level' => 'edit'
        ]
    ],
    'production_stops' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['stops'],
            'module' => 'production',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['stops'],
            'module' => 'production',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['stops'],
            'module' => 'production',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['stops'],
            'module' => 'production',
            'level' => 'edit'
        ]
    ],
    'profiles' => [
        'DELETE' => [
            'type' => 'admin'
        ],
        'INSERT' => [
            'type' => 'admin'
        ],
        'SELECT' => [
            'type' => 'special',
            'handler' => 'profile_self_or_admin'
        ],
        'UPDATE' => [
            'type' => 'special',
            'handler' => 'profile_self_or_admin'
        ]
    ],
    'purchase_orders' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['purchase'],
            'module' => 'supply',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['purchase'],
            'module' => 'supply',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['purchase'],
            'module' => 'supply',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['purchase'],
            'module' => 'supply',
            'level' => 'edit'
        ]
    ],
    'rawmats' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['rawmat'],
            'module' => 'warehouse',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['rawmat'],
            'module' => 'warehouse',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['rawmat'],
            'module' => 'warehouse',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['rawmat'],
            'module' => 'warehouse',
            'level' => 'edit'
        ]
    ],
    'sales_deliveries' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['sales_delivery'],
            'module' => 'sales',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['sales_delivery'],
            'module' => 'sales',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['sales_delivery', 'sales'],
            'module' => 'sales',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['sales_delivery'],
            'module' => 'sales',
            'level' => 'edit'
        ]
    ],
    'sales_orders' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['sales_orders'],
            'module' => 'sales',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['sales_orders'],
            'module' => 'sales',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['sales_orders', 'sales_delivery', 'sales', 'sales_aging'],
            'module' => 'sales',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['sales_orders'],
            'module' => 'sales',
            'level' => 'edit'
        ]
    ],
    'settings' => [
        'SELECT' => [
            'type' => 'login'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['target'],
            'module' => 'management',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['target'],
            'module' => 'management',
            'level' => 'edit'
        ]
    ],
    'sheeter_reports' => [
        'DELETE' => [
            'type' => 'module',
            'module' => 'management',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['sheeter'],
            'module' => 'production',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['sheeter'],
            'module' => 'production',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'special',
            'handler' => 'owner_or_admin_update'
        ]
    ],
    'suppliers' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['suppliers'],
            'module' => 'supply',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['suppliers'],
            'module' => 'supply',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['suppliers'],
            'module' => 'supply',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['suppliers'],
            'module' => 'supply',
            'level' => 'edit'
        ]
    ],
    'treasury_accounts' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['tr_accounts'],
            'module' => 'treasury',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['tr_accounts'],
            'module' => 'treasury',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['tr_accounts', 'tr_checks', 'tr_trans'],
            'module' => 'treasury',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['tr_accounts'],
            'module' => 'treasury',
            'level' => 'edit'
        ]
    ],
    'treasury_checks' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['tr_checks'],
            'module' => 'treasury',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['tr_checks'],
            'module' => 'treasury',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['tr_checks', 'tr_trans'],
            'module' => 'treasury',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['tr_checks'],
            'module' => 'treasury',
            'level' => 'edit'
        ]
    ],
    'treasury_transactions' => [
        'DELETE' => [
            'type' => 'page',
            'pages' => ['tr_trans'],
            'module' => 'treasury',
            'level' => 'edit'
        ],
        'INSERT' => [
            'type' => 'page',
            'pages' => ['tr_trans'],
            'module' => 'treasury',
            'level' => 'edit'
        ],
        'SELECT' => [
            'type' => 'page',
            'pages' => ['tr_trans', 'tr_checks'],
            'module' => 'treasury',
            'level' => 'view'
        ],
        'UPDATE' => [
            'type' => 'page',
            'pages' => ['tr_trans'],
            'module' => 'treasury',
            'level' => 'edit'
        ]
    ],
    'user_signatures' => [
        'ALL' => [
            'type' => 'special',
            'handler' => 'admin_or_own',
            'field' => 'profile_id'
        ],
        'SELECT' => [
            'type' => 'login'
        ]
    ],
    'workflow_templates' => [
        'SELECT' => [
            'type' => 'login'
        ]
    ],
];
