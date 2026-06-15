CREATE TABLE clicks (
  id           INTEGER PRIMARY KEY,
  link_id      INTEGER NOT NULL REFERENCES links(id),
  at           INTEGER NOT NULL,
  referrer     TEXT NULL,
  country      TEXT NULL,
  device_class TEXT NOT NULL
);

CREATE INDEX clicks_link_id_at ON clicks(link_id, at);
