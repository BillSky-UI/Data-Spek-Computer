import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/device.dart';
import '../utils/field_groups.dart';
import 'public_saver_service.dart';

/// Satu kolom pada tabel laporan PDF.
class _PdfCol {
  const _PdfCol(this.label, this.width, this.value);
  final String label;
  final double width; // dalam mm
  final String Function(Device) value;
}

/// Generator laporan resmi PDF "Laporan Inventaris Perangkat" ber-kop
/// perusahaan, format landscape A4, tabel per kategori (Computer/Laptop/
/// Printer) — untuk arsip/lampiran. Mirip struktur kop pada ekspor Excel,
/// disusun lewat [pw.MultiPage] agar tabel panjang otomatis membalik halaman.
class ReportPdfService {
  ReportPdfService._();
  static final ReportPdfService instance = ReportPdfService._();

  static const String company = 'PT. DWI PRIMA REZEKY - IT';

  /// Susun kolom laporan untuk kategori tertentu. Field yang tidak diinput
  /// kategori tersebut (mis. RAM/Storage untuk Printer) tidak ikut dicetak.
  static List<_PdfCol> _columnsFor(String category) {
    final isPrinter = categoryKey(category) == 'Printer';
    return [
      _PdfCol('Kode', 20, (d) => d.kodeInventaris),
      _PdfCol('Tgl. Evaluasi', 17, (d) => d.tanggalEvaluasi),
      _PdfCol('PLAN', 14, (d) => d.plan),
      _PdfCol('Bagian', 22, (d) => d.bagian),
      _PdfCol('Device Name', 29, (d) => d.deviceName),
      if (!isPrinter) _PdfCol('RAM', 15, (d) => d.ram),
      if (!isPrinter) _PdfCol('Storage', 20, (d) => d.storage),
      _PdfCol(isPrinter ? 'Tipe/Model' : 'Prosesor', 34, (d) => d.prosesor),
      if (!isPrinter) _PdfCol('OS Windows', 26, (d) => d.osWindows),
      _PdfCol(
          isPrinter ? 'Status Perbaikan' : 'Status Upgrade',
          18,
          (d) => d.statusUpgrade),
      _PdfCol('Stiker', 13, (d) => d.statusStiker),
      _PdfCol('Keterangan', 30, (d) => d.keterangan),
    ];
  }

  Future<Uint8List> buildReport(
    List<Device> devices, {
    String? subtitle,
  }) async {
    final m = PdfPageFormat.mm;
    final grouped = {
      for (final k in const ['Computer', 'Laptop', 'Printer']) k: <Device>[],
    };
    for (final d in devices) {
      grouped[categoryKey(d.category)]?.add(d);
    }
    final periode = 'Tahun ${DateTime.now().year}';

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.fromLTRB(10 * m, 10 * m, 10 * m, 14 * m),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Dokumen dibuat dari aplikasi $company',
              style: pw.TextStyle(
                  fontSize: 4.5 * m, color: PdfColors.grey500),
            ),
            pw.Text(
              'Halaman ${ctx.pageNumber}/${ctx.pagesCount}',
              style: pw.TextStyle(
                  fontSize: 4.5 * m, color: PdfColors.grey500),
            ),
          ],
        ),
        build: (ctx) => [
          _header(periode, subtitle, m),
          pw.SizedBox(height: 4 * m),
          _summary(grouped, devices.length, m),
          pw.SizedBox(height: 6 * m),
          for (final (i, category) in const ['Computer', 'Laptop', 'Printer']
              .indexed)
            if ((grouped[category] ?? []).isNotEmpty) ...[
              _sectionTitle(category, (grouped[category]!).length,
                  '${String.fromCharCode(65 + i)}.', m),
              pw.SizedBox(height: 2.5 * m),
              _table(category, grouped[category]!),
              pw.SizedBox(height: 6 * m),
            ],
          if (devices.isEmpty)
            pw.Text('Tidak ada data perangkat untuk laporan ini.',
                style: pw.TextStyle(fontSize: 5 * m, color: PdfColors.grey600)),
          pw.SizedBox(height: 10 * m),
          _signature(m: m),
        ],
      ),
    );

    return doc.save();
  }

  /// Kop laporan: perusahaan + judul dokumen + periode.
  pw.Widget _header(String periode, String? subtitle, double m) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(company,
            style: pw.TextStyle(
                fontSize: 10 * m,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
                letterSpacing: 0.6)),
        pw.SizedBox(height: 1.5 * m),
        pw.Text('LAPORAN INVENTARIS PERANGKAT',
            style: pw.TextStyle(
                fontSize: 14 * m,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900)),
        if (subtitle != null && subtitle.trim().isNotEmpty) ...[
          pw.SizedBox(height: 1.5 * m),
          pw.Text(subtitle.trim(),
              style: pw.TextStyle(
                  fontSize: 6 * m, color: PdfColors.grey700)),
        ],
        pw.SizedBox(height: 1.5 * m),
        pw.Text('Periode evaluasi: $periode',
            style: pw.TextStyle(
                fontSize: 6 * m, color: PdfColors.grey600)),
        pw.SizedBox(height: 3 * m),
        pw.Container(height: 0.6 * m, color: PdfColors.blue800),
      ],
    );
  }

  /// Ringkasan jumlah per kategori di bawah kop.
  pw.Widget _summary(Map<String, List<Device>> grouped, int total, double m) {
    return pw.Row(
      children: [
        for (final (i, category) in ['Computer', 'Laptop', 'Printer'].indexed) ...[
          if (i > 0) pw.SizedBox(width: 4 * m),
          pw.Expanded(
            child: pw.Container(
              padding: pw.EdgeInsets.all(3 * m),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey50,
                borderRadius: pw.BorderRadius.circular(2.5 * m),
                border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(category.toUpperCase(),
                      style: pw.TextStyle(
                          fontSize: 4.5 * m,
                          color: PdfColors.blueGrey600,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.5)),
                  pw.SizedBox(height: 1 * m),
                  pw.Text('${grouped[category]?.length ?? 0} unit',
                      style: pw.TextStyle(
                          fontSize: 7 * m,
                          color: PdfColors.grey900,
                          fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
        pw.SizedBox(width: 4 * m),
        pw.Expanded(
          child: pw.Container(
            padding: pw.EdgeInsets.all(3 * m),
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [PdfColors.blue800, PdfColors.blue600],
                begin: pw.Alignment.topLeft,
                end: pw.Alignment.bottomRight,
              ),
              borderRadius: pw.BorderRadius.circular(2.5 * m),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('TOTAL',
                    style: pw.TextStyle(
                        fontSize: 4.5 * m,
                        color: PdfColors.blue100,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.5)),
                pw.SizedBox(height: 1 * m),
                pw.Text('$total unit',
                    style: pw.TextStyle(
                        fontSize: 7 * m,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _sectionTitle(
      String category, int count, String prefix, double m) {
    final label = switch (category) {
      'Printer' => 'PRINTER ($count unit)',
      'Laptop' => 'LAPTOP ($count unit)',
      _ => 'KOMPUTER ($count unit)',
    };
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.symmetric(vertical: 2.4 * m, horizontal: 3.5 * m),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(2 * m),
      ),
      child: pw.Text('$prefix  $label',
          style: pw.TextStyle(
              fontSize: 6.5 * m,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
              letterSpacing: 0.8)),
    );
  }

  /// Tabel data satu kategori. Baris header ditandai `repeat: true` sehingga
  /// tercetak ulang otomatis saat tabel berlanjut ke halaman berikutnya.
  pw.Widget _table(String category, List<Device> devices) {
    final m = PdfPageFormat.mm;
    final cols = _columnsFor(category);

    pw.Widget cell(String text) => pw.Container(
          padding:
              pw.EdgeInsets.symmetric(horizontal: 1.8 * m, vertical: 1.4 * m),
          child: pw.Text(
            text.trim().isEmpty ? '-' : text.trim(),
            style: pw.TextStyle(fontSize: 4.2 * m, height: 1.25),
            maxLines: 3,
            overflow: pw.TextOverflow.clip,
          ),
        );

    pw.Widget headerCell(String text) => pw.Container(
          padding:
              pw.EdgeInsets.symmetric(horizontal: 1.8 * m, vertical: 1.8 * m),
          color: PdfColors.blue800,
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 4.6 * m,
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold)),
        );

    return pw.Table(
      columnWidths: {
        for (final (i, c) in cols.indexed) i: pw.FixedColumnWidth(c.width * m),
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: PdfColors.blue800),
          children: [for (final c in cols) headerCell(c.label)],
        ),
        for (final (i, d) in devices.indexed)
          pw.TableRow(
            decoration:
                i.isEven ? null : pw.BoxDecoration(color: PdfColors.grey50),
            children: [for (final c in cols) cell(c.value(d))],
          ),
      ],
    );
  }

  /// Blok tanda tangan di akhir laporan (posisi kanan).
  pw.Widget _signature({required double m}) {
    final sekarang = DateTime.now();
    final tanggal =
        '${_p2(sekarang.day)} ${_bulan(sekarang.month)} ${sekarang.year}';
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Jakarta, $tanggal',
              style: pw.TextStyle(fontSize: 5 * m, color: PdfColors.grey600)),
          pw.SizedBox(height: 1 * m),
          pw.Text('Disusun oleh:',
              style: pw.TextStyle(fontSize: 5 * m, color: PdfColors.grey600)),
          pw.SizedBox(height: 22 * m),
          pw.Text('Bagian IT',
              style: pw.TextStyle(
                  fontSize: 5.5 * m,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900)),
          pw.SizedBox(height: 1.5 * m),
          pw.Text('(........................................)',
              style: pw.TextStyle(fontSize: 5 * m, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static String _p2(int n) => n.toString().padLeft(2, '0');

  static String _bulan(int month) => const [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
      ][month - 1];

  /// Simpan PDF ke folder Download publik HP (atau unduhan browser di web).
  Future<SavedTarget> saveToDownloads(Uint8List bytes, String name) =>
      PublicSaverService.instance.savePdfToDownloads(bytes, name);
}