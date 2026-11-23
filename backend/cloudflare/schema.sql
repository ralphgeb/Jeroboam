CREATE TABLE IF NOT EXISTS prices (
  key      TEXT PRIMARY KEY,
  name     TEXT,
  producer TEXT,
  vintage  TEXT,
  usd      REAL NOT NULL,
  low      REAL,
  high     REAL,
  source   TEXT,
  rank     INTEGER DEFAULT 1,
  hits     INTEGER DEFAULT 1,
  updated  INTEGER
);

-- Every wine anyone scans, with what Claude found out about it (no user, device or photo is ever stored).
CREATE TABLE IF NOT EXISTS wines (
  key        TEXT PRIMARY KEY,
  sig        TEXT,
  name       TEXT,
  producer   TEXT,
  vintage    TEXT,
  region     TEXT,
  country    TEXT,
  style      TEXT,
  json       TEXT,
  scans      INTEGER DEFAULT 1,
  first_seen INTEGER,
  last_seen  INTEGER
);
CREATE INDEX IF NOT EXISTS wines_sig ON wines (sig);
CREATE INDEX IF NOT EXISTS wines_scans ON wines (scans DESC);
