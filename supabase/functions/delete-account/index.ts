import { createClient } from 'jsr:@supabase/supabase-js@2'

// حذف حساب Supabase Auth بالكامل — إلزامي لمتطلبات Apple App Store.
// service_role بيتقرأ من متغيّر بيئة الدالة (يحقنه Supabase تلقائياً)،
// ما بينكتب بأي ملف بالريبو ولا يوصل للتطبيق (قاعدة ٥ بـCLAUDE.md).
// حذف الهوية فقط — صفوف profiles تبقى (بدون قيد مفتاح خارجي على
// account_uid، موثّق بـCLAUDE.md)، نفس مبدأ "الحساب طبقة إضافية".
Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'يجب تسجيل الدخول' }), { status: 401 })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  })
  const { data: userData, error: userError } = await userClient.auth.getUser()
  if (userError || !userData?.user) {
    return new Response(JSON.stringify({ error: 'جلسة غير صالحة' }), { status: 401 })
  }

  const adminClient = createClient(supabaseUrl, serviceKey)
  const { error: deleteError } = await adminClient.auth.admin.deleteUser(userData.user.id)
  if (deleteError) {
    return new Response(JSON.stringify({ error: deleteError.message }), { status: 500 })
  }

  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
