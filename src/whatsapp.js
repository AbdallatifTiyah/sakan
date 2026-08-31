// تجهيز لواتساب Business API (Meta Cloud API) — غير مفعّل بعد، لأنه محتاج حساب حقيقي.
// لحد ما يصير الحساب جاهز، كل التواصل عبر واتساب شغّال يدوياً بروابط wa.me
// (زر "تذكير واتساب" باللوحة، "مشاركة واتساب" لرابط المالك، إلخ) — هاي بتضل شغّالة
// بغض النظر عن هالملف.
//
// ═══ شو محتاج قبل ما يشتغل هاد الملف ═══
// 1. حساب Meta Business Manager موثّق (verified business).
// 2. تطبيق WhatsApp على Meta for Developers، مربوط بالـBusiness Manager.
// 3. رقم هاتف مخصّص للمنصة (مش رقم شخصي مستخدم على واتساب عادي) — بينضاف ويتوثّق
//    من نفس التطبيق. Meta بتعطي رقم اختبار مجاني للتجربة قبل إضافة رقم حقيقي.
// 4. Permanent access token (System User token) — مش الـtoken المؤقت اللي بينتهي بـ٢٤ ساعة.
// 5. Phone Number ID (رقم داخلي من لوحة Meta، مش رقم الهاتف نفسه).
// 6. اعتماد قوالب الرسائل (message templates) — أي رسالة المنصة تبدأها (مش رد على رسالة
//    العميل خلال ٢٤ ساعة) لازم تكون بقالب معتمد من Meta مسبقاً. القوالب المطلوبة لسكن:
//      - sakan_listing_expiring  (تذكير المالك: إعلانه بدو تأكيد)
//      - sakan_owner_dashboard   (رابط لوحة المالك لأول مرة)
//      - sakan_institution_ack   (تأكيد استلام طلب مؤسسة)
//    تقديم القوالب وموافقة Meta عليها بياخذ من ساعات لأيام، خصوصاً أول مرة.
//
// ═══ بعد ما يصير الحساب جاهز ═══
// ضيف سرّين بـwrangler (ما ينكتبوا بأي ملف بالريبو — قاعدة ٥ بـCLAUDE.md):
//   npx wrangler secret put WHATSAPP_TOKEN
//   npx wrangler secret put WHATSAPP_PHONE_ID
// وبعدها استدعي sendWhatsAppTemplate() من worker.js بمكان الحدث المناسب
// (مثلاً: لما إعلان يوصل expiring_soon_days، أو لما admin_institution_lead_status
// يتحدّث لأول مرة). التنبيهات باللوحة (قسم "تنبيهات") هي المكان الطبيعي تستبدل
// فيه زر "تذكير واتساب" اليدوي بإرسال تلقائي، بس بعد ما تتأكد القوالب معتمدة.

const GRAPH_VERSION = "v20.0";

/**
 * يبعث رسالة قالب معتمد عبر WhatsApp Cloud API.
 * @param {object} env - Worker env (لازم فيه WHATSAPP_TOKEN و WHATSAPP_PHONE_ID)
 * @param {string} to - رقم المستلم بصيغة دولية بدون + (مثلاً "970599123456")
 * @param {string} templateName - اسم القالب المعتمد من Meta (زي sakan_listing_expiring)
 * @param {string[]} params - القيم اللي بتعبّي متغيرات القالب بالترتيب ({{1}}, {{2}}, ...)
 * @param {string} [langCode] - كود اللغة المعتمد للقالب (افتراضي: ar)
 */
export async function sendWhatsAppTemplate(env, to, templateName, params = [], langCode = "ar") {
  if (!env.WHATSAPP_TOKEN || !env.WHATSAPP_PHONE_ID) {
    throw new Error("WhatsApp API مش مجهّز — أضف WHATSAPP_TOKEN و WHATSAPP_PHONE_ID بأسرار wrangler أولاً.");
  }

  const url = `https://graph.facebook.com/${GRAPH_VERSION}/${env.WHATSAPP_PHONE_ID}/messages`;
  const body = {
    messaging_product: "whatsapp",
    to,
    type: "template",
    template: {
      name: templateName,
      language: { code: langCode },
      components: params.length
        ? [{ type: "body", parameters: params.map(text => ({ type: "text", text: String(text) })) }]
        : []
    }
  };

  const r = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: "Bearer " + env.WHATSAPP_TOKEN,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(body)
  });

  const data = await r.json().catch(() => null);
  if (!r.ok) {
    const msg = (data && data.error && data.error.message) || ("WhatsApp API error " + r.status);
    throw new Error(msg);
  }
  return data;
}
