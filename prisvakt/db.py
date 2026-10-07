import sqlite3
import time

SCHEMA = """
CREATE TABLE IF NOT EXISTS products (
  url TEXT PRIMARY KEY, site TEXT NOT NULL, name TEXT NOT NULL, currency TEXT,
  first_seen REAL NOT NULL, last_seen REAL NOT NULL);
CREATE TABLE IF NOT EXISTS prices (
  url TEXT NOT NULL, price REAL NOT NULL, ts REAL NOT NULL);
CREATE INDEX IF NOT EXISTS prices_url ON prices(url);
CREATE TABLE IF NOT EXISTS alerts (
  url TEXT NOT NULL, price REAL NOT NULL, ts REAL NOT NULL, PRIMARY KEY (url, price));
"""


class Store:
    def __init__(self, path: str):
        self.db = sqlite3.connect(path)
        self.db.executescript(SCHEMA)

    def record(self, site: str, p, now: float | None = None) -> float | None:
        """Lagrer observasjon. Returnerer høyeste tidligere kjente pris (eller None)."""
        now = now or time.time()
        prev_max = self.db.execute(
            "SELECT MAX(price) FROM prices WHERE url=?", (p.url,)).fetchone()[0]
        self.db.execute(
            "INSERT INTO products VALUES (?,?,?,?,?,?) ON CONFLICT(url) DO UPDATE "
            "SET name=excluded.name, last_seen=excluded.last_seen",
            (p.url, site, p.name, p.currency, now, now))
        last = self.db.execute(
            "SELECT price FROM prices WHERE url=? ORDER BY ts DESC LIMIT 1",
            (p.url,)).fetchone()
        if last is None or last[0] != p.price:  # bare lagre endringer
            self.db.execute("INSERT INTO prices VALUES (?,?,?)", (p.url, p.price, now))
        self.db.commit()
        return prev_max

    def already_alerted(self, url: str, price: float) -> bool:
        return self.db.execute("SELECT 1 FROM alerts WHERE url=? AND price=?",
                               (url, price)).fetchone() is not None

    def mark_alerted(self, url: str, price: float):
        self.db.execute("INSERT OR IGNORE INTO alerts VALUES (?,?,?)",
                        (url, price, time.time()))
        self.db.commit()
