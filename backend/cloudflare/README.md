# Jero's shared price list (Cloudflare Worker + D1)

Set up once, from the Cloudflare website (no computer needed beyond a browser):

1. **Database.** dash.cloudflare.com > Storage & databases > D1 SQL database > Create. Name it `jero-prices`.
   Open it, go to **Console**, paste the contents of `schema.sql` and run it.
2. **Worker.** Workers & Pages > Create > Create Worker. Name it `jero-prices`, Deploy, then **Edit code**:
   replace everything with the contents of `worker.js` and Deploy.
3. **Connect them.** Open the worker > Settings > Bindings > Add > **D1 database**. Variable name `DB`, pick `jero-prices`.
4. **Secret.** Same page: Variables and Secrets > Add > type **Secret**, name `API_KEY`, value any long random string
   (a password manager makes one). Deploy.
5. **Copy the worker's address** (it looks like `https://jero-prices.yourname.workers.dev`).
6. In the GitHub repo: Settings > Secrets and variables > Actions > New repository secret:
   - `PRICE_DB_URL` = that address (no slash at the end)
   - `PRICE_DB_KEY` = the same random string you used for `API_KEY`

The next TestFlight build then talks to it. Until both secrets exist the app simply skips the shared list.
Only a wine's name, producer, vintage and price are stored: no photos, accounts or anything about the person.
Costs: the free Cloudflare plan covers about 100,000 lookups a day.

## Claude proxy (the Anthropic key lives here, not in the app)

The same worker forwards the app's calls to Claude (`POST /claude`), adding the Anthropic key, allowing only Jero-shaped
requests (always Claude Haiku, short answers, at most two web searches) and keeping a daily spending cap per phone
(`DEVICE_DAILY_USD`, default 0.15) and for everyone together (`GLOBAL_DAILY_USD`, default 5). Its spending table creates itself.

1. Workers & Pages > `jero-prices` > **Edit code**: replace everything with the new `worker.js`, **Deploy**.
2. Settings > **Variables and Secrets** > Add > type **Secret**, name `ANTHROPIC_API_KEY`, value: the Anthropic key. Deploy.
   (Optional: type **Text**, `GLOBAL_DAILY_USD` = the most Jero may spend on Claude per day, e.g. `5`.)
3. GitHub > Actions > **Check the Claude proxy** > Run workflow: it must end with "The Claude proxy works".
4. GitHub > Settings > Secrets and variables > Actions > **Variables** > New: `CLAUDE_PROXY_READY` = `true`.
   From the next TestFlight build the app talks to Claude only through the worker and carries no Anthropic key.
5. Then create a new key in the Anthropic console, put it in the worker's `ANTHROPIC_API_KEY`, and delete the old one
   (the old one shipped inside earlier TestFlight builds).

## Gemini test route (optional)

`POST /gemini {"prompt"}` asks Gemini with Google Search (secret `GEMINI_API_KEY`; model `GEMINI_MODEL`, default
`gemini-2.5-flash`; at most `GEMINI_DAILY_CALLS` a day, default 300). Used only by the comparison
(`tools/compare_wine_check.py`, Actions > **Compare wine checks**), not by the app yet.
1. aistudio.google.com > **Get API key** > Create API key. 2. Paste the new `worker.js`, Deploy.
3. Worker > Settings > Variables and Secrets > Add > Secret `GEMINI_API_KEY`. Deploy. 4. Run the comparison.
