// Jero's shared wine-price list: one small Cloudflare Worker with a D1 database.
// The app asks it for a price before searching anywhere else, and sends back every price it had to find itself,
// so the list grows with every lookup anyone makes. Only the wine's name, producer, vintage and price are stored:
// no photos, no accounts, nothing about the person.
//
//   GET  /price?key=<key>    -> 200 {"usd":..,"low":..,"high":..,"source":..,"shops":..} or 404
//   POST /price              -> {"key","name","producer","vintage","usd","low","high","source"}  (adds or improves)
//   POST /claude             -> the app's calls to Claude (Anthropic Messages API), forwarded with the ANTHROPIC_API_KEY secret
//   GET  /claude/ping        -> {"ok": true, "key": true|false}: is the proxy set up? (costs nothing)
//   POST /gemini {"prompt"}  -> Gemini with Google Search grounding (secret GEMINI_API_KEY), for the wine-check comparison
//   GET  /gemini/ping        -> {"ok": true, "key": true|false}
//
// All of them need the header  x-jero-key: <API_KEY secret>.

const RANK = { "Wine-Searcher": 3, "CellarTracker": 3, "Shop": 2, "Estimate": 1 };
const rankOf = (s) => (s.startsWith("Average of") || s === "Shop price" ? RANK.Shop : (RANK[s] ?? 1));
const json = (obj, status = 200) => new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json" } });
const clean = (v, n = 120) => String(v ?? "").slice(0, n);

// ---- Claude proxy
// The Anthropic key lives only here (secret ANTHROPIC_API_KEY), never in the app. Only Jero-shaped requests go through:
// always Claude Haiku, short answers, at most two web searches (and only wine-price sites when the app names domains),
// and a daily spending cap per phone (DEVICE_DAILY_USD, default 0.15) and for everyone together (GLOBAL_DAILY_USD, default 5).
const MODEL = "claude-haiku-5-5";
const PRICE_SITES = ["wine-searcher.com", "cellartracker.com"];
const SEARCH_USD = 0.01;
const day = () => new Date().toISOString().slice(0, 10);
const claudeError = (message, status, type = "proxy") => json({ type: "error", error: { type, message } }, status);

function shape(b) {
  if (!b || !Array.isArray(b.messages) || b.messages.length === 0 || b.messages.length > 4) return null;
  if (b.messages.some((m) => !m || (m.role !== "user" && m.role !== "assistant"))) return null;
  // at least 800 tokens: Jero's answers are short JSON, but a cut-off answer is paid for and useless
  const out = { model: MODEL, max_tokens: Math.max(800, Math.min(Number(b.max_tokens) || 1000, 3000)), messages: b.messages };
  // thinking off unless the app asks for it: Haiku thinks by default and, after a web search, can spend the whole answer on it
  // (app builds up to 83 don't send this, so the worker sets it for them)
  out.thinking = { type: b.thinking && b.thinking.type === "adaptive" ? "adaptive" : "disabled" };
  if (typeof b.system === "string") out.system = b.system.slice(0, 8000);
  out.output_config = Object.assign({ effort: "low" }, b.output_config && typeof b.output_config === "object" ? b.output_config : {});
  // thinking can only be off at effort "high" or lower
  if (out.thinking.type === "disabled" && ["xhigh", "max"].includes(out.output_config.effort)) out.output_config.effort = "high";
  if (Array.isArray(b.tools)) {
    const t = b.tools.find((x) => x && x.type === "web_search_20250305");
    if (t) {
      const tool = { type: "web_search_20250305", name: "web_search", max_uses: Math.max(1, Math.min(Number(t.max_uses) || 1, 2)) };
      if (Array.isArray(t.allowed_domains)) tool.allowed_domains = t.allowed_domains.filter((d) => PRICE_SITES.includes(d));
      if (!tool.allowed_domains || tool.allowed_domains.length) out.tools = [tool];
    }
  }
  return out;
}

async function usage(env) {
  await env.DB.prepare(
    "CREATE TABLE IF NOT EXISTS claude_usage (day TEXT NOT NULL, device TEXT NOT NULL, usd REAL NOT NULL DEFAULT 0, calls INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (day, device))"
  ).run();
}

async function spent(env, d, device) {
  const row = await env.DB.prepare("SELECT usd FROM claude_usage WHERE day = ? AND device = ?").bind(d, device).first();
  return row ? row.usd : 0;
}

async function addSpend(env, d, device, usd) {
  const q = `INSERT INTO claude_usage (day, device, usd, calls) VALUES (?, ?, ?, 1)
             ON CONFLICT(day, device) DO UPDATE SET usd = usd + excluded.usd, calls = calls + 1`;
  await env.DB.batch([env.DB.prepare(q).bind(d, device, usd), env.DB.prepare(q).bind(d, "*", usd)]);
}

async function claude(req, env) {
  if (!env.ANTHROPIC_API_KEY) return claudeError("The Claude proxy is not set up yet.", 503);
  const device = String(req.headers.get("x-jero-device") || "").slice(0, 64);
  if (!/^[0-9A-Fa-f-]{20,64}$/.test(device)) return claudeError("Missing device.", 400);
  const raw = await req.text();
  if (raw.length > 3_000_000) return claudeError("Too large.", 413);
  let body;
  try { body = shape(JSON.parse(raw)); } catch { body = null; }
  if (!body) return claudeError("Not a Jero request.", 400);

  await usage(env);
  const d = day();
  const perDevice = Number(env.DEVICE_DAILY_USD || 0.15), all = Number(env.GLOBAL_DAILY_USD || 5);
  if ((await spent(env, d, device)) >= perDevice) return claudeError("Today's allowance is used up.", 429, "limit");
  if ((await spent(env, d, "*")) >= all) return claudeError("Jero's daily limit is reached. Try again tomorrow.", 429, "limit");

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "content-type": "application/json", "x-api-key": env.ANTHROPIC_API_KEY,
               "anthropic-version": req.headers.get("anthropic-version") || "2026-10-21" },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  try {
    const u = JSON.parse(text).usage || {};
    const searches = (u.server_tool_use && u.server_tool_use.web_search_requests) || 0;
    const usd = (u.input_tokens || 0) * 0.10 / 1e6 + (u.output_tokens || 0) * 0.50 / 1e6 + searches * SEARCH_USD;
    if (usd > 0) await addSpend(env, d, device, usd);
  } catch {}
  return new Response(text, { status: res.status, headers: { "content-type": "application/json" } });
}

// ---- Gemini with Google Search (test: tools/compare_wine_check.py). The key is the secret GEMINI_API_KEY; the model is
// GEMINI_MODEL (default: the current Flash, asked from Google). At most GEMINI_DAILY_CALLS calls a day (default 300), counted in claude_usage.
async function gemini(req, env) {
  if (!env.GEMINI_API_KEY) return claudeError("The Gemini key is not set up yet.", 503);
  let b;
  try { b = await req.json(); } catch { return claudeError("json", 400); }
  const prompt = String(b && b.prompt || "").slice(0, 6000);
  if (!prompt) return claudeError("Not a Jero request.", 400);
  await usage(env);
  const d = day();
  const row = await env.DB.prepare("SELECT calls FROM claude_usage WHERE day = ? AND device = 'gemini'").bind(d).first();
  if (row && row.calls >= Number(env.GEMINI_DAILY_CALLS || 300)) return claudeError("Gemini's daily test limit is reached.", 429, "limit");
  const model = env.GEMINI_MODEL || (await geminiModel(env));
  if (!model) return claudeError("No Gemini Flash model found for this key.", 503);
  const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
    method: "POST",
    headers: { "content-type": "application/json", "x-goog-api-key": env.GEMINI_API_KEY },
    body: JSON.stringify({ contents: [{ role: "user", parts: [{ text: prompt }] }], tools: [{ google_search: {} }],
                           generationConfig: { maxOutputTokens: 1024, temperature: 0.2 } }),
  });
  const text = await res.text();
  await env.DB.prepare(`INSERT INTO claude_usage (day, device, usd, calls) VALUES (?, 'gemini', 0, 1)
                        ON CONFLICT(day, device) DO UPDATE SET calls = calls + 1`).bind(d).run();
  return new Response(text, { status: res.status, headers: { "content-type": "application/json", "x-gemini-model": model } });
}

// Google renames its models often: without GEMINI_MODEL, ask Google which models this key can use and take the current Flash
// ("gemini-flash-latest" when offered, else the newest plain Flash that can generate content).
async function geminiModel(env) {
  const r = await fetch("https://generativelanguage.googleapis.com/v1beta/models?pageSize=200", { headers: { "x-goog-api-key": env.GEMINI_API_KEY } });
  if (!r.ok) return null;
  const list = ((await r.json()).models || [])
    .filter((m) => (m.supportedGenerationMethods || []).includes("generateContent"))
    .map((m) => String(m.name || "").replace(/^models\//, ""));
  if (list.includes("gemini-flash-latest")) return "gemini-flash-latest";
  const flash = list.filter((n) => /^gemini-[\d.]+-flash(-\d+)?$/.test(n) || /^gemini-[\d.]+-flash-preview/.test(n));
  const ver = (n) => parseFloat((n.match(/gemini-([\d.]+)/) || [0, 0])[1]);
  flash.sort((a, b) => ver(b) - ver(a) || a.length - b.length);
  return flash[0] || null;
}

export default {
  async fetch(req, env) {
    if (req.headers.get("x-jero-key") !== env.API_KEY) return json({ error: "no" }, 401);
    const url = new URL(req.url);

    if (url.pathname === "/claude/ping") return json({ ok: true, key: !!env.ANTHROPIC_API_KEY });
    if (url.pathname === "/gemini/ping") {
      const model = env.GEMINI_API_KEY ? (env.GEMINI_MODEL || (await geminiModel(env))) : null;
      return json({ ok: true, key: !!env.GEMINI_API_KEY, model });
    }
    if (url.pathname === "/gemini") {
      if (req.method !== "POST") return json({ error: "method" }, 405);
      return gemini(req, env);
    }
    if (url.pathname === "/claude") {
      if (req.method !== "POST") return json({ error: "method" }, 405);
      return claude(req, env);
    }

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
