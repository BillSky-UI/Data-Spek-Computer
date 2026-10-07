-- ============================================================
-- Skema SQLite untuk backend/api.php — HANYA untuk pratinjau lokal.
--
-- Produksi memakai MySQL (lihat schema.sql). Mode SQLite dipakai untuk
-- mencoba API di komputer sendiri ketika belum punya hosting/MySQL:
--   php -S localhost:8080 -t backend
--   (isi config.php dengan DSN sqlite:__DIR__/inventaris.db lalu import
--    file ini sekali lewat api.php?op=migrate — atau sqlite3 CLI)
--
-- Nama tabel/kolom identik dengan schema.sql.
-- ============================================================

CREATE TABLE IF NOT EXISTS devices (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  kode_inventaris     TEXT COLLATE NOCASE,
  tanggal_evaluasi    TEXT,
  plan                TEXT,
  bagian              TEXT,
  device_name         TEXT,
  category            TEXT,
  prosesor            TEXT,
  motherboard         TEXT,
  ram                 TEXT,
  storage             TEXT,
  os_windows          TEXT,
  goal                TEXT,
  perlu_upgrade_ganti TEXT,
  perlu_upgrade_repair TEXT,
  status_upgrade      TEXT,
  keterangan          TEXT,
  status_stiker       TEXT,
  drive_link          TEXT,
  created_at          TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  updated_at          TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
);

-- COLLATE NOCASE: mereplikasi UNIQUE case-insensitive utf8mb4_general_ci di MySQL.
CREATE TABLE IF NOT EXISTS bagian (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT NOT NULL COLLATE NOCASE UNIQUE,
  created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
);

CREATE TABLE IF NOT EXISTS plan (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT NOT NULL COLLATE NOCASE UNIQUE,
  created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
);

CREATE TABLE IF NOT EXISTS app_settings (
  id         INTEGER PRIMARY KEY,
  pin_hash   TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
);

CREATE TABLE IF NOT EXISTS app_state (
  id  INTEGER PRIMARY KEY,
  rev INTEGER NOT NULL DEFAULT 0
);

INSERT OR IGNORE INTO app_settings (id, pin_hash) VALUES (1, '');
INSERT OR IGNORE INTO app_state (id, rev) VALUES (1, 0);

CREATE INDEX IF NOT EXISTS idx_devices_kode ON devices (kode_inventaris);

-- tiap tulisan memperbarui updated_at (tanpa trigger sampah: pakai WHEN
-- supaya UPDATE dari trigger tidak memicu trigger-nya sendiri lagi)
CREATE TRIGGER IF NOT EXISTS trg_devices_upd AFTER UPDATE ON devices
WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE devices SET updated_at = datetime('now', 'localtime') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_bagian_upd AFTER UPDATE ON bagian
WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE bagian SET updated_at = datetime('now', 'localtime') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_plan_upd AFTER UPDATE ON plan
WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE plan SET updated_at = datetime('now', 'localtime') WHERE id = NEW.id;
END;
