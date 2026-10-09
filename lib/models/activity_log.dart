/// Satu baris riwayat aktivitas (audit trail).
///
/// Dicatat pada setiap perubahan data penting: tambah/ubah/hapus perangkat,
/// ganti PIN, impor/reseed dari Excel. Tersimpan di SQLite lokal (fallback)
/// dan cloud supabase `activity_log` (best-effort) sehingga riwayat tetap ada
/// walau offline.
class ActivityLog {
  final int? id;
  final String action;
  final String kode;
  final String deviceName;
  final String detail;
  final String createdAt;

  const ActivityLog({
    this.id,
    required this.action,
    required this.kode,
    required this.deviceName,
    this.detail = '',
    required this.createdAt,
  });

  ActivityLog copyWith({int? id}) => ActivityLog(
        id: id ?? this.id,
        action: action,
        kode: kode,
        deviceName: deviceName,
        detail: detail,
        createdAt: createdAt,
      );

  /// Struktur baris SQLite & cloud (id + created_at diisi DB).
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'action': action,
        'kode': kode,
        'device_name': deviceName,
        'detail': detail,
        'created_at': createdAt,
      };

  /// Payload untuk insert cloud Supabase (kolom diisi default DB).
  Map<String, dynamic> toCloudMap() => {
        'action': action,
        'kode': kode,
        'device_name': deviceName,
        'detail': detail,
      };

  factory ActivityLog.fromMap(Map<String, dynamic> m) => ActivityLog(
        id: m['id'],
        action: (m['action'] ?? '').toString(),
        kode: (m['kode'] ?? '').toString(),
        deviceName: (m['device_name'] ?? '').toString(),
        detail: (m['detail'] ?? '').toString(),
        createdAt: (m['created_at'] ?? '').toString(),
      );
}