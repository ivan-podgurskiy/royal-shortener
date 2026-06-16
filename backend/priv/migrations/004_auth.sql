CREATE TABLE users (
  id            INTEGER PRIMARY KEY,
  email         TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at    INTEGER NOT NULL
);

CREATE TABLE sessions (
  token       TEXT PRIMARY KEY,
  user_id     INTEGER NOT NULL REFERENCES users(id),
  expires_at  INTEGER NOT NULL
);

ALTER TABLE links ADD COLUMN owner_user_id INTEGER NULL REFERENCES users(id);

CREATE INDEX links_owner_user_id ON links(owner_user_id);
