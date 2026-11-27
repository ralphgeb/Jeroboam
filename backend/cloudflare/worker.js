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

// The wines table gets readable grapes, their percentages and whether they were checked online (added Nov 2026). Done once per
// worker start: missing columns are added and older rows filled from the JSON they already hold.
let winesReady = false;
async function winesColumns(env) {
  if (winesReady) return;
  for (const col of ["grapes TEXT", "grape_percent TEXT", "checked INTEGER"]) {
    try { await env.DB.prepare(`ALTER TABLE wines ADD COLUMN ${col}`).run(); } catch (e) { /* already there */ }
  }
  await env.DB.prepare(`UPDATE wines SET
      grapes = (SELECT group_concat(value, ', ') FROM json_each(wines.json, '$.grapes')),
      grape_percent = (SELECT group_concat(value, ', ') FROM json_each(wines.json, '$.grape_percent')),
      checked = CASE WHEN json_extract(wines.json, '$.checked') = 1 OR json_extract(wines.json, '$.from_database') = 1 THEN 1 ELSE 0 END
    WHERE grapes IS NULL AND json IS NOT NULL AND json_valid(json)`).run();
  winesReady = true;
}

/// What a wine's JSON says about its grapes, for the readable columns.
function grapeColumns(text) {
  try {
    const w = JSON.parse(text || "{}");
    const g = Array.isArray(w.grapes) ? w.grapes.map(String).filter(Boolean) : [];
    const p = Array.isArray(w.grape_percent) ? w.grape_percent.map(Number) : [];
    return { grapes: g.length ? g.join(", ").slice(0, 300) : null, percent: p.length ? p.join(", ").slice(0, 100) : null,
             checked: w.checked === true || w.from_database === true ? 1 : 0 };
  } catch { return { grapes: null, percent: null, checked: 0 }; }
}

// Starts GitHub's fingerprint check (workflow_dispatch of print-check.yml on main) at most once a minute.
async function startPrintCheck(env) {
  try {
    const now = Math.floor(Date.now() / 1000);
    await env.DB.prepare("CREATE TABLE IF NOT EXISTS print_check_runs (id INTEGER PRIMARY KEY, at INTEGER)").run();
    const last = await env.DB.prepare("SELECT at FROM print_check_runs WHERE id = 1").first();
    if (last && now - last.at < 60) return;
    await env.DB.prepare("INSERT OR REPLACE INTO print_check_runs (id, at) VALUES (1, ?)").bind(now).run();
    const repo = env.GITHUB_REPO || "ralphgeb/Jeroboam";
    await fetch(`https://api.github.com/repos/${repo}/actions/workflows/print-check.yml/dispatches`, {
      method: "POST",
      headers: { "authorization": `Bearer ${env.GITHUB_TOKEN}`, "accept": "application/vnd.github+json",
                 "x-github-api-version": "2022-11-28", "user-agent": "jero-worker", "content-type": "application/json" },
      body: JSON.stringify({ ref: "main" }),
    });
  } catch (e) { /* the hourly run picks it up */ }
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
  // b.lite: the cheaper, quicker Flash-Lite. b.thinking: Google's thinkingConfig, only these keys (thinking off = budget 0 or level
  // "minimal", depending on the model); Gemini thinks by default and that thinking was most of its 13 s per wine.
  const model = (b.lite ? await geminiModel(env, true) : null) || env.GEMINI_MODEL || (await geminiModel(env));
  if (!model) return claudeError("No Gemini Flash model found for this key.", 503);
  const gen = { maxOutputTokens: Number(env.GEMINI_MAX_TOKENS || 8192) };   // Gemini's thinking counts against this limit too
  const t = b.thinking || {};
  if (Number.isInteger(t.thinkingBudget) || typeof t.thinkingLevel === "string")
    gen.thinkingConfig = Number.isInteger(t.thinkingBudget) ? { thinkingBudget: Math.max(0, Math.min(t.thinkingBudget, 4096)) }
                                                           : { thinkingLevel: String(t.thinkingLevel).slice(0, 12) };
  const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
    method: "POST",
    headers: { "content-type": "application/json", "x-goog-api-key": env.GEMINI_API_KEY },
    body: JSON.stringify({ contents: [{ role: "user", parts: [{ text: prompt }] }], tools: [{ google_search: {} }],
                           generationConfig: gen }),
  });
  const text = await res.text();
  await env.DB.prepare(`INSERT INTO claude_usage (day, device, usd, calls) VALUES (?, 'gemini', 0, 1)
                        ON CONFLICT(day, device) DO UPDATE SET calls = calls + 1`).bind(d).run();
  return new Response(text, { status: res.status, headers: { "content-type": "application/json", "x-gemini-model": model } });
}

// Google renames its models often: without GEMINI_MODEL, ask Google which models this key can use and take the current Flash
// ("gemini-flash-latest" when offered, else the newest plain Flash that can generate content).
async function geminiModel(env, lite = false) {
  const r = await fetch("https://generativelanguage.googleapis.com/v1beta/models?pageSize=200", { headers: { "x-goog-api-key": env.GEMINI_API_KEY } });
  if (!r.ok) return null;
  const list = ((await r.json()).models || [])
    .filter((m) => (m.supportedGenerationMethods || []).includes("generateContent"))
    .map((m) => String(m.name || "").replace(/^models\//, ""));
  if (lite) {
    if (list.includes("gemini-flash-lite-latest")) return "gemini-flash-lite-latest";
    const l = list.filter((n) => /^gemini-[\d.]+-flash-lite(-preview)?(-\d+)?$/.test(n));
    l.sort((a, b) => parseFloat(b.slice(7)) - parseFloat(a.slice(7)) || a.length - b.length);
    return l[0] || null;
  }
  if (list.includes("gemini-flash-latest")) return "gemini-flash-latest";
  const flash = list.filter((n) => /^gemini-[\d.]+-flash(-\d+)?$/.test(n) || /^gemini-[\d.]+-flash-preview/.test(n));
  const ver = (n) => parseFloat((n.match(/gemini-([\d.]+)/) || [0, 0])[1]);
  flash.sort((a, b) => ver(b) - ver(a) || a.length - b.length);
  return flash[0] || null;
}

export default {
  async fetch(req, env, ctx) {
    if (req.headers.get("x-jero-key") !== env.API_KEY) return json({ error: "no" }, 401);
    const url = new URL(req.url);

    if (url.pathname === "/claude/ping") return json({ ok: true, key: !!env.ANTHROPIC_API_KEY });
    if (url.pathname === "/gemini/ping") {
      const model = env.GEMINI_API_KEY ? (env.GEMINI_MODEL || (await geminiModel(env))) : null;
      const lite = env.GEMINI_API_KEY ? await geminiModel(env, true) : null;
      return json({ ok: true, key: !!env.GEMINI_API_KEY, model, lite });
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
    // ---- label fingerprints (the app's LabelPrint: Apple Vision feature prints, 32-bit floats, base64), at most 5 per wine.
    //   POST /print {"key","rev","dims","vec"}   GET /prints/export?limit=  (for tests run on GitHub)
    if (url.pathname === "/print" && req.method === "POST") {
      let b;
      try { b = await req.json(); } catch { return json({ error: "json" }, 400); }
      const key = clean(b.key, 300), vec = String(b.vec || "");
      const rev = Number(b.rev) | 0, dims = Number(b.dims) | 0;
      if (!key || !vec || vec.length > 20000 || dims <= 0 || dims > 8192) return json({ error: "bad" }, 400);
      await env.DB.prepare(`CREATE TABLE IF NOT EXISTS label_prints (id INTEGER PRIMARY KEY AUTOINCREMENT, key TEXT NOT NULL,
                            rev INTEGER, dims INTEGER, vec TEXT NOT NULL, created INTEGER)`).run();
      await env.DB.prepare("CREATE INDEX IF NOT EXISTS label_prints_key ON label_prints (key)").run();
      await env.DB.prepare("INSERT INTO label_prints (key, rev, dims, vec, created) VALUES (?, ?, ?, ?, ?)")
        .bind(key, rev, dims, vec, Math.floor(Date.now() / 1000)).run();
      // keep the 5 newest of each wine
      await env.DB.prepare(`DELETE FROM label_prints WHERE key = ? AND id NOT IN
                            (SELECT id FROM label_prints WHERE key = ? ORDER BY id DESC LIMIT 5)`).bind(key, key).run();
      // TestFlight fingerprint check: ask GitHub to compare this print now (print-check.yml), instead of waiting for its timer.
      // Needs the secret GITHUB_TOKEN (fine-grained: this repo, Actions read/write). GitHub queues at most one waiting run.
      if (env.GITHUB_TOKEN) ctx.waitUntil(startPrintCheck(env));
      return json({ ok: true });
    }
    if (url.pathname === "/prints/export") {
      const limit = Math.max(1, Math.min(20000, Number(url.searchParams.get("limit")) || 5000));
      try {
        const since = Number(url.searchParams.get("since")) || 0;
        const { results } = await env.DB.prepare("SELECT id, key, rev, dims, vec, created FROM label_prints WHERE created >= ? ORDER BY id DESC LIMIT ?").bind(since, limit).all();
        return json({ rows: results || [] });
      } catch { return json({ rows: [] }); }
    }

    // ---- fingerprint check (TestFlight only, while testing): GitHub's print-check.yml compares each phone print with the shop
    //   photos' prints and posts the 3 nearest; the app lists them (Settings > TestFlight > Fingerprint check).
    //   POST /prints/checks {"checks":[{"id","key","created","results"}]}   GET /prints/checks?limit=40
    if (url.pathname === "/prints/checks") {
      await env.DB.prepare(`CREATE TABLE IF NOT EXISTS print_checks (id INTEGER PRIMARY KEY, key TEXT, created INTEGER,
                            results TEXT, checked INTEGER)`).run();
      if (req.method === "POST") {
        let b;
        try { b = await req.json(); } catch { return json({ error: "json" }, 400); }
        const list = Array.isArray(b.checks) ? b.checks.slice(0, 500) : [];
        const now = Math.floor(Date.now() / 1000);
        for (const c of list) {
          await env.DB.prepare("INSERT OR REPLACE INTO print_checks (id, key, created, results, checked) VALUES (?, ?, ?, ?, ?)")
            .bind(Number(c.id) | 0, clean(c.key, 300), Number(c.created) | 0, JSON.stringify(c.results || {}).slice(0, 8000), now).run();
        }
        return json({ ok: true, saved: list.length });
      }
      const limit = Math.max(1, Math.min(200, Number(url.searchParams.get("limit")) || 40));
      const { results } = await env.DB.prepare("SELECT id, key, created, results, checked FROM print_checks ORDER BY created DESC LIMIT ?").bind(limit).all();
      return json({ rows: results || [] });
    }

    // ---- for tests run on GitHub (tools/label_match_test.py): the scanned wines that have a label signature, newest first
    //   GET /wines/export?limit=1000 -> {"rows": [{"sig","name","producer","vintage","json"}]}
    if (url.pathname === "/wines/export") {
      const limit = Math.max(1, Math.min(5000, Number(url.searchParams.get("limit")) || 1000));
      const { results } = await env.DB.prepare(
        "SELECT sig, name, producer, vintage, json FROM wines WHERE sig IS NOT NULL AND sig != '' ORDER BY last_seen DESC LIMIT ?"
      ).bind(limit).all();
      return json({ rows: results || [] });
    }

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
        await winesColumns(env);
        const now = Math.floor(Date.now() / 1000);
        const g = grapeColumns(b.json);
        // a scan counts once: the app also sends the wine again after checking it, with "count": false (older builds send no flag)
        const add = b.count === false ? 0 : 1;
        // a checked wine's grapes replace an unchecked guess, never the other way round; region and country fill in when known
        await env.DB.prepare(
          `INSERT INTO wines (key, sig, name, producer, vintage, region, country, style, json, grapes, grape_percent, checked, scans, first_seen, last_seen)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT(key) DO UPDATE SET scans = scans + ?, last_seen = excluded.last_seen,
             sig = COALESCE(excluded.sig, sig),
             region = COALESCE(NULLIF(excluded.region, ''), region), country = COALESCE(NULLIF(excluded.country, ''), country),
             style = COALESCE(NULLIF(excluded.style, ''), style),
             json = CASE WHEN excluded.checked >= COALESCE(checked, 0) THEN COALESCE(excluded.json, json) ELSE json END,
             grapes = CASE WHEN excluded.checked >= COALESCE(checked, 0) THEN COALESCE(excluded.grapes, grapes) ELSE grapes END,
             grape_percent = CASE WHEN excluded.checked >= COALESCE(checked, 0) THEN COALESCE(excluded.grape_percent, grape_percent) ELSE grape_percent END,
             checked = MAX(COALESCE(checked, 0), excluded.checked)`
        ).bind(key, b.sig ? clean(b.sig, 300) : null, clean(b.name), clean(b.producer), clean(b.vintage, 12), clean(b.region), clean(b.country, 60),
               clean(b.style, 20), b.json ? String(b.json).slice(0, 8000) : null, g.grapes, g.percent, g.checked, add, now, now, add).run();
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
