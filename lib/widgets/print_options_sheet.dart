import 'package:flutter/material.dart';

import '../models/device.dart';
import '../pages/print_preview_page.dart';
import '../theme/app_theme.dart';
import '../utils/field_groups.dart';
import 'barcode_download_dialog.dart';
import 'sticker_download_dialog.dart';

/// Lembar pilihan aksi "Cetak / Download" pada Halaman Detail perangkat.
///
/// Dua opsi yang dipisahkan secara tegas:
///   a) Download Barcode => unduh gambar barcode unik (stiker).
///   b) Preview & Download PDF => dokumen teks spesifikasi lengkap
///      (tanpa barcode).
class PrintOptionsSheet extends StatelessWidget {
  final Device device;
  const PrintOptionsSheet({super.key, required this.device});

  void _openBarcode(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => BarcodeDownloadDialog(device: device),
    );
  }

  void _openPdf(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PrintPreviewPage(device: device)),
    );
  }

  /// Printer memakai desain label 7,6 x 3,8 cm, kategori lain 15,5 x 6 cm.
  bool get _isPrinter => categoryKey(device.category) == 'Printer';

  void _openSticker(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => StickerDownloadDialog(device: device),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cetak / Download',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih dokumen yang ingin diunduh untuk perangkat ini.',
              style: TextStyle(color: c.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _option(
              context,
              icon: Icons.qr_code_2,
              color: c.blue,
              title: 'Download Barcode',
              subtitle:
                  'Barcode + QR berisi link PDF/PNG spesifikasi (Google Drive), '
                  'siap dicetak jadi stiker',
              onTap: () => _openBarcode(context),
            ),
            const SizedBox(height: 10),
            _option(
              context,
              icon: Icons.picture_as_pdf_outlined,
              color: c.dangerFg,
              title: 'Preview & Download PDF Spesifikasi',
              subtitle: 'Teks spesifikasi lengkap perangkat (tanpa barcode), format A4',
              onTap: () => _openPdf(context),
            ),
            const SizedBox(height: 10),
            _option(
              context,
              icon: Icons.sticky_note_2_outlined,
              color: c.blue,
              title: 'Download Stiker (Template)',
              subtitle: _isPrinter
                  ? 'Label printer (tanpa barcode & QR), format 7,6 x 3,8 cm'
                  : 'Stiker inventaris + spesifikasi perangkat '
                      '(tanpa barcode & QR), format 15,5 x 6 cm',
              onTap: () => _openSticker(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final c = context.appColors;
    return Material(
      color: c.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: c.textMuted,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: c.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
