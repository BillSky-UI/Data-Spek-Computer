import 'package:flutter/material.dart';

import '../app_info.dart';
import '../database/db_helper.dart';
import '../pages/settings_page.dart';
import '../services/export_service.dart';
import '../services/settings_controller.dart';
import 'clickable.dart';

/// Ikon titik tiga (…) pada AppBar untuk Pengaturan, Export & Tentang.
class AppPopupMenu extends StatelessWidget {
  final SettingsController settings;
  const AppPopupMenu({super.key, required this.settings});

  Future<void> _exportToExcel(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Munculkan indikator singkat agar user tahu proses berjalan.
      messenger.showSnackBar(const SnackBar(
          content: Text('Mengekspor ke Excel (Computer/Laptop/Printer)...'),
          duration: Duration(seconds: 1)));
      final devices = await DbHelper.instance.getAll();
      final saved = await ExportService.instance.saveExcelToDownloads(devices);
      messenger.showSnackBar(
          SnackBar(content: Text('Tersimpan di ${saved.location}: ${saved.path}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal ekspor: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Clickable(
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
        switch (value) {
          case 'settings':
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => SettingsPage(settings: settings)),
            );
          case 'export':
            _exportToExcel(context);
          case 'about':
            _showAbout(context);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'settings', child: Text('Pengaturan')),
        PopupMenuItem(value: 'export', child: Text('Export to Excel')),
        PopupMenuItem(value: 'about', child: Text('Tentang Aplikasi')),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tentang Aplikasi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppInfo.name),
            const SizedBox(height: 6),
            Text(
              'Versi ${AppInfo.versionLabel}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Manajemen inventaris spesifikasi komputer. Data dimuat otomatis dari file Excel pada peluncuran pertama.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup')),
        ],
      ),
    );
  }
}