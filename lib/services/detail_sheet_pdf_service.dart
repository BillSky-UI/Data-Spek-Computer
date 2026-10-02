import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';

import '../models/device.dart';
import '../utils/field_groups.dart';

/// Generator dokumen PDF "Spesifikasi Lengkap Perangkat".
///
/// Menggunakan [pw.MultiPage] sehingga seluruh data spesifikasi dirender
/// **lengkap dari atas sampai bawah** dan otomatis membalik ke halaman
/// berikutnya bila teksnya panjang (tidak ada data yang terpotong).
/// PDF ini murni berisi teks/rincian data — **tanpa barcode**. Barcode stiker
/// diunduh terpisah melalui dialog "Download Barcode" pada menu Cetak/Download.
class DetailSheetPdfService {
  DetailSheetPdfService._();
  static final DetailSheetPdfService instance = DetailSheetPdfService._();

  Future<Uint8List> buildDetailSheet(Device d) async {
    final m = PdfPageFormat.mm;
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.fromLTRB(12 * m, 14 * m, 12 * m, 16 * m),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: pw.EdgeInsets.only(top: 4 * m),
          child: pw.Text(
            'Halaman ${ctx.pageNumber}/${ctx.pagesCount}',
            style: pw.TextStyle(
                fontSize: 5 * m, color: PdfColors.grey500),
          ),
        ),
        build: (ctx) {
          final widgets = <pw.Widget>[
            _header(d, m),
            pw.SizedBox(height: 5 * m),
            _identity(d, m),
            pw.SizedBox(height: 6 * m),
            _sectionTitle(
                categoryKey(d.category) == 'Printer'
                    ? 'DETAIL PRINTER'
                    : 'DETAIL SPESIFIKASI',
                m),
            pw.SizedBox(height: 3 * m),
            // Setiap baris spec berdiri sendiri di alur MultiPage agar
            // bisa pindah ke halaman berikutnya satu per satu (anti terpotong).
            for (final (k, v) in _specRows(d)) ...[
              _specRow(k, v, m),
              pw.SizedBox(height: 1.6 * m),
            ],
            pw.SizedBox(height: 6 * m),
            _footer(d, m),
          ];
          return widgets;
        },
      ),
    );

    return doc.save();
  }

  /// Seluruh atribut perangkat, urut dari atas sampai bawah tanpa ada yang
  /// tertinggal.
  List<(String, String)> _specRows(Device d) => [
        ('Kode Inventaris', d.kodeInventaris),
        ('Device Name', d.deviceName),
        ('Tanggal Evaluasi', d.tanggalEvaluasi),
        ('PLAN', d.plan),
        ('Bagian', d.bagian),
        ('Category', categoryKey(d.category)),
        (labelFor('prosesor', d.category), d.prosesor),
        (labelFor('motherboard', d.category), d.motherboard),
        if (showSpecField('ram', d.category))
          (labelFor('ram', d.category), d.ram),
        if (showSpecField('storage', d.category))
          (labelFor('storage', d.category), d.storage),
        if (showSpecField('osWindows', d.category))
          (labelFor('osWindows', d.category), d.osWindows),
        if (showSpecField('goal', d.category)) (labelFor('goal', d.category), d.goal),
        (labelFor('statusUpgrade', d.category), d.statusUpgrade),
        (labelFor('perluUpgradeGanti', d.category), d.perluUpgradeGanti),
        (labelFor('perluUpgradeRepair', d.category), d.perluUpgradeRepair),
        ('Keterangan', d.keterangan),
        ('Status Stiker', d.statusStiker),
      ];

  pw.Widget _header(Device d, double m) {
    return pw.Container(
      padding: pw.EdgeInsets.fromLTRB(6 * m, 5.5 * m, 6 * m, 5.5 * m),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [PdfColors.blue800, PdfColors.blue600],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.circular(3.5 * m),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('INVENTARIS PERANGKAT',
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 5.5 * m,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2)),
          pw.SizedBox(height: 2 * m),
          pw.Text(d.kodeInventaris,
              style: pw.TextStyle(
                  color: PdfColors.amber100,
                  fontSize: 14 * m,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.5)),
          pw.SizedBox(height: 1.5 * m),
          pw.Text(
            d.deviceName.trim().isEmpty ? 'Tanpa nama' : d.deviceName,
            style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 9 * m,
                fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _identity(Device d, double m) {
    return pw.Column(
      children: [
        pw.Row(
          children: [
            _identBox('BAGIAN', d.bagian, m),
            pw.SizedBox(width: 3 * m),
            _identBox('PLAN', d.plan, m),
            pw.SizedBox(width: 3 * m),
            _identBox('CATEGORY', categoryKey(d.category), m),
          ],
        ),
        pw.SizedBox(height: 3 * m),
        pw.Row(
          children: [
            _identBox('TANGGAL EVALUASI', d.tanggalEvaluasi, m),
            pw.SizedBox(width: 3 * m),
            _identBox('STATUS STIKER', d.statusStiker, m),
            pw.SizedBox(width: 3 * m),
            _identBox('STATUS UPGRADE', d.statusUpgrade, m),
          ],
        ),
      ],
    );
  }

  pw.Widget _identBox(String label, String value, double m) {
    final v = value.trim().isEmpty ? '-' : value.trim();
    return pw.Expanded(
      child: pw.Container(
        padding: pw.EdgeInsets.all(2.5 * m),
        decoration: pw.BoxDecoration(
          color: PdfColors.blueGrey50,
          borderRadius: pw.BorderRadius.circular(2.5 * m),
          border: pw.Border.all(color: PdfColors.blueGrey300, width: 0.4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 4.5 * m,
                    color: PdfColors.blueGrey600,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.4)),
            pw.SizedBox(height: 0.8 * m),
            pw.Text(v,
                style: pw.TextStyle(
                    fontSize: 6.5 * m,
                    color: PdfColors.grey900,
                    fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  pw.Widget _sectionTitle(String title, double m) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.symmetric(vertical: 2.2 * m, horizontal: 3.5 * m),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(2 * m),
      ),
      child: pw.Text(title,
          style: pw.TextStyle(
              fontSize: 6.5 * m,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
              letterSpacing: 0.8)),
    );
  }

  pw.Widget _specRow(String k, String v, double m) {
    final value = v.trim().isEmpty ? belumDiInput : v.trim();
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(vertical: 2.4 * m, horizontal: 3.5 * m),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
        borderRadius: pw.BorderRadius.circular(2 * m),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 46 * m,
            child: pw.Text(k,
                style: pw.TextStyle(
                    fontSize: 6.5 * m,
                    color: PdfColors.grey600,
                    fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(width: 2 * m),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 6.5 * m,
                    color: value == belumDiInput
                        ? PdfColors.grey400
                        : PdfColors.grey900,
                    height: 1.3)),
          ),
        ],
      ),
    );
  }

  pw.Widget _footer(Device d, double m) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 2 * m,
          height: 2 * m,
          margin: pw.EdgeInsets.only(top: 1 * m),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey500,
            shape: pw.BoxShape.circle,
          ),
        ),
        pw.SizedBox(width: 2 * m),
        pw.Expanded(
          child: pw.Text(
            'Dokumen ini memuat teks spesifikasi lengkap. Barcode/QR stiker '
            'diunduh terpisah melalui menu Cetak / Download pada aplikasi '
            '(${d.kodeInventaris}).',
            style: pw.TextStyle(
                fontSize: 5 * m,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic,
                height: 1.3),
          ),
        ),
      ],
    );
  }

  /// Simpan PDF ke direktori Download (fallback dokumen aplikasi).
  Future<File> saveToDownloads(Uint8List bytes, String name) async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final dir = Directory('${ext.path}/Download');
        if (!await dir.exists()) await dir.create(recursive: true);
        final file = File('${dir.path}/$name');
        await file.writeAsBytes(bytes, flush: true);
        return file;
      }
    }
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}