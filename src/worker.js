const ADMIN_PREFIX = "/admin";
const SUPABASE_URL = "https://yckteijitcqjtedoyoyv.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlja3RlaWppdGNxanRlZG95b3l2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc5MjA3MTksImV4cCI6MjEwMzQ5NjcxOX0.mAY5A6ROvtxN4kkD8g1s_tsDlSjGfy4TCNkgbYHeRvo";

const esc = s => String(s ?? "").replace(/[&<>"']/g,
  c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

async function fetchListing(ref) {
  const r = await fetch(
    SUPABASE_URL + "/rest/v1/v_listings_public?ref=eq." + encodeURIComponent(ref) +
      "&select=title,description,city,area,price,images",
    { headers: { apikey: SUPABASE_ANON_KEY, Authorization: "Bearer " + SUPABASE_ANON_KEY } }
  );
  if (!r.ok) return null;
  const rows = await r.json();
  return rows[0] || null;
}

// بيبني كارت مشاركة (WhatsApp/فيسبوك) لإعلان محدّد — بيبدّل meta tags بس، الصفحة نفسها SPA واحدة.
function withListingMeta(res, listing, canonicalUrl) {
  const title = listing.title + " — سكن";
  const price = listing.price ? Number(listing.price).toLocaleString("ar-EG") + " ₪/شهر — " : "";
  const desc = price + listing.city + " · " + listing.area + ". غرفة موثّقة على سكن.";
  const img = Array.isArray(listing.images) && listing.images[0] ? listing.images[0] : null;

  return new HTMLRewriter()
    .on("title", { element(el) { el.setInnerContent(title); } })
    .on('meta[name="description"]', { element(el) { el.setAttribute("content", desc); } })
    .on('meta[property="og:title"]', { element(el) { el.setAttribute("content", title); } })
    .on('meta[property="og:description"]', { element(el) { el.setAttribute("content", desc); } })
    .on("head", {
      element(el) {
        el.append(`<meta property="og:url" content="${esc(canonicalUrl)}">`, { html: true });
        el.append(`<meta property="og:type" content="website">`, { html: true });
        if (img) {
          el.append(`<meta property="og:image" content="${esc(img)}">`, { html: true });
          el.append(`<meta name="twitter:card" content="summary_large_image">`, { html: true });
        } else {
          el.append(`<meta name="twitter:card" content="summary">`, { html: true });
        }
      }
    })
    .transform(res);
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const p = url.pathname;

    if (p === ADMIN_PREFIX || p.startsWith(ADMIN_PREFIX + "/")) {
      const res = await env.ASSETS.fetch(request);
      const out = new Response(res.body, res);
      out.headers.set("X-Robots-Tag", "noindex, nofollow");
      return out;
    }

    const ref = url.searchParams.get("l");
    if (p === "/" && ref) {
      const res = await env.ASSETS.fetch(request);
      const listing = await fetchListing(ref).catch(() => null);
      if (listing) return withListingMeta(res, listing, url.origin + "/?l=" + encodeURIComponent(ref));
      return res;
    }

    return env.ASSETS.fetch(request);
  }
};
