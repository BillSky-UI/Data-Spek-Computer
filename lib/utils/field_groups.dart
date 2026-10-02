import 'dart:collection';

import '../models/device.dart';

/// Label khusus untuk data kosong / null.
const String belumDiInput = 'Belum di input';

/// Tampilkan nilai; jika kosong/null tampilkan "Belum di input".
String display(String v) =>
    v.trim().isEmpty ? belumDiInput : v.trim();

/// Isi dengan field data yang kosong pada detail view.
bool isEmpty(String v) => v.trim().isEmpty;

// ---------- Grup kategori spesifikasi ----------

/// Normalisasi kategori perangkat ke tab utama: Computer, Laptop, Printer.
/// Data lama (mis. "Komputer") dipetakan agar tetap muncul di tab Computer.
String categoryKey(String raw) {
  final t = raw.trim().toLowerCase();
  if (t.isEmpty) return 'Computer';
  if (t.contains('laptop')) return 'Laptop';
  if (t.contains('print')) return 'Printer';
  if (t.contains('computer') || t.contains('komputer')) return 'Computer';
  return raw.trim();
}

/// Prosesor dikelompokkan berdasarkan seri (Core i3/i5/i7/i9, Ryzen).
String processorGroup(String s) {
  final t = s.trim();
  if (t.isEmpty) return belumDiInput;
  final lower = t.toLowerCase();
  if (lower.contains('i3')) return 'Core i3';
  if (lower.contains('i5')) return 'Core i5';
  if (lower.contains('i7')) return 'Core i7';
  if (lower.contains('i9')) return 'Core i9';
  if (lower.contains('ryzen')) return 'AMD Ryzen';
  if (t.length <= 24) return t;
  return '${t.substring(0, 24).trim()}…';
}

/// Motherboard ditampilkan sebagai baris pertama (label singkat).
String motherboardGroup(String s) {
  final t = s.replaceAll('\n', ' ').trim();
  if (t.isEmpty) return belumDiInput;
  if (t.length > 32) return '${t.substring(0, 32).trim()}…';
  return t;
}

/// Storage dikelompokkan berdasarkan jenis media.
String storageGroup(String s) {
  final t = s.toLowerCase();
  if (t.trim().isEmpty) return belumDiInput;
  if (t.contains('nvme')) return 'NVMe SSD';
  if (t.contains('ssd')) return 'SSD';
  if (t.contains('hdd')) return 'HDD';
  return 'Lainnya';
}

/// RAM dinormalisasi ke kapasitas (8 GB, 16 GB, ...).
String ramGroup(String s) {
  final m = RegExp(r'(\d+(?:[.,]\d+)?)\s*([GM]B)', caseSensitive: false)
      .firstMatch(s.trim());
  if (m == null) return s.trim().isEmpty ? belumDiInput : s.trim();
  final num = m.group(1)!.replaceAll(',', '.');
  var value = double.tryParse(num) ?? 0;
  final unit = m.group(2)!.toUpperCase();
  if (unit == 'MB') value = value / 1024;
  final intVal = value % 1 == 0 ? value.toInt().toString() : value.toString();
  return '$intVal GB';
}

/// OS Windows dikelompokkan berdasarkan versi utama.
String osGroup(String s) {
  final t = s.trim();
  if (t.isEmpty) return belumDiInput;
  final lower = t.toLowerCase();
  if (lower.contains('windows 11')) return 'Windows 11';
  if (lower.contains('windows 10')) return 'Windows 10';
  if (lower.contains('windows 7')) return 'Windows 7';
  if (lower.contains('server')) return 'Windows Server';
  return t.length <= 20 ? t : '${t.substring(0, 20).trim()}…';
}

// ---------- Status ringkasan ----------

/// Label default setiap field spesifikasi.
String specLabel(String key) => _specLabels[key] ?? key;

/// Label khusus kategori Printer — fokus pada detail printer, bukan
/// spesifikasi PC (processor/motherboard/ram/os tidak relevan sebagai
/// "spesifikasi komputer").
String printerSpecLabel(String key) => _printerLabels[key] ?? specLabel(key);

/// Label default (Computer / Laptop).
const _specLabels = <String, String>{
  'prosesor': 'Spesifikasi Prosesor',
  'motherboard': 'Motherboard',
  'ram': 'RAM',
  'storage': 'Storage',
  'osWindows': 'OS Windows',
  'goal': 'Goal',
  'perluUpgradeGanti': 'Perlu Upgrade - Ganti',
  'perluUpgradeRepair': 'Perlu Upgrade - Repair',
  'statusUpgrade': 'Status Upgrade',
  'keterangan': 'Keterangan',
  'statusStiker': 'Status Stiker',
};

/// Label khusus Printer (kolom tetap, tampilan menyesuaikan kategori).
const _printerLabels = <String, String>{
  'prosesor': 'Tipe / Model Printer',
  'motherboard': 'Metode Koneksi (USB / WiFi / Network)',
  'perluUpgradeGanti': 'Perlu Ganti (Sparepart / Unit)',
  'perluUpgradeRepair': 'Perlu Repair',
  'statusUpgrade': 'Status Perbaikan',
  'keterangan': 'Keterangan',
  'statusStiker': 'Status Stiker',
};

/// Field yang tidak relevan untuk Printer sehingga tidak ditampilkan di
/// halaman detail perangkat, preview cetak, dan lembar PDF.
///
/// Data lama di kolom ini tetap tersimpan di database, hanya disembunyikan
/// dari tampilan supaya printer tidak menampilkan baris kosong.
const _printerHiddenKeys = <String>{
  'ram',
  'storage',
  'osWindows',
  'goal',
};

/// Benar bila field ini perlu ditampilkan untuk kategori perangkat tersebut.
bool showSpecField(String key, String category) =>
    !(categoryKey(category) == 'Printer' && _printerHiddenKeys.contains(key));

/// Label field untuk kategori tertentu (Printer → label khusus printer).
String labelFor(String key, String category) =>
    categoryKey(category) == 'Printer' ? printerSpecLabel(key) : specLabel(key);

/// Perangkat dianggap "Tercapai / Compatible" bila status upgrade selesai
/// atau goal menyatakan tercapai/kompatibel.
bool isTercapai(Device d) {
  final status = d.statusUpgrade.toLowerCase();
  final goal = d.goal.toLowerCase();
  if (status.startsWith('compl')) return true;
  if (status.contains('compatible')) return true;
  if (goal.contains('tercapai')) return true;
  if (goal.contains('compatible') || goal.contains('kompetible')) return true;
  return false;
}

/// Perlu perbaikan/penggantian bila kolom "Perlu Upgrade - Ganti/Repair" = Yes.
bool needsUpgrade(Device d) {
  final ganti = d.perluUpgradeGanti.toLowerCase();
  final repair = d.perluUpgradeRepair.toLowerCase();
  return ganti.startsWith('y') || repair.startsWith('y');
}

// ---------- Agregasi ----------

/// Kelompokkan perangkat berdasarkan grouper dan hitung jumlah tiap kategori.
/// Hasil diurutkan: jumlah terbanyak dulu, lalu label alfabetis.
Map<String, int> aggregate(
    Iterable<Device> devices, String Function(Device) group) {
  final map = <String, int>{};
  for (final d in devices) {
    final key = group(d);
    map[key] = (map[key] ?? 0) + 1;
  }
  final sorted = map.entries.toList()
    ..sort((a, b) {
      final c = b.value.compareTo(a.value);
      if (c != 0) return c;
      return a.key.compareTo(b.key);
    });
  return LinkedHashMap.fromEntries(sorted);
}