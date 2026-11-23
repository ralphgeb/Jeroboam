// Jero's shared wine-price list: one small Cloudflare Worker with a D1 database.
// The app asks it for a price before searching anywhere else, and sends back every price it had to find itself,
// so the list grows with every lookup anyone makes. Only the wine's name, producer, vintage and price are stored:
// no photos, no accounts, nothing about the person.
//
//   GET  /price?key=<key>    -> 200 {"usd":..,"low":..,"high":..,"source":..,"shops":..} or 404
//   POST /price              -> {"key","name","producer","vintage","usd","low","high","source"}  (adds or improves)
//
// Both need the header  x-jero-key: <API_KEY secret>.

const RANK = { "Wine-Searcher": 3, "CellarTracker": 3, "Shop": 2, "Estimate": 1 };
const rankOf = (s) => (s.startsWith("Average of") || s === "Shop price" ? RANK.Shop : (RANK[s] ?? 1));
const json = (obj, status = 200) => new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json" } });
const clean = (v, n = 120) => String(v ?? "").slice(0, n);

export default {
  async fetch(req, env) {
    if (req.headers.get("x-jero-key") !== env.API_KEY) return json({ error: "no" }, 401);
    const url = new URL(req.url);

    // ---- wines: every scan adds to a counter and keeps what Claude found out (so the next person's scan costs nothing)
    //   GET  /wine?sig=<label signature>  or  ?key=<wine key>   -> 200 {"json": "<identity>"} or 404
    //   POST /wine  {"key","sig","json","name","producer","vintage","region","country","style"}  -> adds the wine or counts one more scan
    if (url.pathname === "/wine") {
      if (req.method === "GET") {
        const sig = clean(url.searchParams.get("sig"), 300), key = clean(url.searchParams.get("key"), 300);
        if (!sig && !key) return json({ error: "key" }, 400);
        const row = sig
          ? await env.DB.prepare("SELECT json FROM wines WHERE sig = ? ORDER BY scans DESC LIMIT 1").bind(sig).first()
          : await env.DB.prepare("SELECT json FROM wines WHERE key = ?").bind(key).first();
        return row && row.json ? json({ json: row.json }) : json({ error: "none" }, 404);
      }
      if (req.method === "POST") {
        let b;
        try { b = await req.json(); } catch { return json({ error: "json" }, 400); }
        const key = clean(b.key, 300);
        if (!key || !clean(b.name)) return json({ error: "bad" }, 400);
        const now = Math.floor(Date.now() / 1000);
        await env.DB.prepare(
          `INSERT INTO wines (key, sig, name, producer, vintage, region, country, style, json, scans, first_seen, last_seen)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
           ON CONFLICT(key) DO UPDATE SET scans = scans + 1, last_seen = excluded.last_seen,
             sig = COALESCE(excluded.sig, sig), json = COALESCE(excluded.json, json)`
        ).bind(key, b.sig ? clean(b.sig, 300) : null, clean(b.name), clean(b.producer), clean(b.vintage, 12), clean(b.region), clean(b.country, 60),
               clean(b.style, 20), b.json ? String(b.json).slice(0, 8000) : null, now, now).run();
        return json({ ok: true });
      }
      return json({ error: "method" }, 405);
    }

    if (url.pathname !== "/price") return json({ error: "not found" }, 404);

    if (req.method === "GET") {
      const key = clean(url.searchParams.get("key"), 300);
      if (!key) return json({ error: "key" }, 400);
      const row = await env.DB.prepare("SELECT usd, low, high, source, rank, hits FROM prices WHERE key = ?").bind(key).first();
      if (!row) return json({ error: "none" }, 404);
      await env.DB.prepare("UPDATE prices SET hits = hits + 1 WHERE key = ?").bind(key).run();
      return json(row);
    }

    if (req.method === "POST") {
      let b;
      try { b = await req.json(); } catch { return json({ error: "json" }, 400); }
      const key = clean(b.key, 300), usd = Number(b.usd);
      if (!key || !(usd > 0 && usd < 200000)) return json({ error: "bad" }, 400);
      const source = clean(b.source, 40) || "Estimate";
      const rank = rankOf(source);
      const low = Number(b.low) > 0 ? Number(b.low) : usd * 0.85, high = Number(b.high) > 0 ? Number(b.high) : usd * 1.2;
      const existing = await env.DB.prepare("SELECT rank FROM prices WHERE key = ?").bind(key).first();
      // a better source replaces a worse one; an estimate never replaces a real price
      if (existing && existing.rank > rank) return json({ ok: true, kept: true });
      await env.DB.prepare(
        `INSERT INTO prices (key, name, producer, vintage, usd, low, high, source, rank, hits, updated)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)
         ON CONFLICT(key) DO UPDATE SET usd = excluded.usd, low = excluded.low, high = excluded.high,
           source = excluded.source, rank = excluded.rank, updated = excluded.updated`
      ).bind(key, clean(b.name), clean(b.producer), clean(b.vintage, 12), usd, low, high, source, rank, Math.floor(Date.now() / 1000)).run();
      return json({ ok: true });
    }
    return json({ error: "method" }, 405);
  },
};
