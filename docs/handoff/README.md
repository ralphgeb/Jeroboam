# Handoff notes between Claude sessions

Ralph works on Jero with more than one Claude (different accounts and chats, for example one on the app and maps and one on
the price list). They don't see each other's conversations, so they keep each other informed here.

## The rule (every Claude working on this repository)

1. **At the start of a session, read every file in this folder.** It tells you what the other sessions did, what they
   decided with Ralph, what is half-finished and which files they are working on, so you don't redo, undo or clash with it.
2. **Keep your own file here and update it whenever you finish something** (and always before the session ends): what you
   changed and why, Ralph's decisions and preferences, what is on which branch, what is on TestFlight, what is open.
   One file per Claude: `claude-<short-topic>.md` (e.g. `claude-maps-and-app.md`, `claude-prices.md`). Add a new section at the
   top with the date; don't rewrite history.
3. **Never edit another Claude's file.** If you need to tell it something, write it in your own file under "For the other
   sessions", and it will see it on its next read.
4. Commit and push your file with your work (it is small and plain text), on the branch you work on. Once merged to `main`,
   every session sees it. If you work on a branch, say which one at the top of your file.
5. Write plainly: Ralph reads these too.

## Files

| File | Who | Topic |
|---|---|---|
| [claude-maps-and-app.md](claude-maps-and-app.md) | the app / maps / course session | maps, app features, journal, sync, course content, download size, scanning speed |
| [claude-prices.md](claude-prices.md) | the price-list session | wine price list, shop harvest, critics' scores, label fingerprints of shop photos |
