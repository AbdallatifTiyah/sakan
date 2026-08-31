const ADMIN_PREFIX = "/admin";

export default {
  async fetch(request, env) {
    const p = new URL(request.url).pathname;

    if (p === ADMIN_PREFIX || p.startsWith(ADMIN_PREFIX + "/")) {
      const res = await env.ASSETS.fetch(request);
      const out = new Response(res.body, res);
      out.headers.set("X-Robots-Tag", "noindex, nofollow");
      return out;
    }

    return env.ASSETS.fetch(request);
  }
};
