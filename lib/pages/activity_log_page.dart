import 'package:flutter/material.dart';

import '../database/db_helper.dart';
import '../models/activity_log.dart';
import '../theme/app_theme.dart';
import '../widgets/clickable.dart';

/// Halaman riwayat aktivitas (audit trail): tahu siapa/waktu apa yang
/// ditambah, diubah, atau dihapus — plus kejadian lain (ganti PIN, impor,
/// reseed). Data dibaca dari SQLite lokal (selalu lengkap untuk perangkat ini).
class ActivityLogPage extends StatefulWidget {
  const ActivityLogPage({super.key});

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  List<ActivityLog> _logs = [];
  bool _loading = true;

  /// Pencocokan aksi → ikon & warna (tema terang & gelap).
  static (IconData, Color) _ikonAksi(BuildContext context, String action) {
    final c = context.appColors;
    return switch (action) {
      'tambah' => (Icons.add_circle, c.accent),
      'ubah' => (Icons.edit, c.blue),
      'hapus' => (Icons.delete, c.danger),
      'pin' => (Icons.lock_outline, c.accent),
      'import' => (Icons.upload_file, c.blue),
      'reset' => (Icons.restart_alt, c.accent),
      _ => (Icons.circle_outlined, c.textMuted),
    };
  }

  static const _labelAksi = {
    'tambah': 'Ditambahkan',
    'ubah': 'Diubah',
    'hapus': 'Dihapus',
    'pin': 'Keamanan',
    'import': 'Impor Excel',
    'reset': 'Reset Dari Excel',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await DbHelper.instance.getActivityLog();
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    final c = context.appColors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Riwayat', style: TextStyle(fontSize: 17)),
        content: Text(
          'Hapus seluruh riwayat aktivitas?',
          style: TextStyle(color: c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await DbHelper.instance.clearActivityLog();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Riwayat Aktivitas'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          if (_logs.isNotEmpty)
            IconButton(
              tooltip: 'Hapus riwayat',
              icon: const Icon(Icons.delete_outline),
              onPressed: _clear,
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.accent))
          : _logs.isEmpty
              ? _emptyState(context)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _logs.length,
                  separatorBuilder: (_, _) => Divider(
                      height: 1, color: c.border, indent: 16, endIndent: 16),
                  itemBuilder: (context, i) => _logTile(context, _logs[i]),
                ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final c = context.appColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 52, color: c.emptyIcon),
          const SizedBox(height: 10),
          Text('Belum ada riwayat aktivitas',
              style: TextStyle(color: c.textMuted)),
        ],
      ),
    );
  }

  Widget _logTile(BuildContext context, ActivityLog log) {
    final c = context.appColors;
    final (icon, color) = _ikonAksi(context, log.action);
    final label = _labelAksi[log.action] ?? log.action;
    final waktu = _waktu(log.createdAt);

    final judul = log.kode.trim().isEmpty || log.kode == '-'
        ? log.deviceName
        : '${log.kode} — ${log.deviceName}';
    final sub = [label, waktu].join(' · ');

    return Clickable(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(judul,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.textPrimary, fontSize: 14)),
        subtitle: Text(
          sub,
          style: TextStyle(
              color: c.blue, fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
        isThreeLine: log.detail.isNotEmpty,
        trailing: log.detail.isNotEmpty
            ? Icon(Icons.chevron_right, color: c.textMuted, size: 18)
            : null,
        onTap: log.detail.isEmpty
            ? null
            : () => _showDetail(log, judul),
      ),
    );
  }

  void _showDetail(ActivityLog log, String judul) {
    final c = context.appColors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(judul, style: const TextStyle(fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_labelAksi[log.action] ?? log.action,
                style: TextStyle(color: c.blue, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(_waktu(log.createdAt),
                style: TextStyle(color: c.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            Text(log.detail, style: TextStyle(color: c.textPrimary)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  /// Tanggal + jam lokal manusiawi dari stempel ISO (tanggal_ ISO tetap utuh).
  static String _waktu(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    final jam = '${p2(local.hour)}:${p2(local.minute)}';
    return '${_hariIni(local)} · $jam';
  }

  static String _hariIni(DateTime local) {
    final now = DateTime.now();
    final tgl = '${p2(local.day)}/${p2(local.month)}/${local.year}';
    final sama = local.year == now.year && local.month == now.month && local.day == now.day;
    final kemarin = now.subtract(const Duration(days: 1));
    final kSem = kemarin.year == local.year &&
        kemarin.month == local.month &&
        kemarin.day == local.day;
    if (sama) return 'Hari ini';
    if (kSem) return 'Kemarin';
    return tgl;
  }

  static String p2(int n) => n.toString().padLeft(2, '0');
}