import 'package:flutter/material.dart';

import '../database/db_helper.dart';

/// Banner kecil di atas konten saat data tidak tersedia sama sekali
/// (cloud gagal DAN inisialisasi lokal gagal). Warna netral, bukan merah.
///
/// Saat mode lokal aktif (Supabase belum dikonfigurasi/gagal) atau cloud
/// tersambung, banner tidak ditampilkan agar tidak mengganggu pengguna.
class CloudStatusBanner extends StatelessWidget {
  const CloudStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Mode lokal (SQLite + seed Excel) dianggap "siap": data sudah terisi,
    // sehingga tidak ada banner error yang mengganggu.
    if (DbHelper.instance.synced) return const SizedBox.shrink();

    final error = DbHelper.instance.lastError;

    return Material(
      color: const Color(0xFFFDF3E3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: Color(0xFF8A6D2F)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error ?? 'Data tidak tersedia. Coba buka ulang aplikasi.',
                style: const TextStyle(
                    color: Color(0xFF7A6130), fontSize: 12, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}