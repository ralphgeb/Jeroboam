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
