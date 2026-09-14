/**
 * لایه‌ی ارتباط با بک‌اند PHP — جایگزین کتابخانه‌ی supabase-js
 *
 * این فایل یک شیء به نام sb می‌سازد که دقیقا همان متدهای سوپابیس را
 * دارد (from/rpc/auth/storage). برای همین، هیچ‌کدام از ۸۰۰۰ خط کد
 * سامانه لازم نیست عوض شود؛ فقط منبع داده زیرش تغییر می‌کند.
 */
(function () {
  'use strict';

  // اگر فایل‌های api کنار index.html باشند، همین مسیر درست است
  const API_BASE = (window.ERP_API_BASE || 'api').replace(/\/$/, '');
  const TOKEN_KEY = 'erp_token';

  const getToken = () => { try { return localStorage.getItem(TOKEN_KEY); } catch { return null; } };
  const setToken = t => {
    try { t ? localStorage.setItem(TOKEN_KEY, t) : localStorage.removeItem(TOKEN_KEY); } catch {}
  };

  async function call(file, payload) {
    let res, txt;
    try {
      res = await fetch(`${API_BASE}/${file}`, {
        method: 'POST',
        headers: Object.assign(
          { 'Content-Type': 'application/json' },
          getToken() ? { Authorization: 'Bearer ' + getToken() } : {}
        ),
        body: JSON.stringify(payload || {})
      });
      txt = await res.text();
    } catch (e) {
      return { data: null, error: { message: 'ارتباط با سرور برقرار نشد' } };
    }

    let json;
    try { json = txt ? JSON.parse(txt) : {}; }
    catch { return { data: null, error: { message: 'پاسخ نامعتبر از سرور' } }; }

    if (res.status === 401) {
      setToken(null);
      return { data: null, error: { message: json.error || 'نشست منقضی شده، دوباره وارد شوید' } };
    }
    if (!res.ok || json.error) {
      return { data: null, error: { message: json.error || ('خطای سرور ' + res.status) } };
    }
    return { data: json, error: null };
  }

  // ---------------------------------------------------------------- from()
  // فقط الگوهایی که سامانه واقعا استفاده می‌کند پشتیبانی می‌شوند
  function from(table) {
    const q = { table, _filters: [], _single: false };

    q.select = function () { return q; };
    q.eq = function (col, val) { q._filters.push([col, val]); return q; };
    q.neq = function () { return q; };
    q.single = function () { q._single = true; return q; };

    q.insert = function (row) { q._op = 'put'; q._row = row; return q; };
    q.upsert = function (row, opts) {
      q._op = 'put'; q._row = row;
      if (opts && opts.onConflict) q._key = opts.onConflict;
      return q;
    };
    q.delete = function () { q._op = 'del'; return q; };

    q.then = function (resolve, reject) { return q._run().then(resolve, reject); };

    q._run = async function () {
      if (q._op === 'put') {
        const r = await call('data.php', {
          op: 'put', table, row: q._row, keyField: q._key || 'id'
        });
        return { data: r.data ? r.data.row : null, error: r.error };
      }
      if (q._op === 'del') {
        const f = q._filters[0];
        const r = await call('data.php', {
          op: 'del', table, id: f ? f[1] : null, keyField: f ? f[0] : 'id'
        });
        return { data: null, error: r.error };
      }
      const r = await call('data.php', { op: 'getAll', table });
      if (r.error) return { data: null, error: r.error };
      let rows = r.data.rows || [];
      for (const [col, val] of q._filters) {
        const camel = col.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
        rows = rows.filter(x => x[camel] === val || x[col] === val);
      }
      return { data: q._single ? (rows[0] || null) : rows, error: null };
    };

    return q;
  }

  // ----------------------------------------------------------------- rpc()
  async function rpc(fn, params) {
    const r = await call('rpc.php', { fn, params: params || {} });
    return { data: r.data, error: r.error };
  }

  // ----------------------------------------------------------------- auth
  // رمز آخرین ورود موفق را نگه می‌داریم چون فرم «تغییر رمز» اول با رمز
  // فعلی وارد می‌شود و بعد رمز جدید را می‌فرستد (بدون اینکه رمز قبلی را پاس بدهد)
  let lastPassword = '';

  const withEmail = u => (u && !u.email && u.username)
    ? Object.assign({}, u, { email: u.username + '@sanatsabz.local' })
    : u;

  const auth = {
    async signInWithPassword({ email, password }) {
      // سامانه ایمیل ساختگی می‌سازد (user@sanatsabz.local) — فقط نامش را می‌گیریم
      const username = String(email || '').split('@')[0];
      const r = await call('auth.php', { action: 'login', username, password });
      if (r.error) return { data: null, error: r.error };
      setToken(r.data.token);
      lastPassword = password;
      return {
        data: { user: withEmail(r.data.user), session: { access_token: r.data.token } },
        error: null
      };
    },

    async signOut() {
      await call('auth.php', { action: 'logout' });
      setToken(null);
      return { error: null };
    },

    async getSession() {
      if (!getToken()) return { data: { session: null }, error: null };
      const r = await call('auth.php', { action: 'me' });
      if (r.error || !r.data.user) { setToken(null); return { data: { session: null }, error: null }; }
      return {
        data: { session: { access_token: getToken(), user: withEmail(r.data.user) } },
        error: null
      };
    },

    async getUser() {
      const r = await call('auth.php', { action: 'me' });
      return { data: { user: r.data ? withEmail(r.data.user) : null }, error: r.error };
    },

    async updateUser({ password }) {
      const r = await call('auth.php', {
        action: 'change_password', oldPassword: lastPassword, newPassword: password
      });
      if (!r.error) lastPassword = password;
      return { data: null, error: r.error };
    },

    onAuthStateChange() {
      return { data: { subscription: { unsubscribe() {} } } };
    }
  };

  // --------------------------------------------------------------- storage
  const storage = {
    from(bucket) {
      return {
        async upload(path, file) {
          const fd = new FormData();
          fd.append('file', file);
          fd.append('path', path);
          fd.append('bucket', bucket);
          try {
            const res = await fetch(`${API_BASE}/upload.php`, {
              method: 'POST',
              headers: getToken() ? { Authorization: 'Bearer ' + getToken() } : {},
              body: fd
            });
            const j = await res.json();
            if (!res.ok || j.error) return { data: null, error: { message: j.error || 'آپلود ناموفق' } };
            return { data: { path: j.path }, error: null };
          } catch {
            return { data: null, error: { message: 'ارتباط با سرور برقرار نشد' } };
          }
        },
        getPublicUrl(path) {
          return { data: { publicUrl: `uploads/${path}` } };
        },
        // بک‌آپ شبانه در نسخه‌ی هاست شخصی توسط خود هاست (cron) گرفته می‌شود
        async list() {
          return { data: [], error: null };
        },
        async download() {
          return { data: null, error: { message:
            'بک‌آپ‌ها روی خود هاست ذخیره می‌شوند — از بخش Backup پنل هاست دانلود کنید' } };
        }
      };
    }
  };

  // مدیریت کاربران — در نسخه‌ی سوپابیس یک Edge Function بود،
  // اینجا مستقیم به auth.php وصل می‌شود
  const functions = {
    async invoke(name, opts) {
      if (name !== 'admin-users') {
        return { data: null, error: { message: 'این قابلیت در نسخه‌ی هاست شخصی فعال نیست' } };
      }
      const b = (opts && opts.body) || {};
      const map = {
        create:         { action: 'admin_create_user' },
        reset_password: { action: 'admin_set_password' },
        set_active:     { action: 'admin_set_active' }
      };
      const m = map[b.action];
      if (!m) return { data: null, error: { message: 'عملیات نامعتبر' } };

      const r = await call('auth.php', Object.assign({}, m, {
        username: b.username, password: b.password, name: b.name,
        role: b.role, roleLabel: b.roleLabel, perms: b.perms,
        id: b.userId, active: b.active
      }));
      return { data: r.data, error: r.error };
    }
  };

  // ------------------------------------------------------ به‌روزرسانی زنده
  // سوپابیس از WebSocket استفاده می‌کرد؛ روی هاست اشتراکی چنین چیزی نداریم،
  // پس هر چند ثانیه یک درخواست سبک می‌فرستیم و اگر داده‌ای عوض شده بود
  // همان رویداد را صدا می‌زنیم. نتیجه برای کاربر یکی است.
  const POLL_MS = 20000;

  function channel() {
    const handlers = [];   // [{table, cb}]
    let timer = null, last = null;

    const ch = {
      on(_event, opts, cb) {
        if (opts && opts.table) handlers.push({ table: opts.table, cb });
        return ch;
      },
      subscribe() {
        if (timer) return ch;
        const tick = async () => {
          if (!getToken() || document.hidden) return;
          const r = await call('changes.php', {});
          if (r.error || !r.data) return;
          const now = r.data.stamps || {};
          if (last) {
            for (const h of handlers) {
              if (last[h.table] !== undefined &&
                  now[h.table] !== undefined &&
                  last[h.table] !== now[h.table]) {
                try { h.cb({ table: h.table, new: null }); } catch (e) {}
              }
            }
          }
          last = now;
        };
        tick();
        timer = setInterval(tick, POLL_MS);
        return ch;
      },
      unsubscribe() { if (timer) { clearInterval(timer); timer = null; } return ch; }
    };
    return ch;
  }

  function removeChannel(ch) { if (ch && ch.unsubscribe) ch.unsubscribe(); }

  window.supabase = {
    createClient() {
      return { from, rpc, auth, storage, functions, channel, removeChannel };
    }
  };
})();
