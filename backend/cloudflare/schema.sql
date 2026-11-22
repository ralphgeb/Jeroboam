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
