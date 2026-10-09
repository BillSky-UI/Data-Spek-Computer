import '../models/device.dart';

/// Label kolom yang dicocokkan untuk selisih perubahan perangkat.
final _kolomLabel = <String, String Function(Device)>{
  'Kode Inventaris': (d) => d.kodeInventaris,
  'Tanggal Evaluasi': (d) => d.tanggalEvaluasi,
  'PLAN': (d) => d.plan,
  'Bagian': (d) => d.bagian,
  'Nama Device': (d) => d.deviceName,
  'Kategori': (d) => d.category,
  'Prosesor': (d) => d.prosesor,
  'Motherboard': (d) => d.motherboard,
  'RAM': (d) => d.ram,
  'Storage': (d) => d.storage,
  'OS Windows': (d) => d.osWindows,
  'Goal': (d) => d.goal,
  'Upgrade Ganti': (d) => d.perluUpgradeGanti,
  'Upgrade Repair': (d) => d.perluUpgradeRepair,
  'Status Upgrade': (d) => d.statusUpgrade,
  'Keterangan': (d) => d.keterangan,
  'Status Stiker': (d) => d.statusStiker,
  'Drive Link': (d) => d.driveLink,
};

/// Ringkasan "kolom lama → baru" antara dua versi perangkat.
///
/// Menghasilkan string seperti "Bagian: HRD → Keuangan; Storage: 256GB → 512GB"
/// untuk diisi ke riwayat aktivitas. Kosong bila tidak ada perbedaan.
String diffDevice(Device? lama, Device baru) {
  if (lama == null) return '';
  final parts = <String>[];
  for (final e in _kolomLabel.entries) {
    final a = (e.value(lama)).trim();
    final b = (e.value(baru)).trim();
    if (a == b) continue;
    parts.add('${e.key}: ${a.isEmpty ? '(kosong)' : a} → ${b.isEmpty ? '(kosong)' : b}');
  }
  return parts.join('; ');
}