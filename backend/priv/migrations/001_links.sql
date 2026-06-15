CREATE TABLE links (
  id          INTEGER PRIMARY KEY,
  slug        TEXT NOT NULL UNIQUE,
  target_url  TEXT NOT NULL,
  secret      TEXT NOT NULL,
  click_count INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL
);
