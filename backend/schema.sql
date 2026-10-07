-- ============================================================
-- Skema MySQL untuk API Inventaris (backend/api.php)
--
-- CARA PAKAI (shared hosting cPanel + phpMyAdmin):
--   1) Buat database + user di menu "MySQL Databases"
--   2) Buka phpMyAdmin -> pilih database -> tab "Import"
--   3) Pilih file ini -> "Go"
--   4) Salin config.example.php menjadi config.php lalu isi
--      DSN / user / password database tersebut.
--
-- Aman dijalankan ulang (IF NOT EXISTS + INSERT IGNORE).
-- Kolom & nama tabel sengaja identik dengan skema lokal SQLite
-- (lib/database/local_database.dart) supaya mode lokal <-> cloud aman.
-- ============================================================

SET NAMES utf8mb4;

-- Perangkat inventaris
CREATE TABLE IF NOT EXISTS devices (
  id                 BIGINT       NOT NULL AUTO_INCREMENT,
  kode_inventaris    TEXT         NULL,
  tanggal_evaluasi   TEXT         NULL,
  plan               TEXT         NULL,
  bagian             TEXT         NULL,
  device_name        TEXT         NULL,
  category           TEXT         NULL,
  prosesor           TEXT         NULL,
  motherboard        TEXT         NULL,
  ram                TEXT         NULL,
  storage            TEXT         NULL,
  os_windows         TEXT         NULL,
  goal               TEXT         NULL,
  perlu_upgrade_ganti TEXT        NULL,
  perlu_upgrade_repair TEXT       NULL,
  status_upgrade     TEXT         NULL,
  keterangan         TEXT         NULL,
  status_stiker      TEXT         NULL,
  drive_link         TEXT         NULL,
  created_at         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  -- index prefix: kode_inventaris bertipe TEXT (tidak bisa di-UNIQUE utuh),
  -- dipakai saat upsert impor Excel agar tidak full scan per baris.
  KEY idx_devices_kode (kode_inventaris(191))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- Master Bagian (CRUD penuh). UNIQUE case-insensitive (general_ci),
-- selaras dengan pemeriksaan duplikat berbasis lower-case di aplikasi.
CREATE TABLE IF NOT EXISTS bagian (
  id         BIGINT      NOT NULL AUTO_INCREMENT,
  name       VARCHAR(191) NOT NULL,
  created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_bagian_name (name)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- Master PLAN (Plan 1, Plan 2, dst.)
CREATE TABLE IF NOT EXISTS plan (
  id         BIGINT      NOT NULL AUTO_INCREMENT,
  name       VARCHAR(191) NOT NULL,
  created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_plan_name (name)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- PIN aplikasi (hash SHA-256) — baris tunggal id=1, ikut tersinkron.
CREATE TABLE IF NOT EXISTS app_settings (
  id         BIGINT  NOT NULL,
  pin_hash   TEXT    NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- Nomor revisi: dinaikkan tiap kali API menerima tulisan (insert/update/
-- delete/upsert). Klien polling membaca angka ini tiap 5 detik dan hanya
-- mengunduh data ulang bila berubah — murah dan presisi (tanpa jendela
-- per-second seperti MAX(updated_at)).
CREATE TABLE IF NOT EXISTS app_state (
  id  BIGINT NOT NULL,
  rev BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

INSERT IGNORE INTO app_settings (id, pin_hash) VALUES (1, '');
INSERT IGNORE INTO app_state (id, rev) VALUES (1, 0);
