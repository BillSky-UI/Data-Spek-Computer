import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/foundation.dart' show compute;

import '../models/device.dart';
import '../utils/field_groups.dart';
import 'public_saver_service.dart';

/// Satu kolom tabel pada sheet Excel.
///
/// [group] adalah judul kelompok yang di-merge di header baris pertama
/// (mis. "Spesifikasi Saat Ini"); null berarti judul kolom tunggal yang
/// di-merge vertikal dua baris.
class _Column {
  const _Column({
    required this.label,
    required this.value,
    this.group,
    this.width = 18,
  });

  final String label;
  final String Function(Device) value;
  final String? group;
  final double width;
}

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

  /// Kolom tabel untuk sebuah sheet.
  ///
  /// Hanya field yang benar-benar diinput pada form kategori tersebut yang
  /// ikut diekspor: printer tidak punya RAM/Storage/OS/Goal, jadi sheet
  /// Printer tidak ikut membawa kolom kosong tersebut.
  ///
  /// Sheet Computer dan Laptop memakai nama kolom versi master (bahasa Inggris)
  /// supaya formatnya tetap sama dengan arsip Excel lama. Sheet Printer memakai
  /// istilah printer lewat [printerSpecLabel].
  static List<_Column> _columnsFor(String category) {
    final isPrinter = categoryKey(category) == 'Printer';
    _Column spec(String label, String Function(Device) getter, double width) =>
        _Column(
          group: 'Spesifikasi Saat Ini',
          label: label,
          value: getter,
          width: width,
        );

    return [
      _Column(
          label: 'Tanggal Evaluasi',
          value: (d) => d.tanggalEvaluasi,
          width: 13),
      _Column(label: 'Kode Inventaris', value: (d) => d.kodeInventaris, width: 12),
      _Column(label: 'PLAN', value: (d) => d.plan, width: 8),
      _Column(label: 'Bagian', value: (d) => d.bagian, width: 16),
      _Column(label: 'Device Name', value: (d) => d.deviceName, width: 18),
      _Column(
          label: 'Category',
          value: (d) => categoryKey(d.category),
          width: 10),
      spec(
          isPrinter ? printerSpecLabel('prosesor') : 'Processor',
          (d) => d.prosesor,
          38),
      spec(
          isPrinter ? printerSpecLabel('motherboard') : 'Motherboard',
          (d) => d.motherboard,
          30),
      if (showSpecField('ram', category)) spec('RAM', (d) => d.ram, 12),
      if (showSpecField('storage', category))
        spec('Storage', (d) => d.storage, 20),
      if (showSpecField('osWindows', category))
        spec('OS Windows', (d) => d.osWindows, 34),
      if (showSpecField('goal', category))
        _Column(label: 'Goal', value: (d) => d.goal, width: 10),
      _Column(
        group: 'Perlu Upgrade',
        label: 'Ganti',
        value: _perluGanti,
        width: 12,
      ),
      _Column(
        group: 'Perlu Upgrade',
        label: 'Repair',
        value: _perluRepair,
        width: 10,
      ),
      _Column(
          label: labelFor('statusUpgrade', category),
          value: (d) => d.statusUpgrade,
          width: 12),
      _Column(label: 'Keterangan', value: (d) => d.keterangan, width: 22),
      _Column(label: 'Status Stiker', value: (d) => d.statusStiker, width: 11),
    ];
  }

  static String _perluGanti(Device d) => d.perluUpgradeGanti;

  static String _perluRepair(Device d) => d.perluUpgradeRepair;

  static const String _mimeXlsx =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

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

  Future<SavedTarget> saveExcelToDownloads(List<Device> devices,
      {String prefix = 'Spek_Inventaris_DPR'}) async {
    final bytes = await buildExcelBytesAsync(devices);
    final name = '${_sanitize(prefix)}_${_timestamp()}.xlsx';
    return PublicSaverService.instance.saveFileToDownloads(
      bytes,
      name,
      _mimeXlsx,
    );
  }

  /// Simpan file .csv ke folder Download publik HP (MediaStore).
  Future<SavedTarget> saveCsvToDownloads(List<Device> devices,
      {String prefix = 'Spek_Inventaris_DPR'}) async {
    final bytes = await compute(_buildCsv, devices);
    final name = '${_sanitize(prefix)}_${_timestamp()}.csv';
    return PublicSaverService.instance.saveFileToDownloads(
        bytes, name, 'text/csv');
  }

  /// Buang karakter yang tidak aman untuk nama file.
  static String _sanitize(String s) {
    final bersih = s.trim().replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
    return bersih.isEmpty ? 'Spek_Inventaris_DPR' : bersih;
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
    _applyLayout(sheet, category);
  }

  /// Susun baris mentah (kop + header 2 baris + data). Nilai diisi sebagai
  /// string; null = kosong. Data dimulai dari kolom 1 (B) seperti master,
  /// jumlah kolom mengikuti [_columnsFor] kategori sheet tersebut.
  static List<List<String?>> _rowsFor(
      String category, String periode, List<Device> devices) {
    final cols = _columnsFor(category);
    final width = cols.length + 1; // +1 kolom kosong di kiri (seperti master)
    final last = cols.length; // kolom data terakhir
    final blank = List<String?>.filled(width, null);

    String? groupFor(_Column col) {
      if (col.group == null) return null;
      final i = cols.indexOf(col);
      final before = i > 0 ? cols[i - 1].group : null;
      return before == col.group ? null : col.group;
    }

    // R1: judul laporan di kiri, periode di empat kolom terakhir.
    final kop = List<String?>.filled(width, null);
    kop[2] = _titleFor(category);
    kop[last - 4] = periode;

    final rows = <List<String?>>[
      blank, // R0 spacer
      kop, // R1 judul + periode
      blank, // R2 spacer
      [null, _company, ...List<String?>.filled(width - 2, null)], // R3 perusahaan
      blank, // R4 spacer
      // R5 kelompok header, R6 judul kolom.
      [for (final col in cols) groupFor(col)]..insert(0, null),
      [for (final col in cols) col.label]..insert(0, null),
    ];

    // Baris data mulai dari index 7.
    for (final d in devices) {
      rows.add([null, ...cols.map((c) => c.value(d))]);
    }
    return rows;
  }

  static void _applyLayout(excel_pkg.Sheet sheet, String category) {
    final cols = _columnsFor(category);
    final last = cols.length; // kolom data terakhir (1-based)
    final singles = <int>[
      for (var i = 0; i < cols.length; i++)
        if (cols[i].group == null) i + 1,
    ];

    // Lebar kolom menyesuaikan isi.
    for (var i = 0; i < cols.length; i++) {
      sheet.setColumnWidth(i + 1, cols[i].width);
    }

    // Merge kop.
    _merge(sheet, 2, 1, last - 5, 1); // judul laporan
    _merge(sheet, last - 4, 1, last, 1); // periode
    _merge(sheet, 1, 3, last, 3); // perusahaan
    // Merge kelompok header (kolom berurutan dengan group sama).
    for (var i = 0; i < cols.length; i++) {
      final group = cols[i].group;
      if (group == null) continue;
      var end = i;
      while (end + 1 < cols.length && cols[end + 1].group == group) {
        end++;
      }
      _merge(sheet, i + 1, 5, end + 1, 5);
      i = end;
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
    _styleCell(sheet, last - 4, 1, periodeStyle);
    _styleCell(sheet, 1, 3, companyStyle);

    // Header baris 5 & 6.
    for (var col = 1; col <= last; col++) {
      _styleCell(sheet, col, 5, headerStyle);
      if (singles.contains(col)) {
        _merge(sheet, col, 5, col, 6);
      } else {
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
      for (var col = 1; col <= last; col++) {
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

  /// CSV tetap memakai satu header untuk semua perangkat: kolom diambil dari
  /// kategori Computer yang paling lengkap, supaya semua baris Sejajar.
  static Uint8List _buildCsv(List<Device> devices) {
    final cols = _columnsFor(_sheetOrder.first);
    final buf = StringBuffer();
    buf.writeln(
      cols.map((c) => c.group == null ? c.label : '${c.group} - ${c.label}').map(_csvEncode).join(';'),
    );
    for (final d in devices) {
      buf.writeln(cols.map((c) => _csvEncode(c.value(d))).join(';'));
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