import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/clickable.dart';
import 'device_form_page.dart';

/// Halaman pilihan awal kategori saat menekan "+ Tambah Data".
///
/// Pengguna memilih salah satu kartu: **Computer**, **Laptop**, atau
/// **Printer**. Setelah dipilih, form input terbuka otomatis dengan field
/// Kategori terkunci sesuai pilihan (tidak perlu dropdown lagi). Kategori
/// Printer membawa form khusus spesifikasi printer.
class CategoryPickerPage extends StatefulWidget {
  final String? nextKode;
  const CategoryPickerPage({super.key, this.nextKode});

  @override
  State<CategoryPickerPage> createState() => _CategoryPickerPageState();
}

class _CategoryPickerPageState extends State<CategoryPickerPage> {
  Future<void> _pick(String category) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceFormPage(
          category: category,
          nextKode: widget.nextKode,
        ),
      ),
    );
    if (!mounted) return;
    // Form ditutup → tutup picker dan beri sinyal reload ke halaman asal.
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Tambah Data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Text('Pilih kategori perangkat terlebih dahulu:',
              style: TextStyle(color: c.textMuted, fontSize: 14)),
          const SizedBox(height: 16),
          _card(
            context,
            icon: Icons.computer,
            title: 'Computer',
            subtitle: 'PC desktop dengan spesifikasi lengkap\n'
                '(Processor, Motherboard, RAM, Storage, OS)',
            color: c.blue,
            onTap: () => _pick('Computer'),
          ),
          const SizedBox(height: 14),
          _card(
            context,
            icon: Icons.laptop_mac,
            title: 'Laptop',
            subtitle: 'Laptop / notebook dengan spesifikasi lengkap\n'
                '(Processor, Motherboard, RAM, Storage, OS)',
            color: c.accent,
            onTap: () => _pick('Laptop'),
          ),
          const SizedBox(height: 14),
          _card(
            context,
            icon: Icons.print,
            title: 'Printer',
            subtitle: 'Mesin cetak — form khusus detail printer\n'
                '(Tipe/Model, Koneksi)',
            color: const Color(0xFFF59E0B),
            onTap: () => _pick('Printer'),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required VoidCallback onTap}) {
    final c = context.appColors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      child: Clickable(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: TextStyle(
                              color: c.textMuted,
                              fontSize: 12,
                              height: 1.35)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: c.textMuted, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}