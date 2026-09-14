-- =====================================================================
-- ساخت اولین کاربر «مدیر سیستم»
-- =====================================================================
--
-- این فایل را بعد از نصب اسکیمای اصلی اجرا کنید.
-- فقط روی Supabase (ابری یا خودمیزبان) کار می‌کند، چون کاربر را در
-- جدول auth.users می‌سازد.
--
-- ❗ قبل از اجرا: دو خط زیر را با مقادیر دلخواه خودتان عوض کنید.
--    • نام کاربری فقط حروف انگلیسی و عدد (بدون فاصله، بدون فارسی)
--    • رمز عبور حداقل ۸ کاراکتر و قوی باشد
-- =====================================================================

DO $$
DECLARE
  -- ↓↓↓ این دو خط را عوض کنید ↓↓↓
  v_username text := 'admin';
  v_password text := 'ChangeMe!2026';
  -- ↑↑↑ این دو خط را عوض کنید ↑↑↑

  v_name     text := 'مدیر سیستم';
  v_email    text;
  v_user_id  uuid;
BEGIN
  v_email := lower(v_username) || '@sanatsabz.local';

  IF length(v_password) < 8 THEN
    RAISE EXCEPTION 'رمز عبور باید حداقل ۸ کاراکتر باشد.';
  END IF;

  -- اگر همین کاربر از قبل هست، دوباره ساخته نمی‌شود
  SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;

  IF v_user_id IS NULL THEN
    v_user_id := gen_random_uuid();

    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data
    ) VALUES (
      '00000000-0000-0000-0000-000000000000',
      v_user_id,
      'authenticated',
      'authenticated',
      v_email,
      crypt(v_password, gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{}'::jsonb
    );
    RAISE NOTICE 'کاربر احراز هویت ساخته شد: %', v_email;
  ELSE
    RAISE NOTICE 'کاربر احراز هویت از قبل وجود داشت: %', v_email;
  END IF;

  -- پروفایل کاربر در خود سامانه (با دسترسی کامل مدیر سیستم)
  INSERT INTO public.profiles (id, username, name, role, role_label, is_admin, active, perms)
  VALUES (v_user_id, lower(v_username), v_name, 'system_admin', 'مدیرسیستم', true, true, '{}'::jsonb)
  ON CONFLICT (id) DO UPDATE
    SET is_admin = true, active = true, role = 'system_admin', role_label = 'مدیرسیستم';

  RAISE NOTICE '---------------------------------------------';
  RAISE NOTICE 'تمام شد. حالا می‌توانید وارد سامانه شوید:';
  RAISE NOTICE '   نام کاربری: %', lower(v_username);
  RAISE NOTICE '   رمز عبور  : (همانی که بالا گذاشتید)';
  RAISE NOTICE '---------------------------------------------';
END
$$;
