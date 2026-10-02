import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/device.dart';
import '../services/detail_sheet_pdf_service.dart';
import '../services/public_saver_service.dart';
import '../theme/app_theme.dart';
import '../utils/field_groups.dart';

/// Preview & Download PDF "Spesifikasi Lengkap Perangkat".
///
/// Menampilkan dokumen A4 yang berisi teks spesifikasi perangkat secara
/// rapi **tanpa barcode** (sesuai aturan: PDF = murni teks/rincian data).
/// Barcode stiker diunduh terpisah melalui dialog "Download Barcode" pada
/// menu "Cetak / Download" di halaman detail.
class PrintPreviewPage extends StatefulWidget {
  final Device device;
  const PrintPreviewPage({super.key, required this.device});

  @override
  State<PrintPreviewPage> createState() => _PrintPreviewPageState();
}

class _PrintPreviewPageState extends State<PrintPreviewPage> {
  bool _busySave = false;
  bool _busyShare = false;
  Uint8List? _pdfCache;

  Device get _d => widget.device;
  String get safeKode =>
      _d.kodeInventaris.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  Future<Uint8List> _buildPdf() async {
    if (_pdfCache != null) return _pdfCache!;
    final bytes = await DetailSheetPdfService.instance.buildDetailSheet(_d);
    _pdfCache = bytes;
    return bytes;
  }

  Future<void> _savePdf() async {
    setState(() => _busySave = true);
    try {
      final bytes = await _buildPdf();
      final target = await PublicSaverService.instance
          .savePdfToDownloads(bytes, 'Detail_$safeKode.pdf');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'PDF berhasil diunduh ke ${target.location}: ${target.path}'),
        backgroundColor: const Color(0xFF166534),
      ));
    } catch (e) {
      _toast('Gagal mengunduh PDF: $e');
    } finally {
      if (mounted) setState(() => _busySave = false);
    }
  }

  Future<void> _sharePdf() async {
    setState(() => _busyShare = true);
    try {
      final bytes = await _buildPdf();
      final name = 'Detail_$safeKode.pdf';
      if (kIsWeb) {
        await PublicSaverService.instance.savePdfToDownloads(bytes, name);
      } else {
        await SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: name)],
          subject: 'Detail Perangkat $safeKode',
          text: 'Spesifikasi lengkap $safeKode — ${_d.deviceName}',
        ));
      }
    } catch (e) {
      _toast('Gagal membagikan PDF: $e');
    } finally {
      if (mounted) setState(() => _busyShare = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Preview & Download PDF'),
        actions: [
          IconButton(
            tooltip: 'Simpan PDF',
            onPressed: _busySave ? null : _savePdf,
            icon: _busySave
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download),
          ),
          IconButton(
            tooltip: 'Bagikan PDF',
            onPressed: _busyShare ? null : _sharePdf,
            icon: _busyShare
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Text(
              'Dokumen A4: teks spesifikasi lengkap (tanpa barcode)',
              style: TextStyle(color: c.textMuted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          _sheet(context),
          const SizedBox(height: 10),
          Text(
            'Catatan: barcode/QR stiker diunduh terpisah melalui menu '
            '"Cetak / Download" pada halaman detail. QR stiker mengarah ke '
            'dokumen PDF spesifikasi perangkat ini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textMuted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  /// Lembar "kertas" preview — setia dengan tata letak hasil PDF.
  ///
  /// Menggunakan warna "kertas putih" tetap agar kontras terjaga di tema
  /// gelap maupun terang (teks gelap di atas latar terang).
  Widget _sheet(BuildContext context) {
    final c = context.appColors;
    final fields = <(String, String)>[
      ('Kode Inventaris', _d.kodeInventaris),
      ('Device Name', _d.deviceName),
      ('Tanggal Evaluasi', _d.tanggalEvaluasi),
      ('PLAN', _d.plan),
      ('Bagian', _d.bagian),
      ('Category', categoryKey(_d.category)),
      (labelFor('prosesor', _d.category), _d.prosesor),
      (labelFor('motherboard', _d.category), _d.motherboard),
      if (showSpecField('ram', _d.category))
        (labelFor('ram', _d.category), _d.ram),
      if (showSpecField('storage', _d.category))
        (labelFor('storage', _d.category), _d.storage),
      if (showSpecField('osWindows', _d.category))
        (labelFor('osWindows', _d.category), _d.osWindows),
      if (showSpecField('goal', _d.category))
        (labelFor('goal', _d.category), _d.goal),
      (labelFor('statusUpgrade', _d.category), _d.statusUpgrade),
      (labelFor('perluUpgradeGanti', _d.category), _d.perluUpgradeGanti),
      (labelFor('perluUpgradeRepair', _d.category), _d.perluUpgradeRepair),
      ('Keterangan', _d.keterangan),
      ('Status Stiker', _d.statusStiker),
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
              color: Color(0x22000000),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.heroGrad1, c.heroGrad2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('INVENTARIS PERANGKAT',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(_d.kodeInventaris,
                    style: TextStyle(
                        color: c.heroKode,
                        fontSize: 26,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(_d.deviceName.trim().isEmpty ? 'Tanpa nama' : _d.deviceName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _identRow(context,
                    ['BAGIAN', display(_d.bagian)],
                    ['PLAN', display(_d.plan)],
                    ['CATEGORY', categoryKey(_d.category)]),
                const SizedBox(height: 8),
                _identRow(context,
                    ['TANGGAL EVALUASI', display(_d.tanggalEvaluasi)],
                    ['STATUS STIKER', display(_d.statusStiker)],
                    [
                      categoryKey(_d.category) == 'Printer'
                          ? 'STATUS PERBAIKAN'
                          : 'STATUS UPGRADE',
                      display(_d.statusUpgrade)
                    ]),
                const SizedBox(height: 16),
                Text(
                    categoryKey(_d.category) == 'Printer'
                        ? 'DETAIL PRINTER'
                        : 'DETAIL SPESIFIKASI',
                    style: TextStyle(
                        color: const Color(0xFF475569),
                        fontSize: 12,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      for (final (k, v) in fields)
                        _row(context, k, v),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 13, color: const Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Dokumen ini hanya memuat teks spesifikasi. Unduh '
                        'barcode stiker melalui menu Cetak / Download.',
                        style: TextStyle(
                            color: const Color(0xFF475569), fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _identRow(
      BuildContext context, List<String> a, List<String> b, List<String> c3) {
    Widget box(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 9,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );

    return Row(
      children: [
        box(a[0], a[1]),
        const SizedBox(width: 8),
        box(b[0], b[1]),
        const SizedBox(width: 8),
        box(c3[0], c3[1]),
      ],
    );
  }

  Widget _row(BuildContext context, String k, String v) {
    final empty = v.trim().isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(k,
                style: const TextStyle(
                    color: Color(0xFF475569), fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              empty ? belumDiInput : v.trim(),
              style: TextStyle(
                  color: empty ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                  fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                  fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}