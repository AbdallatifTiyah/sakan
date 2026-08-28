const ADMIN_PREFIX = "/admin";

export default {
  async fetch(request, env) {
    const p = new URL(request.url).pathname;

    if (p === ADMIN_PREFIX || p.startsWith(ADMIN_PREFIX + "/")) {
      if (!authorized(request, env)) {
        return new Response("Unauthorized", {
          status: 401,
          headers: {
            "WWW-Authenticate": 'Basic realm="Sakan Admin", charset="UTF-8"',
            "Content-Type": "text/plain; charset=utf-8",
            "Cache-Control": "no-store"
          }
        });
      }
      const res = await env.ASSETS.fetch(request);
      const out = new Response(res.body, res);
      out.headers.set("Cache-Control", "no-store");
      out.headers.set("X-Robots-Tag", "noindex, nofollow");
      return out;
    }

    return env.ASSETS.fetch(request);
  }
};

function authorized(request, env) {
  const header = request.headers.get("Authorization") || "";
  if (!header.startsWith("Basic ")) return false;
  let decoded;
  try {
    decoded = atob(header.slice(6).trim());
  } catch {
    return false;
  }
  const i = decoded.indexOf(":");
  if (i < 0) return false;
  const okUser = eq(decoded.slice(0, i), env.ADMIN_USER);
  const okPass = eq(decoded.slice(i + 1), env.ADMIN_PASS);
  return okUser && okPass;
}

function eq(a, b) {
  if (typeof a !== "string" || typeof b !== "string") return false;
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
