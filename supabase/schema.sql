-- ============================================================
-- Schema Cloud Database (Supabase / PostgreSQL)
-- Proyek: Inventaris Spek Komputer — Sinkron Penuh
--
-- CARA PAKAI:
--   1) Buka https://supabase.com → buat project (New project)
--   2) Dashboard → SQL Editor → New query
--   3) Tempel seluruh isi file ini → RUN (boleh dijalankan ulang,
--      semua perintah idempotent / aman di-repeat)
-- ============================================================

-- ------------------------------------------------------------
-- TABEL
-- ------------------------------------------------------------

-- Perangkat inventaris
create table if not exists public.devices (
  id bigint generated always as identity primary key,
  kode_inventaris text not null,
  tanggal_evaluasi text,
  plan text,
  bagian text,
  device_name text,
  category text,
  prosesor text,
  motherboard text,
  ram text,
  storage text,
  os_windows text,
  goal text,
  perlu_upgrade_ganti text,
  perlu_upgrade_repair text,
  status_upgrade text,
  keterangan text,
  status_stiker text,
  drive_link text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Master Bagian (CRUD penuh)
create table if not exists public.bagian (
  id bigint generated always as identity primary key,
  name text not null unique
);

-- Master PLAN (Plan 1, Plan 2, dst)
create table if not exists public.plan (
  id bigint generated always as identity primary key,
  name text not null unique
);

-- PIN aplikasi (hash SHA-256) — baris tunggal id=1, tersinkronisasi real-time
create table if not exists public.app_settings (
  id bigint primary key default 1,
  pin_hash text not null default '',
  constraint app_settings_single_row check (id = 1)
);
insert into public.app_settings (id, pin_hash)
values (1, '') on conflict (id) do nothing;

-- ------------------------------------------------------------
-- REALTIME (aman dijalankan ulang)
-- ------------------------------------------------------------
alter table public.devices replica identity full;
alter table public.bagian replica identity full;
alter table public.plan replica identity full;
alter table public.app_settings replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.devices;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.bagian;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.plan;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.app_settings;
exception when duplicate_object then null;
end $$;

-- ------------------------------------------------------------
-- ROW LEVEL SECURITY
-- Aplikasi memakai key publik (anonymous) tanpa login, sehingga
-- policy "allow all" diperlukan. Untuk produksi resmi, gantikan
-- dengan policy berbasis auth user bila perlu.
-- ------------------------------------------------------------
alter table public.devices enable row level security;
alter table public.bagian enable row level security;
alter table public.plan enable row level security;
alter table public.app_settings enable row level security;

-- devices
do $$
begin
  create policy "anon select devices" on public.devices for select using (true);
exception when duplicate_object then null;
end $$;
do $$
begin
  create policy "anon insert devices" on public.devices for insert with check (true);
exception when duplicate_object then null;
end $$;
do $$
begin
  create policy "anon update devices" on public.devices for update using (true) with check (true);
exception when duplicate_object then null;
end $$;
do $$
begin
  create policy "anon delete devices" on public.devices for delete using (true);
exception when duplicate_object then null;
end $$;

-- bagian
do $$
begin
  create policy "anon select bagian" on public.bagian for select using (true);
exception when duplicate_object then null;
end $$;
do $$
begin
  create policy "anon insert bagian" on public.bagian for insert with check (true);
exception when duplicate_object then null;
end $$;
do $$
begin
  create policy "anon update bagian" on public.bagian for update using (true) with check (true);
exception when duplicate_object then null;
end $$;
do $$
begin
  create policy "anon delete bagian" on public.bagian for delete using (true);
exception when duplicate_object then null;
end $$;

-- plan
do $$
begin
  create policy "anon select plan" on public.plan for select using (true);
exception when duplicate_object then null;
end $$;
do $$
begin
  create policy "anon insert plan" on public.plan for insert with check (true);
exception when duplicate_object then null;
end $$;
do $$
begin
  create policy "anon update plan" on public.plan for update using (true) with check (true);
exception when duplicate_object then null;
end $$;
do $$
begin
  create policy "anon delete plan" on public.plan for delete using (true);
exception when duplicate_object then null;
end $$;

-- app_settings
do $$
begin
  create policy "anon select app_settings" on public.app_settings for select using (true);
exception when duplicate_object then null;
end $$;
do $$
begin
  create policy "anon update app_settings" on public.app_settings for update using (true) with check (true);
exception when duplicate_object then null;
end $$;