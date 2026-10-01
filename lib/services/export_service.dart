import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/foundation.dart' show compute;

import '../models/device.dart';
import '../utils/field_groups.dart';
import 'public_saver_service.dart';

/// Export data inventaris ke Excel multi-sheet dengan kop perusahaan.
///
/// Mengikuti format tata letak master
/// `assets/arsip_spesifikasi_komputer_pc_internal.xlsx`:
/// kop "PT. DWI PRIMA REZEKY - IT", judul laporan "Quality of Devices (…)",
/// periode "Tahun YYYY", lalu tabel dua-baris header (kelompok
/// "Spesifikasi Saat Ini" & "Perlu Upgrade") dan baris data.
class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  /// Nama perusahaan / lembaga pada kop.
  static const String _company = 'PT. DWI PRIMA REZEKY - IT';

  /// Urutan sheet = kategori tab di aplikasi.
  static const _sheetOrder = ['Computer', 'Laptop', 'Printer'];

  /// Tampilan judul laporan per kategori, sesuai pola master.
  static String _titleFor(String category) =>
      'Quality of Devices ($category)';

  /// Header tabel (baris 1) — mengikuti master + kolom "Status Stiker"
  /// yang ditambahkan di akhir.
  static const _groupHeaders = {
    1: 'Tanggal Evaluasi',
    2: 'Kode Inventaris',
    3: 'PLAN',
    4: 'Bagian',
    5: 'Device Name',
    6: 'Category',
    7: 'Spesifikasi Saat Ini',
    12: 'Goal',
    13: 'Perlu Upgrade',
    15: 'Status Upgrade',
    16: 'Keterangan',
    17: 'Status Stiker',
  };

  /// Sub-header (baris 2) untuk kolom yang punya kelompok di atasnya.
  static const _subHeaders = {
    7: 'Processor',
    8: 'Motherboard',
    9: 'RAM',
    10: 'Storage',
    11: 'OS Windows',
    13: 'Ganti',
    14: 'Repair',
  };

  /// Kolom tunggal pada header dua baris (di-merge vertikal row1:row2).
  static const _singleCols = [1, 2, 3, 4, 5, 6, 12, 15, 16, 17];

  static const String _mimeXlsx =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  static const _headers = [
    'Tanggal Evaluasi',
    'Kode Inventaris',
    'PLAN',
    'Bagian',
    'Device Name',
    'Category',
    'Spesifikasi Saat Ini - Processor',
    'Spesifikasi Saat Ini - Motherboard',
    'Spesifikasi Saat Ini - RAM',
    'Spesifikasi Saat Ini - Storage',
    'Spesifikasi Saat Ini - OS Windows',
    'Goal',
    'Perlu Upgrade - Ganti',
    'Perlu Upgrade - Repair',
    'Status Upgrade',
    'Keterangan',
    'Status Stiker',
  ];

  static List<String> _values(Device d) => [
        d.tanggalEvaluasi,
        d.kodeInventaris,
        d.plan,
        d.bagian,
        d.deviceName,
        categoryKey(d.category),
        d.prosesor,
        d.motherboard,
        d.ram,
        d.storage,
        d.osWindows,
        d.goal,
        d.perluUpgradeGanti,
        d.perluUpgradeRepair,
        d.statusUpgrade,
        d.keterangan,
        d.statusStiker,
      ];

  /// Kelompokkan perangkat ke sheet sesuai kategori.
  static Map<String, List<Device>> _groupBy(List<Device> devices) {
    final map = <String, List<Device>>{
      for (final s in _sheetOrder) s: <Device>[],
    };
    for (final d in devices) {
      map[categoryKey(d.category)]?.add(d);
    }
    return map;
  }

  Future<SavedTarget> saveExcelToDownloads(List<Device> devices) async {
    final bytes = await buildExcelBytesAsync(devices);
    final name = 'Spek_Inventaris_DPR_${_timestamp()}.xlsx';
    return PublicSaverService.instance.saveFileToDownloads(
      bytes,
      name,
      _mimeXlsx,
    );
  }

  /// Simpan file .csv ke folder Download publik HP (MediaStore).
  Future<SavedTarget> saveCsvToDownloads(List<Device> devices) async {
    final bytes = await compute(_buildCsv, devices);
    final name = 'Spek_Inventaris_DPR_${_timestamp()}.csv';
    return PublicSaverService.instance.saveFileToDownloads(
        bytes, name, 'text/csv');
  }

  /// Versi async [buildExcelBytes] yang jalan di isolate latar.
  ///
  /// Pembuatan .xlsx butuh ~0,7 detik untuk 1.000 baris dan ~3 detik untuk
  /// 5.000 baris. Kalau sinkron, UI thread akan membeku dan Android dapat
  /// menampilkan dialog "isn't responding".
  Future<Uint8List> buildExcelBytesAsync(List<Device> devices) =>
      compute(_buildExcel, devices);

  /// Bangun file `.xlsx` multi-sheet secara sinkron.
  ///
  /// Sheet Computer, Laptop, Printer — masing-masing dengan kop.
  /// Untuk pemakaian dari UI, prefer [buildExcelBytesAsync].
  Uint8List buildExcelBytes(List<Device> devices) => _buildExcel(devices);

  static Uint8List _buildExcel(List<Device> devices) {
    final excel = excel_pkg.Excel.createExcel();
    final grouped = _groupBy(devices);
    final periode = 'Tahun ${DateTime.now().year}';

    for (final category in _sheetOrder) {
      final sheet = excel[category];
      _buildSheet(sheet, category, periode, grouped[category] ?? const []);
    }

    final List<int>? bytes = excel.save();
    if (bytes == null) {
      throw Exception('Gagal membuat file Excel');
    }
    return Uint8List.fromList(bytes);
  }

  // ---------- Layout tiap sheet ----------

  static void _buildSheet(excel_pkg.Sheet sheet, String category, String periode,
      List<Device> devices) {
    final rows = _rowsFor(category, periode, devices);
    for (final row in rows) {
      sheet.appendRow(row.map((v) => v == null ? null : excel_pkg.TextCellValue(v)).toList());
    }
    _applyLayout(sheet);
  }

  /// Susun baris mentah (kop + header 2 baris + data). Nilai diisi sebagai
  /// string; null = kosong. Data dimulai dari kolom 1 (B) seperti master.
  static List<List<String?>> _rowsFor(
      String category, String periode, List<Device> devices) {
    final rows = <List<String?>>[
      List<String?>.filled(18, null), // R0 spacer
      [ // R1 judul + periode
        null, null, _titleFor(category), null, null, null, null, null,
        null, null, null, null, null, periode, null, null, null, null,
      ], // title col2, periode col13
      List<String?>.filled(18, null), // R2 spacer
      [ // R3 perusahaan
        null, _company, null, null, null, null, null, null, null,
        null, null, null, null, null, null, null, null, null,
      ],
      List<String?>.filled(18, null), // R4 spacer
      [ // R5 baris header utama
        null, null, null, null, null, null, null, null, null, null,
        null, null, null, null, null, null, null, null,
      ],
      List<String?>.filled(18, null), // R6 baris sub-header
    ];

    // Isi header utama (kolom 1..17).
    for (var col = 1; col <= 17; col++) {
      rows[5][col] = _groupHeaders[col];
      rows[6][col] = _subHeaders[col];
    }

    // Baris data mulai dari index 7.
    for (final d in devices) {
      rows.add([null, ..._values(d)]);
    }
    return rows;
  }

  static void _applyLayout(excel_pkg.Sheet sheet) {
    // Lebar kolom menyesuaikan isi.
    final widths = <int, double>{
      1: 13, 2: 12, 3: 8, 4: 16, 5: 18, 6: 10,
      7: 38, 8: 30, 9: 12, 10: 20, 11: 34,
      12: 10, 13: 12, 14: 10, 15: 12, 16: 22, 17: 11,
    };
    widths.forEach(sheet.setColumnWidth);

    // Merge kop.
    _merge(sheet, 2, 1, 12, 1); // judul laporan
    _merge(sheet, 13, 1, 17, 1); // periode
    _merge(sheet, 1, 3, 17, 3); // perusahaan
    // Merge kelompok header.
    _merge(sheet, 7, 5, 11, 5); // Spesifikasi Saat Ini
    _merge(sheet, 13, 5, 14, 5); // Perlu Upgrade
    // Header kolom tunggal merge vertikal row5:row6.
    for (final col in _singleCols) {
      _merge(sheet, col, 5, col, 6);
    }

    // Style.
    final headerFill = excel_pkg.ExcelColor.fromHexString('FF1F4E79');
    final white = excel_pkg.ExcelColor.fromHexString('FFFFFFFF');
    final bodyBorder = excel_pkg.Border(
      borderStyle: excel_pkg.BorderStyle.Thin,
      borderColorHex: excel_pkg.ExcelColor.fromHexString('FF8CA3C0'),
    );
    final dailyFill = excel_pkg.ExcelColor.fromHexString('FFF2F6FA');

    final titleStyle = excel_pkg.CellStyle(
      fontFamily: 'Calibri',
      bold: true,
      fontSize: 14,
      horizontalAlign: excel_pkg.HorizontalAlign.Center,
      verticalAlign: excel_pkg.VerticalAlign.Center,
    );
    final periodeStyle = excel_pkg.CellStyle(
        fontSize: 11,
        bold: true,
        horizontalAlign: excel_pkg.HorizontalAlign.Right,
        verticalAlign: excel_pkg.VerticalAlign.Center);
    final companyStyle = excel_pkg.CellStyle(
      fontFamily: 'Calibri',
      bold: true,
      fontSize: 12,
      horizontalAlign: excel_pkg.HorizontalAlign.Left,
      verticalAlign: excel_pkg.VerticalAlign.Center,
    );
    final headerStyle = excel_pkg.CellStyle(
      fontFamily: 'Calibri',
      bold: true,
      fontSize: 10,
      fontColorHex: white,
      backgroundColorHex: headerFill,
      horizontalAlign: excel_pkg.HorizontalAlign.Center,
      verticalAlign: excel_pkg.VerticalAlign.Center,
      textWrapping: excel_pkg.TextWrapping.WrapText,
      leftBorder: bodyBorder,
      rightBorder: bodyBorder,
      topBorder: bodyBorder,
      bottomBorder: bodyBorder,
    );

    // Kop.
    _styleCell(sheet, 2, 1, titleStyle);
    _styleCell(sheet, 13, 1, periodeStyle);
    _styleCell(sheet, 1, 3, companyStyle);

    // Header baris 5 & 6.
    for (var col = 1; col <= 17; col++) {
      _styleCell(sheet, col, 5, headerStyle);
      if (_subHeaders.containsKey(col)) {
        _styleCell(sheet, col, 6, headerStyle);
      }
    }

    // Data rows: border + warna selang-seling pada kolom yang terisi.
    final firstDataRow = 7;
    for (var r = firstDataRow; r < sheet.maxRows; r++) {
      final isAlt = (r - firstDataRow) % 2 == 1;
      final style = excel_pkg.CellStyle(
        fontFamily: 'Calibri',
        fontSize: 10,
        textWrapping: excel_pkg.TextWrapping.WrapText,
        verticalAlign: excel_pkg.VerticalAlign.Top,
        backgroundColorHex: isAlt ? dailyFill : excel_pkg.ExcelColor.none,
        leftBorder: bodyBorder,
        rightBorder: bodyBorder,
        topBorder: bodyBorder,
        bottomBorder: bodyBorder,
      );
      for (var col = 1; col <= 17; col++) {
        _styleCell(sheet, col, r, style);
      }
    }
  }

  static void _merge(excel_pkg.Sheet sheet, int col1, int row1, int col2, int row2) {
    sheet.merge(
      excel_pkg.CellIndex.indexByColumnRow(
          columnIndex: col1, rowIndex: row1),
      excel_pkg.CellIndex.indexByColumnRow(
          columnIndex: col2, rowIndex: row2),
    );
  }

  static void _styleCell(excel_pkg.Sheet sheet, int col, int row,
      excel_pkg.CellStyle style) {
    // Pertahankan nilai yang sudah ada (tulis null = menghapus nilai).
    final cell = sheet.cell(
        excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    sheet.updateCell(
      excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      cell.value,
      cellStyle: style,
    );
  }

  Uint8List buildCsvBytes(List<Device> devices) => _buildCsv(devices);

  static Uint8List _buildCsv(List<Device> devices) {
    final buf = StringBuffer();
    buf.writeln(_headers.map(_csvEncode).join(';'));
    for (final d in devices) {
      buf.writeln(_values(d).map(_csvEncode).join(';'));
    }
    // UTF-8 BOM agar karakter Indonesia terbaca benar di Excel.
    final bom = const [0xEF, 0xBB, 0xBF];
    return Uint8List.fromList([...bom, ...buf.toString().codeUnits]);
  }

  static String _csvEncode(String v) {
    final s = v.replaceAll(RegExp(r'\r?\n'), ' ');
    if (s.contains(';') || s.contains('"') || s.contains(',')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  String _timestamp() {
    final now = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${p(now.month)}${p(now.day)}_'
        '${p(now.hour)}${p(now.minute)}${p(now.second)}';
  }
}