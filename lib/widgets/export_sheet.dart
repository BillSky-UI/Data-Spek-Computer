import 'package:flutter/material.dart';

import '../models/device.dart';
import '../services/export_service.dart';
import '../services/report_pdf_service.dart';
import '../services/saved_target.dart';
import '../theme/app_theme.dart';
import 'clickable.dart';

/// Lembar pilihan "Ekspor hasil (per-filter/dashboard)" ke tiga format:
/// Excel (.xlsx), CSV (.csv), atau Laporan PDF resmi ber-kop perusahaan.
///
/// Berjalan setelah sheet ditutup; hasil akhir ditampilkan lewat SnackBar
/// (lokasi file tersimpan), mengikuti pola unduhan di aplikasi lain.
Future<void> showExportSheet(
  BuildContext context, {
  required List<Device> devices,
  required String title,
  required String subtitle,
  String filePrefix = 'Spek_Inventaris_DPR',
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final kind = await showModalBottomSheet<String>(
    context: context,
    builder: (_) => _ExportSheet(
      title: title,
      subtitle: subtitle,
      count: devices.length,
    ),
  );
  if (kind == null) return;
  await _runExport(messenger, devices, kind, filePrefix, subtitle);
}

Future<void> _runExport(
  ScaffoldMessengerState messenger,
  List<Device> devices,
  String kind,
  String prefix,
  String subtitle,
) async {
  messenger.showSnackBar(
    SnackBar(
      content: Text('Mengekspor ${devices.length} perangkat sebagai ${_label(kind)}...'),
      duration: const Duration(seconds: 1),
    ),
  );
  try {
    final saved = switch (kind) {
      'xlsx' => await ExportService.instance.saveExcelToDownloads(
          devices,
          prefix: prefix,
        ),
      'csv' => await ExportService.instance
          .saveCsvToDownloads(devices, prefix: prefix),
      _ => await _saveReportPdf(devices, prefix, subtitle),
    };
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Tersimpan di ${saved.location}: ${saved.path}'),
        ),
      );
  } catch (e) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Ekspor gagal: $e'),
          backgroundColor: messenger.context.appColors.danger,
        ),
      );
  }
}

Future<SavedTarget> _saveReportPdf(
    List<Device> devices, String prefix, String subtitle) async {
  final bytes = await ReportPdfService.instance.buildReport(
    devices,
    subtitle: subtitle,
  );
  final name = '${_timestamp()}_Laporan_Inventaris.pdf';
  return ReportPdfService.instance.saveToDownloads(bytes, name);
}

String _label(String kind) => switch (kind) {
      'xlsx' => 'Excel',
      'csv' => 'CSV',
      _ => 'laporan PDF',
    };

String _timestamp() {
  final t = DateTime.now();
  String p(int n) => n.toString().padLeft(2, '0');
  return '${t.year}${p(t.month)}${p(t.day)}_${p(t.hour)}${p(t.minute)}';
}

class _ExportSheet extends StatelessWidget {
  const _ExportSheet({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final String title;
  final String subtitle;
  final int count;

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
              title,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count perangkat — $subtitle',
              style: TextStyle(color: c.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _option(
              context,
              icon: Icons.grid_on,
              color: const Color(0xFF1D6B42),
              title: 'Export Excel (.xlsx)',
              subtitle: 'Berkolom kesepakatan + kop PT. DWI PRIMA REZEKY - IT, '
                  'multi-sheet per kategori',
              onTap: () => Navigator.pop(context, 'xlsx'),
            ),
            const SizedBox(height: 10),
            _option(
              context,
              icon: Icons.table_rows_outlined,
              color: c.blue,
              title: 'Export CSV (.csv)',
              subtitle: 'Comma-separated, bisa dibuka di Excel/Spreadsheet',
              onTap: () => Navigator.pop(context, 'csv'),
            ),
            const SizedBox(height: 10),
            _option(
              context,
              icon: Icons.picture_as_pdf_outlined,
              color: c.dangerFg,
              title: 'Laporan PDF Resmi',
              subtitle: 'Kop perusahaan, ringkasan total, tabel per kategori, '
                  'tanda tangan — format A4 landscape',
              onTap: () => Navigator.pop(context, 'pdf'),
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
      child: Clickable(
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
      ),
    );
  }
}