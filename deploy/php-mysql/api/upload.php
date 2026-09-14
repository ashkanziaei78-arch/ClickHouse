<?php
/** آپلود تصویر امضا — جایگزین Supabase Storage */
declare(strict_types=1);
require_once __DIR__ . '/lib.php';

$u = require_login();
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') fail('روش درخواست نامعتبر است', 405);
if (!isset($_FILES['file'])) fail('فایلی ارسال نشده');

$f = $_FILES['file'];
if ($f['error'] !== UPLOAD_ERR_OK) fail('خطا در آپلود فایل');
if ($f['size'] > MAX_UPLOAD_BYTES) fail('حجم فایل بیش از حد مجاز است');

// نوع فایل را از محتوا تشخیص می‌دهیم، نه از نام یا هدر مرورگر
$info = @getimagesize($f['tmp_name']);
$allowed = [IMAGETYPE_PNG => 'png', IMAGETYPE_JPEG => 'jpg', IMAGETYPE_WEBP => 'webp'];
if (!$info || !isset($allowed[$info[2]])) fail('فقط تصویر PNG یا JPG یا WEBP مجاز است');
$ext = $allowed[$info[2]];

$dir = __DIR__ . '/../uploads';
if (!is_dir($dir) && !@mkdir($dir, 0755, true)) fail_internal('cannot create uploads dir');

$name = uuid4() . '.' . $ext;
if (!move_uploaded_file($f['tmp_name'], $dir . '/' . $name)) {
    fail_internal('move_uploaded_file failed');
}
@chmod($dir . '/' . $name, 0644);

log_activity('آپلود تصویر امضا', '✍️');
json_out(['path' => $name, 'url' => 'uploads/' . $name]);
