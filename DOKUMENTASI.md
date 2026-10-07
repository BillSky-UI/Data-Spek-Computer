# Dokumentasi Aplikasi Inventaris Spek Komputer (DPR)

Versi Aplikasi : **3.5.1 (build 6)**
Nama Paket : `spek_komputer`
Judul di Layar : **Spek Inventaris DPR**
Perusahaan : **PT. DWI PRIMA REZEKY - IT**

---

## 1. Ringkasan Singkat

Aplikasi ini adalah sistem **manajemen inventaris perangkat komputer** (PC Desktop, Laptop, dan
Printer) untuk kebutuhan internal perusahaan. Fungsinya:

- Mencatat dan menyimpan spesifikasi tiap perangkat (prosesor, motherboard, RAM, storage, OS).
- Mengelola **PLAN** dan **Bagian** sebagai master data.
- Menampilkan statistik dan dashboard kondisi perangkat.
- Menghasilkan **barcode/QR, stiker, dan PDF spesifikasi** untuk ditempel di perangkat.
- Mendukung **offline** (SQLite) maupun **sinkronisasi cloud** (MySQL + REST API PHP).
- Mengimpor dan mengekspor data ke/from Excel.

Aplikasi berjalan di **Android, iOS, dan Web (PWA)** dari satu basis kode.

---

## 2. Bahasa Pemrograman & Teknologi

### 2.1 Bahasa Utama: **Dart** (dengan framework **Flutter**)

Seluruh logika aplikasi ditulis menggunakan **bahasa Dart**. Flutter adalah framework UI dari Google
yang membuat satu kode Dart dapat dijalankan di Android, iOS, maupun Web.

| Lapisan | Teknologi | Keterangan |
|---|---|---|
| Bahasa aplikasi | **Dart** | Seluruh file `lib/*.dart` |
| Framework UI | **Flutter** | Widget, navigasi, tema, layout |
| Basis data cloud | **MySQL** (via `backend/api.php`, REST + polling 5 detik) | |
| Basis data offline | **SQLite** | `sqflite` (Android/iOS), `sqlite3.wasm` (Web) |
| Bahasa query | **SQL** | `CREATE TABLE`, `ALTER TABLE`, `SELECT`, `INSERT` |
| Android | **Kotlin** + Gradle | `MainActivity.kt` sebagai *host*, logika bisnis tetap Dart |
| iOS | **Swift** | `AppDelegate.swift` sebagai *host* |
| Web | **HTML + JavaScript** | `web/index.html`, `flutter_bootstrap.js` (PWA) |
| Utilitas terpisah | **Node.js + Express** | `server.js` (berbasis `xlsx`) — alat bantu baca Excel, **bukan** bagian dari runtime aplikasi Flutter |

> **Ringkas:** kalau ditanya "aplikasi ini dibuat pakai bahasa apa?", jawabannya **Dart (Flutter)**.
> additionally dengan **SQL** untuk basis data, **Kotlin/Swift** hanya untuk pembungkus native Android/iOS,
> dan **JavaScript/HTML** untuk versi web.

### 2.2 Library/Package yang Digunakan

| Package | Fungsi |
|---|---|
| `http` ^1.6.0 | Klien REST ke `backend/api.php` (MySQL, polling 5 detik) |
| `sqflite` + `sqflite_common_ffi_web` | Database lokal SQLite (Android/iOS & Web) |
| `excel` ^4.0.6 | Membaca & menulis file `.xlsx` |
| `file_picker` | Memilih file Excel dari penyimpanan HP |
| `pdf` | Membuat PDF spesifikasi & stiker |
| `barcode_widget` | Menggambar barcode & QR Code |
| `gal` | Menyimpan file ke galeri |
| `share_plus` | Membagikan file (PDF/PNG) ke WhatsApp, email, dll. |
| `permission_handler` | Meminta izin kamera & penyimpanan |
| `mobile_scanner` | Scanner QR / barcode bawaan aplikasi |
| `fl_chart` | Grafik lingkaran (pie) status stiker |
| `intl` | Format tanggal Indonesia |
| `shared_preferences` | Menyimpan tema & hash PIN di perangkat |
| `crypto` | Hash **SHA-256** untuk PIN (PIN tidak disimpan sebagai teks polos) |
| `path_provider` | Lokasi folder dokumen aplikasi |
| `web` | Dukungan tampilan khusus web |
| `flutter_lints` ^6.0.0 | Aturan kualitas kode (analisis statis) |

### 2.3 Persyaratan Teknis

- **Flutter SDK** dengan Dart `^3.13.2` (dari `pubspec.yaml`).
- **Android minSdk 21** (Android 5.0 Lollipop ke atas).
- Versi aplikasi: `3.5.1+6` (versionName `3.5.1`, versionCode `6`).

---

## 3. Struktur Folder Proyek

```
lib/
├── main.dart                     # Entry point: baca config.json, init cloud, buka gerbang PIN
├── app_info.dart                 # Nama & versi aplikasi
├── env/app_config.dart           # Konfigurasi MySQL & URL publik QR
├── models/device.dart            # Model data Device (17 field)
├── database/
│   ├── db_helper.dart            # Otak data: CRUD, cache, import Excel, master data, PIN cloud
│   ├── local_database.dart       # SQLite lokal (tabel devices, bagian_master, plan_master)
│   ├── web_db_factory.dart       # Adapter SQLite untuk Web
│   └── db_factory_stub.dart      # Stub untuk platform tanpa SQLite
├── pages/                        # Semua halaman layar
│   ├── pin_login_page.dart       # Layar masuk PIN
│   ├── change_pin_page.dart      # Ganti PIN
│   ├── main_shell.dart           # Kerangka + bottom navigation
│   ├── device_list_page.dart     # Daftar perangkat (grouping per kategori)
│   ├── category_picker_page.dart # Pilih kategori saat tambah data
│   ├── device_form_page.dart     # Form tambah/edit perangkat
│   ├── detail_page.dart          # Detail perangkat
│   ├── dashboard_page.dart       # Dashboard & statistik
│   ├── spec_breakdown_page.dart  # Rincian varian spesifikasi
│   ├── variant_devices_page.dart # Daftar device per varian
│   ├── sticker_detail_page.dart  # Daftar device per status stiker
│   ├── print_preview_page.dart   # Preview & unduh PDF spesifikasi
│   └── scan_page.dart            # Scanner QR / barcode
├── services/
│   ├── export_service.dart       # Ekspor Excel multi-sheet & CSV
│   ├── sticker_pdf_service.dart  # PDF stiker 15,5×6 cm & label printer 7,6×3,8 cm
│   ├── detail_sheet_pdf_service.dart # Helper PDF
│   ├── barcode_export_service.dart # Barcode & QR
│   ├── pin_controller.dart       # Hash & verifikasi PIN
│   ├── settings_controller.dart  # Tema (light/dark/system)
│   ├── platform_saver*.dart      # Simpan file lintas platform
│   ├── public_saver_service.dart # Simpan ke folder Downloads
│   └── saved_target.dart         # Info lokasi file tersimpan
├── theme/app_theme.dart          # Tema warna terang & gelap
├── utils/field_groups.dart       # Normalisasi data + agregasi statistik
└── widgets/                      # Komponen reusable (popup menu, dialog stiker, dll.)

assets/
├── icon/logo.png                 # Logo aplikasi
├── seed_inventaris.xlsx          # Sumber data awal (seed, nama tanpa spasi)
└── arsip_spesifikasi_komputer_pc_internal.xlsx

test/                             # 5 file test otomatis (19 test)
android/, ios/, web/              # Proyek native per platform
```

---

## 4. Struktur Data

### 4.1 Field pada satu perangkat (tabel `devices`)

| No | Field | Nama Tampilan | Tipe |
|---|---|---|---|
| 1 | `tanggal_evaluasi` | Tanggal Evaluasi | teks `dd/mm/yyyy` |
| 2 | `kode_inventaris` | Kode Inventaris | teks, **otomatis** |
| 3 | `plan` | PLAN | teks (master data) |
| 4 | `bagian` | Bagian | teks (master data) |
| 5 | `device_name` | Device Name | teks, **wajib** |
| 6 | `category` | Category | Computer / Laptop / Printer |
| 7 | `prosesor` | Spesifikasi Prosesor (PC) / Tipe-Model (Printer) | teks |
| 8 | `motherboard` | Motherboard (PC) / Metode Koneksi (Printer) | teks |
| 9 | `ram` | RAM (PC) / Kecepatan Cetak ppm (Printer) | teks |
| 10 | `storage` | Storage (PC) / Kapasitas & Tray Kertas (Printer) | teks |
| 11 | `os_windows` | OS Windows (PC) / Kompatibilitas Driver (Printer) | teks |
| 12 | `goal` | Goal (PC) / Status Tinta-Toner (Printer) | teks |
| 13 | `perlu_upgrade_ganti` | Perlu Upgrade – Ganti | Yes / No |
| 14 | `perlu_upgrade_repair` | Perlu Upgrade – Repair | Yes / No |
| 15 | `status_upgrade` | Status Upgrade | Complated / Pending |
| 16 | `keterangan` | Keterangan | teks bebas |
| 17 | `status_stiker` | Status Stiker | Sudah / Belum |
| 18 | `drive_link` | Link Google Drive Spesifikasi (opsional) | URL |

> **Penting:** label kolom 7–12 **berubah otomatis** bila kategori = Printer. Jadi satu form
> tetap dipakai untuk semua kategori, tetapi maknanya menyesuaikan.

### 4.2 Tabel Master Data

| Tabel | Isi | Dipakai di |
|---|---|---|
| `bagian` / `bagian_master` | Daftar unit kerja | Dropdown Bagian (form & dashboard) |
| `plan` / `plan_master` | Daftar PLAN | Dropdown PLAN (form & dashboard) |
| `app_settings` | Hash PIN (cloud) | Login & ganti PIN |

### 4.3 Aturan Kode Inventaris (otomatis)

Kode dibuat otomatis oleh sistem dan **tidak bisa diedit manual** (terkunci di form).

| Kategori | Prefix | Contoh |
|---|---|---|
| Computer | `K` | `K-001`, `K-002` |
| Laptop | `L` | `L-001` |
| Printer | `P` | `P-001` |

Nomor Always 3 digit dan berasal dari nomor terbesar yang sudah ada.

---

## 5. Cara Penyimpanan Data (Penting untuk Pemula)

Aplikasi punya **dua mode** yang dipilih otomatis:

1. **Mode Cloud (MySQL + REST API PHP)**
   - Aktif bila `MYSQL_API_URL` (dan opsional `MYSQL_API_KEY`) diisi saat build,
     atau di web melalui `web/config.json` / URL relatif `backend`.
   - Data tersimpan di server, tersinkron antar perangkat dengan **polling ringan
     tiap 5 detik** (`op=rev` lalu unduh ulang bila ada perubahan).

2. **Mode Lokal (SQLite)**
   - Otomatis dipakai bila cloud tidak dikonfigurasi atau gagal connect.
   - File basis data: `inventaris_local.db` di folder dokumen aplikasi.
   - Aplikasi tetap berfungsi penuh secara offline.

3. **Data Awal (Seed)**
   - Saat database masih kosong, aplikasi otomatis mengisi data dari file Excel
     bawaan (`assets/seed_inventaris.xlsx`).
   - File Excel kedua (`assets/arsip_spesifikasi_komputer_pc_internal.xlsx`) merupakan data historis/arsip.
   - Nama file aset **wajib tanpa spasi**: build web menaruh aset dengan nama ter-URL-encode
     (`%20`), sedangkan server statis (Vercel/Netlify/Express) mendekode-nya menjadi spasi
     sehingga file tidak ditemukan → error "Unable to load assets/…".

Anda dapat melihat mode yang aktif di **Pengaturan → Informasi Aplikasi → Basis Data**
(`Lokal (SQLite) — offline` atau `MySQL Cloud (sinkron 5 detik)`).

---

## 6. Panduan Penggunaan Fitur (Step-by-Step)

### 6.1 Membuka Aplikasi

1. Aplikasi terbuka ke layar **PIN**.
2. Masukkan PIN lalu tekan **Buka Aplikasi**.
3. **PIN awal: `0000`** (4–6 digit).
4. Jika belum pernah mengatur PIN, sistem otomatis memakai PIN bawaan tersebut.
5. PIN disimpan sebagai **hash SHA-256** di perangkat — bukan disimpan sebagai teks biasa.

> Stability: PIN bersifat lokal per perangkat. Mengganti PIN tidak menghapus data.

### 6.2 Struktur Navigasi

```
Layar PIN
   │
   ▼
┌──────────────────────────────────────────┐
│  [Banner status cloud, bila ada masalah]│
├──────────────────────────────────────────┤
│  Konten halaman                          │
│  ┌──────────────┐  ┌──────────────────┐  │
│  │ Daftar        │  │ Dashboard        │  │
│  │ Perangkat    │  │                  │  │
│  └──────────────┘  └──────────────────┘  │
└──────────────────────────────────────────┘
   bottom navigation (2 tab)
```

Menu tambahan (titik tiga di kanan atas):
- **Pengaturan**
- **Export to Excel**
- **Tentang Aplikasi**

### 6.3 Tab 1 — Daftar Perangkat

#### Pencarian & Penyaringan
- **Kolom cari**: ketik Kode Inventaris atau Nama device.
- **Chip kategori**: `Semua`, `Computer`, `Printer`, `Laptop`, plus jumlah data.
- **Dropdown Bagian**: saring hanya device dari unit tertentu.

#### Tampilan Berbentuk Grup
Data dikelompokkan dengan header berisi ikon + jumlah, urutan:

1. **KOMPUTER**
2. **PRINTER**
3. **LAPTOP**
4. **LAINNYA** (apabila ada kategori lain)

#### Ikon di pojok kanan atas
| Ikon | Fungsi |
|---|---|
| `+ Tambah Data` | Membuka halaman pilih kategori |
| Scan (kamera) | Membuka scanner QR/barcode |
| Import (Excel) | Memilih & mengimpor file `.xlsx` |
| Titik tiga | Popup menu (Pengaturan/Export/Tentang) |

#### Asset List Kosong
Jika tidak ada data yang cocok, muncul pesan **"Tidak ada data yang cocok"**.

### 6.4 Menambah Data Baru

1. Tekan **+ Tambah Data**.
2. Pilih kategori: **Computer**, **Laptop**, atau **Printer**.
   - Setiap kategori punya keterangan singkat (mis. Printer = "form khusus detail printer").
3. Form terbuka dengan **kode inventaris sudah terisi otomatis** dan terkunci.

#### Isi Form (umum)
| Field | Tipe | Catatan |
|---|---|---|
| Kode Inventaris | Otomatis | Terkunci, berbeda per kategori |
| Tanggal Evaluasi | Tanggal picker | Format `dd/mm/yyyy` |
| PLAN | Dropdown | Dari master data Pengaturan |
| Bagian | Dropdown | Dari master data Pengaturan |
| Device Name | Teks | **Wajib diisi** |
| Category | Terkunci / dropdown | Terkunci saat tambah baru |
| Spesifikasi (5 kolom) | Teks | Label menyesuaikan kategori |
| Goal / Status Tinta | Teks | |
| Perlu Upgrade – Ganti | Dropdown | `Yes` / `No` |
| Perlu Upgrade – Repair | Dropdown | `Yes` / `No` |
| Status Upgrade | Dropdown | `Complated` / `Pending` |
| Keterangan | Teks (3 baris) | Catatan bebas |
| Status Stiker | Dropdown | `Sudah` / `Belum` |
| Link Google Drive | URL (opsional) | Di-encode ke QR pada menu Download Barcode |

4. Tekan **Simpan** (atau **Simpan Perubahan** saat edit).
5. Data langsung muncul di Dashboard dan Daftar Perangkat.

> **Catatan:** PLAN dan Bagian **tidak bisa ditambah dari form**. Kelola lewat
> **Pengaturan → Master Data → Edit Plan / Edit Bagian**.

### 6.5 Edit & Hapus Perangkat

1. Ketuk salah satu device di Daftar Perangkat.
2. Di **Detail Perangkat** ada tombol aksi di bawah:
   - **Edit** → membuka form yang sudah terisi.
   - **Hapus** → dialog konfirmasi, lalu data dihapus dari cloud & lokal.
   - **Cetak / Download** → lihat sub-bawah ini.

### 6.6 Scan QR / Barcode

1. Tekan ikon kamera di halaman Daftar Perangkat atau Dashboard.
2. Arahkan kamera ke QR/barcode stiker.
3. Jika kode ditemukan → langsung membuka **Detail Perangkat**.
4. Jika tidak ditemukan → pesan **"Kode '...' tidak ditemukan di inventaris"**.
5. Ada tombol **Coba Lagi** bila kamera gagal diakses.

### 6.7 Cetak / Download (3 Opsi)

| Opsi | Hasil | Format |
|---|---|---|
| **Download Barcode** | Barcode + QR, siap cetak jadi stiker | **PNG** |
| **Preview & Download PDF Spesifikasi** | Dokumen teks spesifikasi lengkap, ada preview | **A4 PDF** |
| **Download Stiker (Template)** | Stiker inventaris + spesifikasi perangkat keras | **PDF 15,5 × 6 cm** (printer: **7,6 × 3,8 cm**) |

- Pada dialog stiker/barcode ada tombol **Download** dan **Bagikan** (kirim ke WhatsApp/dll).
- **Stiker PDF tidak memuat barcode maupun QR** — isinya hanya judul, 2 baris identitas,
  sub-header, dan tabel perangkat keras. Butuh kode pindai? Gunakan menu **Download Barcode**
  (PNG) yang sudah tersedia terpisah.
- **Storage untuk stiker Computer/Laptop** bisa dipilih ulang saat cetak karena nilai
  `storage` di input sering tidak konsisten (mis. "256GB SSD Sata"). Dialog menampilkan daftar
  ukuran (8 GB–2TB); tiap ukuran bisa diisikan **jumlah unit** (mis. 256 GB ada 2 + 128 GB ada 3),
  hasilnya dicetak sebagai `256 GB 2x + 128 GB 3x`. Tanpa pilihan, stiker memakai nilai tersimpan.
- Desain stiker dipilih otomatis dari kategori perangkat:

  | Kategori | Desain | Kertas | Isi |
  |---|---|---|---|
  | Computer / Laptop | `Logo/Template Stiker.pdf` | 15,5 × 6 cm | Judul, 2 baris identitas, pita abu, tabel 5 komponen |
  | **Printer** | `Logo/Label Inventaris Kantor.pdf` | **7,6 × 3,8 cm** | Nama Barang, Bagian, Nama PIC, Kode Unit, Tanggal Penyerahan |

- **Stiker printer** memakai gambar desain asli (`assets/img/stiker_printer_bg.jpg`,
  898 × 449 px) sebagai latar penuh, jadi logo, garis bingkai, dan tulisan label
  identik dengan desain; yang digambar ulang hanya nilai datanya. Pemetaannya:
  `Nama Barang` = kolom **Tipe / Model Printer** di form, `Bagian` = bagian,
  `Nama PIC` = nama perangkat, `Kode Unit` = kode inventaris,
  `Tanggal Penyerahan` = kolom **Tanggal Evaluasi** (ditulis di kotak kanan-bawah
  desain, kolom **"Tgl.Penyerahan"** yang cuma ada di raster). Desain tidak punya
  kolom Keterangan, jadi `keterangan` tidak dicetak di stiker printer. Posisi nilai
  diukur dari content stream PDF desain (215,52 × 107,76 pt) lalu dikonversi ke milimeter.
- **Font stiker printer**: desain memakai Calibri-Bold 6 pt. Calibri adalah font
  proprietary Microsoft sehingga tidak disertakan; yang dipakai sebagai gantinya
  **Carlito-Bold** (`assets/fonts/Carlito-Bold.ttf`), klon open-source yang
  metrik dan tampilannya identik dengan Calibri — hasilnya hurufnya pas dengan
  desain (Helvetica-Bold sebelumnya terlalu lebar). Kalau font gagal dimuat,
  aplikasi jatuh ke Helvetica-Bold supaya PDF tetap bisa dibuat.
- Ukuran kertas stiker biasa adalah **15,5 × 6 cm** (landscape). Posisi absolut semua elemen
  (`pw.Stack` + `pw.Positioned`) diukur dari `Logo/Template Stiker.pdf` (ruang desain
  157 × 63 mm), lalu diperkecil seragam dengan faktor 0,9524 agar muat di kertas 15,5 × 6 cm
  tanpa meregangkan logo maupun garis. Tata letak tidak bergeser meskipun isi data
  berbeda-beda. Huruf dikecilkan otomatis bila teks terlalu lebar untuk kolomnya
  (batas bawah 5 pt, atau 3 pt untuk stiker printer) supaya kode inventaris panjang
  tetap tercetak utuh.
- Kedua desain dibangun di isolate latar (`compute`) dengan aset gambar di-cache,
  sehingga unduhan stiker tidak membekukan UI (±0,1 detik setelah aset ter-cache).


### 6.8 Tab 2 — Dashboard

#### Ringkasan Angka
Tiga kartu di atas: **Total Perangkat**, **Total Bagian**, **Total PLAN**.

#### Penyaringan
- Dropdown **Semua Bagian**
- Dropdown **Semua PLAN**

#### Grafik Status Stiker
- Diagram lingkaran (pie) **`STATUS STIKER`**: Sudah vs Belum.
- **Ketuk** grafik → halaman **Status Stiker** yang memisahkan device
  **"BELUM DITEMPEK"** dan yang sudah, lengkap dengan jumlahnya.

#### Statistik Spesifikasi
Enam kartu (2 kolom):
| Kartu | Pengelompokan otomatis |
|---|---|
| **Processor** | Core i3 / i5 / i7 / i9 / AMD Ryzen |
| **Motherboard** | Ditruncate ringkas (32 karakter) |
| **Storage** | NVMe SSD / SSD / HDD / Lainnya |
| **RAM / Memory** | Dihitung ke GB (mis. `2048 MB` → `2 GB`) |
| **OS Windows** | Windows 11 / 10 / 7 / Server |
| **Category Device** | Computer / Laptop / Printer |

Setiap kartu menampilkan jumlah perangkat per varian + persentase.
- Tekan **Lihat Rincian** → halaman **Rincian …** berisi daftar varian, jumlah, dan persen.
- Tekan satu varian → **Device per Varian** (daftar device di varian itu, siap diketuk ke detail).

#### Status Kosong
Jika tidak ada data, tampil **"Belum ada data perangkat"**.

### 6.9 Pengaturan

#### Tema Aplikasi
- **Mengikuti sistem** / **Terang** / **Gelap**. Pilihan langsung tersimpan di perangkat.

#### Keamanan Aplikasi
- **Ubah PIN**: masukkan PIN Lama, PIN Baru (4–6 digit), lalu Konfirmasi.
  - Notifikasi **"PIN berhasil diubah"** bila sukses.

#### Master Data
Dua baris yang bisa dibuka-tutup (chevron). **Tertutup secara default** agar tampilan ringkas.

| Baris | Isi | Aksi |
|---|---|---|
| **Edit Bagian** | Jumlah bagian tersimpan | Tambah, Edit (ikon pensil), Hapus (ikon tong) |
| **Edit Plan** | Jumlah PLAN tersimpan | Tambah, Edit, Hapus |

- Baris **Tambah Bagian Baru** / **Tambah PLAN Baru** berada di bagian bawah masing-masing daftar.
- Edit/Hapus menggunakan dialog dengan tombol **Simpan** / **Hapus** dan pembatalan **Batal**.
- Setelah berhasil, daftar langsung diperbarui dan **dropdown di form serta Dashboard ikut ter-update**
  otomatis.

#### Data
- **Ekspor ke Excel** → menyimpan `.xlsx` (multi-sheet) ke folder **Download** HP.
- **Ekspor ke CSV** → menyimpan `.csv` ke folder **Download** HP.
- Setelah selesai, muncul notifikasi lokasi file tersimpan.

#### Informasi Aplikasi
- Nama Aplikasi, Versi (`V3.5.1 (build 6)`), Basis Data aktif, dan keterangan Data Awal.

### 6.10 Tentang Aplikasi
Dialog berisi nama, versi, dan deskripsi singkat; tombol **Tutup** untuk keluar.

### 6.11 Banner Status Cloud
Banner berwarna krem muncul **hanya jika cloud GAGAL dan database lokal juga gagal diinisialisasi**,
dengan pesan penyebabnya. Bila mode lokal aktif (data sudah terisi) atau cloud tersambung,
banner tidak ditampilkan agar tidak mengganggu.

---

## 7. Format File Excel

### 7.1 Struktur Ekspor (`.xlsx`)

- **3 sheet**: `Computer`, `Laptop`, `Printer` (sesuai urutan tab).
- **Kop**: baris judul `Quality of Devices (Computer|Laptop|Printer)`,
  baris perusahaan `PT. DWI PRIMA REZEKY - IT`, dan baris periode.
- **Header 2 baris** (group header + sub-header), 17 kolom:

| # | Group Header | Sub-header |
|---|---|---|
| 1 | Tanggal Evaluasi | — |
| 2 | Kode Inventaris | — |
| 3 | PLAN | — |
| 4 | Bagian | — |
| 5 | Device Name | — |
| 6 | Category | — |
| 7 | Spesifikasi Saat Ini | Processor |
| 8 | Spesifikasi Saat Ini | Motherboard |
| 9 | Spesifikasi Saat Ini | RAM |
| 10 | Spesifikasi Saat Ini | Storage |
| 11 | Spesifikasi Saat Ini | OS Windows |
| 12 | Goal | — |
| 13 | Perlu Upgrade | Ganti |
| 14 | Perlu Upgrade | Repair |
| 15 | Status Upgrade | — |
| 16 | Keterangan | — |
| 17 | Status Stiker | — |

- Sel ditata: lebar kolom otomatis, header di-merge dan diberi warna, sel data diberi border.
- Kolom berformat panjang dipotong/di-line-break agar rapi.

### 7.2 Ekspor CSV
- Format `.csv` dengan pemisah titik koma (`;`) dan BOM UTF-8 agar **dibuka rapi di Excel Indonesia**.

### 7.3 Cara Impor Excel (Fitur Import)

1. Tekan ikon **Import dari Excel** di halaman Daftar Perangkat.
2. Pilih file `.xlsx` dari penyimpanan HP (file picker, hanya ekstensi `xlsx` yang tampil).
3. Aplikasi membaca **seluruh sheet** (`Computer`, `Laptop`, `Printer`) secara otomatis:
   - Mendeteksi baris header utama maupun sub-header setelah baris kop/spacer.
   - Mengenali header Bahasa Inggris (mis. `Processor`).
   - Melewatkan baris tanpa Kode Inventaris.
4. Data **disimpan ke SQLite lokal** dan, bila cloud aktif, **di-upsert ke MySQL** lalu
   cache di-refresh agar ID cloud tersedia.
5. Muncul notifikasi **"Impor Excel berhasil: N perangkat tersimpan."**; bila tidak ada baris
   yang dikenali, muncul **"File Excel kosong / kolom tidak dikenali."**; bila error,
   muncul **"Gagal impor Excel: ..."**.

> **Tips:** Impor bersifat **upsert berdasarkan Kode Inventaris**. Mengimpor ulang file yang sama
> **tidak** menggandakan data; data lama diperbarui.

---

## 8. Ringkasan Alur Kerja Harian

```
Buka aplikasi → masuk PIN
   ↓
Daftar Perangkat: cari / saring / pilih grup
   ↓
Ketuk device → lihat Detail
   ├─ Edit → ubah spesifikasi → Simpan
   ├─ Hapus → konfirmasi
   └─ Cetak/Download → Barcode PNG | PDF A4 | Stiker PDF
   ↓
Tambah baru → + Tambah Data → pilih kategori → isi form → Simpan
   ↓
Scan QR (dari Barcode PNG / label QR) → langsung ke Detail
   ↓
Dashboard → cek statistik → ketuk varian → lihat device
   ↓
Pengaturan → Tema / PIN / Master Data (Bagian & Plan) / Ekspor Excel-CSV
```

---

## 9. Panduan untuk Developer

### 9.1 Menjalankan di Komputer (Development)
```bash
flutter pub get          # unduh dependency
flutter run              # jalankan di emulator/HP
flutter run -d chrome    # jalankan versi web
```

### 9.2 Build APK Android (Rilis)
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### 9.3 Build dengan Cloud (MySQL) Aktif
```bash
flutter build apk --release \
  --dart-define=MYSQL_API_URL=https://domain.com/backend \
  --dart-define=MYSQL_API_KEY=rahasia-api-anda
```
`MYSQL_API_URL` = folder deploy yang berisi `api.php`; `MYSQL_API_KEY` = kunci API dari
`backend/config.php` (opsional). Deploy web: upload `backend/` ke hosting, impor
`backend/schema.sql` di phpMyAdmin (atau biarkan auto-migrate), buat `backend/config.php`
dari `backend/config.example.php`, dan bila perlu isi `web/config.json`.

### 9.4 Opsional — QR (Barcode PNG) Menunjuk Halaman Web Publik
```bash
flutter build apk --release \
  --dart-define=PUBLIC_BASE_URL=https://nama-proyek.netlify.app
```
Jika diisi, QR pada **Download Barcode** menjadi `https://nama-proyek.netlify.app?kode=K-001`,
sehingga kamera HP biasa langsung membuka halaman detail tanpa perlu instal aplikasi.
(Prioritas target QR: `Link Google Drive` → `PUBLIC_BASE_URL?kode=...` → kode inventaris.)

### 9.5 Build Web (PWA)
```bash
flutter build web
```
Folder `web/` sudah disiapkan sebagai PWA (manifest, ikon, `sqlite3.wasm`, service worker
`sqflite_sw.js`).

Hasil build yang **dibagikan ke web** adalah folder **`web-deploy/`** (hasil `flutter build web
--release` yang disalin ke sana dan ikut ter-commit) — isinya identik dengan aplikasi HP. Folder
ini yang dipakai untuk hosting statis (Vercel/GitHub Pages/Netlify) maupun disajikan `server.js`.

#### Deploy ke Vercel
`vercel.json` sudah disiapkan: `buildCommand` kosong (tanpa build di sisi Vercel) dan
`outputDirectory: web-deploy`; `.vercelignore` membuang source Flutter agar upload ringan.
Deploy ulang: `flutter build web --release` → salin `build\web` ke `web-deploy\` (boleh lewati
`*.symbols`) → commit & push. Vercel otomatis take build baru dari `web-deploy/`.

### 9.6 Kualitas Kode
```bash
dart analyze --no-fatal-warnings   # analisis statis (hasil: No issues found!)
flutter test                      # 5 file test, 19 test otomatis
```
Pengaturan aturan kode ada di `analysis_options.yaml` (menggunakan `flutter_lints`).

### 9.7 Membuat Ikon Aplikasi
```bash
dart run flutter_launcher_icons
```
Sumber ikon: `assets/icon/logo.png` (adaptive background `#1E3A8A`).

### 9.8 Utilitas Node.js (`server.js`)
Server **Express** pemeliharaan aplikasi lama (dulu menyajikan `public/`). Mulai v3.7 server ini
menyajikan **build Flutter penuh** dari `web-deploy` (identik APK) via `express.static` + fallback
SPA ke `index.html`; `npm start` (port 3000). Endpoint API (`/api/devices`, `/api/import`) dan
utilitas `xlsx` (Excel → `data/inventory.json`) masih ada untuk dukungan, namun aplikasi Flutter
mode lokal memakai SQLite browser (`sqlite3.wasm`) dan tidak bergantung pada API tersebut.

---

## 10. Kalau Ada Masalah (Troubleshooting)

| Gejala | Penyebab & Solusi |
|---|---|
| Kode inventaris bentrok | Kode dibuat dari nomor terbesar kategori terkait; bila data dihapus dari cloud tetapi cache lokal masih ada, tutup & buka ulang aplikasi. |
| Dropdown PLAN/Bagian kosong | Buka **Pengaturan → Master Data** lalu tambah, atau data sudah dipakai device sebelumnya otomatis tetap tampil. |
| Import Excel gagal | Pastikan file berformat `.xlsx` (bukan `.xls`/`.csv`) dan sheet berisi header yang dikenali. |
| Kamera tidak bisa scan | Beri izin kamera saat diminta; di Pengaturan sistem, aktifkan izin Kamera untuk aplikasi ini. |
| PDF/PNG tidak ditemukan | Lihat notifikasi "Tersimpan di …" yang muncul setelah mengunduh; periksa folder **Download**. |
| `dart analyze`-reported warning | Jalankan `dart format .` lalu analyze ulang. |
| Ingin reset ke data awal | Gunakan `reseedFromExcel()` di `db_helper.dart` (dipakai otomatis `seedIfEmpty()` bila database kosong). |

---

## 11. Glosarium Singkat

| Istilah | Arti |
|---|---|
| **PLAN** | Program/Keggiaan kerja yang menjadi acuan perangkat. |
| **Bagian** | Unit kerja / divisi pemilik perangkat. |
| **Master Data** | Daftar acuan yang dipakai berulang di form (kode, plan, bagian). |
| **Stiker** | Label kecil berisi identitas + spesifikasi perangkat keras (tanpa barcode/QR). Printer memakai desain label tersendiri 7,6 × 3,8 cm. |
| **Seed** | Pengisian awal data dari file Excel saat database kosong. |
| **Upsert** | Menyisipkan data baru, atau memperbarui bila Kode Inventaris sudah ada. |
| **Cache** | Salinan data di memori agar aplikasi cepat tanpa perlu unduhan ulang. |
| **PWA** | Web App yang bisa "diinstall" di layar utama HP. |
| **Realtime** | Data berubah otomatis di semua perangkat tanpa tombol refresh. |

---

## 12. Ringkasan Singkat untuk Dijawab Saat Wawancara / Ujian

> Aplikasi **Inventaris Spek Komputer DPR** dibuat dengan **bahasa Dart** menggunakan
> **framework Flutter** (versi 3.5.1+6). Data disimpan di **SQLite** (`sqflite`) untuk mode
> offline dan disinkronkan ke **MySQL (REST API PHP)** untuk mode cloud. Aplikasi dapat berjalan
> di **Android, iOS, dan Web (PWA)** dari satu basis kode. Fitur utamanya: inventaris perangkat
> (Computer/Laptop/Printer) dengan master data **PLAN** dan **Bagian**, dashboard statistik
> spesifikasi, scanner QR/barcode, serta pembuatan **barcode PNG, PDF A4, dan stiker PDF
> 15,5×6 cm**. Ekspor ke **Excel multi-sheet** (3 sheet) dan **CSV**; impor membaca seluruh sheet
> secara toleran. Keamanan menggunakan **PIN yang di-hash SHA-256**. Kode inventaris dibuat
> otomatis berawalan **K / L / P** dengan nomor 3 digit. Seluruh kode lolos `dart analyze` (No
> issues) dan 31 pengujian otomatis.
