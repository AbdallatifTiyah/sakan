عدّل wrangler.toml وأنشئ src/worker.js:

- main = "src/worker.js"
- [assets] directory = "./public", binding = "ASSETS", run_worker_first = ["/admin/*"]

src/worker.js:
أي طلب مساره بيبلّش بـ /admin لازم يعدّي HTTP Basic Auth
مقابل env.ADMIN_USER و env.ADMIN_PASS.
لو فشل: رجّع 401 مع WWW-Authenticate: Basic realm="Sakan Admin".
لو نجح: مرّره لـ env.ASSETS.fetch(request).
أي مسار تاني: مرّره مباشرة لـ ASSETS.

لا تكتب كلمة المرور بالكود — من env فقط.