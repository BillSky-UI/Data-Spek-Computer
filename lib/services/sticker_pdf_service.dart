import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/device.dart';
import '../utils/field_groups.dart';

/// Argumen yang dikirim ke isolate latar.
///
/// [logo1] dan [logo2] sudah dibaca sebagai byte di isolate utama, karena
/// `rootBundle` tidak bisa dipakai dari isolate yang di-spawn `compute`.
class StikerJob {
  const StikerJob(this.d, this.logo1, this.logo2);

  final Device d;
  final Uint8List? logo1;
  final Uint8List? logo2;
}

/// Argumen stiker printer ke isolate latar.
///
/// Berbeda dari [StikerJob], stiker printer memakai satu gambar latar penuh
/// (logo + garis + tulisan label sudah menyatu di dalam desain) sehingga
/// hanya butuh satu aset gambar, ditambah byte font Carlito.
class PrinterStikerJob {
  const PrinterStikerJob(this.d, this.background, this.fontBytes);

  final Device d;
  final Uint8List? background;
  final Uint8List? fontBytes;
}

/// Generator PDF stiker. Ada dua desain, dipilih otomatis dari kategori:
///
/// 1. **Inventaris & Spesifikasi** (Computer/Laptop) - meniru
///    `Logo/Template Stiker.pdf`.
/// 2. **Label Inventaris Kantor** (Printer) - memakai gambar desain sebagai
///    latar, lihat bagian "stiker printer" di bawah.
///
/// Kertas stiker pertama dicetak 155 x 60 mm (15,5 cm x 6 cm), sedangkan
/// koordinat di bawah ini **diukur langsung dari file PDF template**
/// (CropBox 157 x 63 mm, 1 unit = 1/72 inch) lalu dikonversi ke milimeter.
/// Ruang ukur itu dipakai apa adanya, lalu diperkecil seragam oleh [scale]
/// agar seluruh desain muat di kertas yang lebih kecil tanpa teregang.
/// Karena memakai posisi absolut, tata letak tidak bergeser walaupun isi
/// data panjangnya berbeda-beda.
///
/// Rangka desain hasil ukur:
/// - garis horizontal tiap 5,45 mm (tipis), garis paling atas & bawah lebih
///   tebal, garis vertikal kiri & kanan sebagai pembatas;
/// - dua garis vertikal di x=20,71 dan x=55,35 membagi area tabel menjadi
///   3 kolom: No | Sub-unit | Merek Dan Spesifikasi Komponen;
/// - pita abu-abu (RGB 208) sebagai baris "Perangkat Keras/Hardware";
/// - dua logo di header: `stiker_header.png` di kiri dan `logo_dpr_small.png`
///   di kanan, keduanya setinggi 7,2 mm dan sejajar pada titik yang sama.
///
/// Peringatan: Flutter memotong konten yang melebihi tinggi halaman tanpa
/// melempar error, jadi jangan diubah ukuran kertasnya tanpa diuji ulang.
class StickerPdfService {
  StickerPdfService._();
  static final StickerPdfService instance = StickerPdfService._();

  /// Ukuran kertas stiker (mm) = 15,5 cm x 6 cm.
  static const double paperW = 155;
  static const double paperH = 60;

  /// Ruang desain hasil ukur dari `Logo/Template Stiker.pdf` (157 x 63 mm).
  /// Semua konstanta posisi di bawah memakai satuan ini lalu dipetakan ke
  /// ukuran kertas nyata lewat [scale] + [_offX]/_offY.
  static const double _designW = 157;
  static const double _designH = 63;

  /// Skala seragam supaya gambar dan garis tidak teregang. Sisi terpendek
  /// jadi pembatas: 60/63 = 0,9524 < 155/157 = 0,9873.
  static const double scale = 60 / 63;

  /// Sisa lebar dibagi rata jadi margin kiri/kanan; tinggi pas karena
  /// _designH * scale == paperH.
  static const double _offX = (paperW - _designW * scale) / 2;
  static const double _offY = (paperH - _designH * scale) / 2;

  /// Pemetaan ruang desain -> milimeter kertas nyata.
  static double _px(double v) => _offX + v * scale; // x dari tepi kiri
  static double _py(double v) => _offY + v * scale; // y dari tepi atas
  static double _pl(double v) => v * scale; // panjang (lebar/tinggi/garis)
  /// y dari tepi bawah kertas.
  static double _pb(double v) => paperH - _offY - (_designH - v) * scale;

  // ---------------------------------------------------------------- kerangka
  static const double _borderTop = 1.37;
  static const double _borderH = 60.82;
  static const double _leftRuleX = 1.10;
  static const double _leftRuleW = 0.58;
  static const double _rightRuleX = 155.28;
  static const double _rightRuleW = 0.79;

  static const double _hlineX = 1.68;
  static const double _hlineW = 153.60;
  static const double _hlineH = 0.70;
  static const double _topHlineY = 1.37;
  static const double _bottomHlineY = 61.19;
  static const double _bottomHlineH = 1.00;
  static const List<double> _rowHlines = <double>[
    12.42, // y-bawah 50,58
    23.02, // y-bawah 39,98
    28.48, // y-bawah 34,52 (tepat di bawah pita abu)
    33.95, // y-bawah 29,05
    39.42, // y-bawah 23,58
    44.89, // y-bawah 18,11
    50.36, // y-bawah 12,64
    55.81, // y-bawah  7,19
  ];

  static const double _vlineTop = 28.81;
  static const double _vlineH = 32.38;
  static const double _col1RuleX = 20.71;
  static const double _col1RuleW = 0.26;
  static const double _col2RuleX = 55.35;
  static const double _col2RuleW = 0.43;

  static const double _bandX = 1.41;
  static const double _bandW = 154.39;
  static const double _bandY = 23.18;
  static const double _bandH = 5.51;

  // ------------------------------------------------------------------ logo
  //
  // Band header adalah ruang antara garis atas (selesai di y=2,07) dan garis
  // tabel pertama (y=12,42), jadi tingginya 10,35 mm. Kedua logo memakai
  // tinggi 7,2 mm yang sama agar sejajar, dengan sisa 1,575 mm dibagi rata
  // sebagai jarak atas dan bawah supaya tidak menempel garis.
  static const double _headerTop = 2.07;
  static const double _headerBottom = 12.42;
  static const double _logoH = 7.20;
  static const double _logoY =
      _headerTop + (_headerBottom - _headerTop - _logoH) / 2;

  // Lebar mengikuti rasio gambar supaya kotak pas dan tidak ada ruang kosong
  // di dalam (BoxFit.contain akan menengahkan gambar, bukan meregangkannya).
  static const double _logoRatio = 1.5575; // stiker_header.png 623x400
  static const double _logo2Ratio = 1.2422; // logo_dpr_small.png 400x322
  static const double _logoW = _logoH * _logoRatio;
  static const double _logo2W = _logoH * _logo2Ratio;

  static const double _logoX = 5.16; // logo kiri, mengukur dari template
  static const double _logo2Right = 151.00; // tepi kanan logo kanan
  static const double _logo2X = _logo2Right - _logo2W;

  // ------------------------------------------------------------------ teks
  static const double _titleFs = 11.2;
  static const double _bodyFs = 8.75;

  // Batas bawah ukuran huruf agar kode inventaris yang panjang tetap
  // terbaca utuh walau hurufnya harus mengecil jauh dari ukuran desain.
  static const double _minFs = 5.0;

  static const double _titleX = 44.80;
  static const double _titleBaseline = 54.60;

  static const List<double> _labelX = <double>[2.00, 56.20, 103.40];
  static const List<double> _valueX = <double>[21.50, 67.40, 118.90];
  static const double _row1Baseline = 46.80;
  static const double _row2Baseline = 41.40;

  static const double _bandTextX = 57.90;
  static const double _bandBaseline = 35.90;

  static const double _headerBaseline = 30.50;
  static const List<double> _rowBaselines = <double>[
    25.00,
    19.50,
    14.10,
    8.60,
    3.20,
  ];

  // batas lebar tiap kolom (mm) dipakai untuk mengecilkan huruf otomatis
  static const double _noColCenter = 11.20;
  static const double _noColW = 19.00;
  static const double _unitX = 21.50;
  static const double _unitW = 33.60;
  static const double _specCenter = 105.30;
  static const double _specW = 99.00;

  // `left` pada helper _teks adalah tepi kiri kotak, jadi kolom yang
  // dipusatkan harus dikurangi setengah lebarnya lebih dulu.
  static const double _noColLeft = _noColCenter - _noColW / 2;
  static const double _specLeft = _specCenter - _specW / 2;

  static const String noDok = 'FRM-06/SOP-001-IT';

  // --------------------------------------------------------- stiker printer
  //
  // Kategori Printer memakai desain yang berbeda: `Logo/Label Inventaris
  // Kantor.pdf`. Di sana logo, garis bingkai, dan tulisan label sudah dibakar
  // jadi satu gambar raster 898 x 449 px yang memenuhi seluruh halaman, jadi
  // file JPEG itu dipakai apa adanya sebagai latar. Yang digambar ulang hanya
  // nilai-nilai data, dengan posisi yang diambil dari content stream PDF.
  //
  // Ukuran kertas = CropBox PDF 215,52 x 107,76 pt, dengan 1 pt = 25,4/72 mm.
  static const double printerW = 76.03; // mm
  static const double printerH = 38.02; // mm
  static const String _printerBgAsset = 'assets/img/stiker_printer_bg.jpg';
  static const String _printerFontAsset = 'assets/fonts/Carlito-Bold.ttf';

  /// Font desain: Calibri-Bold 6 pt. Calibri itu font proprietary Microsoft,
  /// jadi tidak boleh disertakan di aplikasi; yang dipakai adalah **Carlito**,
  /// klon open-source dengan metrik dan tampilan identik Calibri. Dengan itu
  /// lebar huruf, tinggi huruf, dan posisinya sama persis dengan desain
  /// (Helvetica-Bold terlalu lebar sehingga teks terlihat tidak sinkron).
  ///
  /// Fallback ke Helvetica-Bold dipakai kalau font gagal dimuat, supaya PDF
  /// tetap bisa dibuat. [_teksPrinter] tetap mengecilkan huruf otomatis bila
  /// teks melebihi lebar kolomnya.
  static const double _printerFs = 6.0;
  static const double _printerMinFs = 3.0;

  /// Posisi slot teks hasil ukur dari content stream, satuan mm dihitung dari
  /// tepi atas label (y = tinggiHalaman - baselinePd).
  static const double _pBarangX = 15.82; // 44,832 pt
  static const double _pBarangY = 9.78; // baseline 80,051 pt
  static const double _pBagianX = 15.74; // 44,623 pt
  static const double _pBagianY = 13.67; // baseline 69,023 pt
  static const double _pPicX = 15.69; // 44,478 pt
  static const double _pPicY = 18.49; // baseline 55,347 pt
  static const double _pKodeX = 53.96; // 152,945 pt
  static const double _pKodeY = 9.47; // baseline 80,918 pt
  static const double _pKetX = 48.07; // 136,248 pt
  static const double _pKetY = 23.33; // baseline 41,623 pt

  /// Tanggal Penyerahan tidak ada di desain asli (yang hanya punya 5 slot),
  /// jadi posisinya disamakan dengan baris "Bagian" di kolom kanan, memberi
  /// bentuk form 2 kolom yang rata. Lebarnya mengikuti kolom Kode Unit.
  static const double _pTglX = 53.96;
  static const double _pTglY = 13.67;

  /// Lebar area nilai. Batas kanan kolom kiri diambil sebelum area Kode Unit
  /// mulai (x = 53,96 mm); nilai yang lebih panjang akan mengecilkan huruf.
  static const double _pKolW = 28.0;
  static const double _pKodeW = 19.5;
  static const double _pKetW = 26.0;

  /// Font terpisah hanya untuk mengukur lebar teks (butuh PdfDocument).
  static final PdfDocument _ukurDoc = PdfDocument();
  static final PdfFont _ukurBold = PdfFont.helveticaBold(_ukurDoc);
  static final PdfFont _ukurReg = PdfFont.helvetica(_ukurDoc);

  /// Cache byte logo agar tidak dibaca ulang dari `rootBundle` tiap stiker.
  static final Map<String, Uint8List?> _cacheLogo = <String, Uint8List?>{};

  /// Membuat PDF stiker sesuai kategori perangkat.
  ///
  /// Printer memakai desain `Logo/Label Inventaris Kantor.pdf` (76,03 x 38,02
  /// mm, latar gambar), sedangkan kategori lain memakai stiker
  /// Inventaris & Spesifikasi 155 x 60 mm.
  ///
  /// Seluruh pekerjaan berat (kompresi gambar + Flate) dijalankan di isolate
  /// latar lewat [compute] supaya UI thread tidak beku dan Android tidak
  /// menampilkan dialog "isn't responding". Aset gambar tetap dibaca di isolate
  /// utama karena `rootBundle` tidak tersedia di isolate latar.
  Future<Uint8List> buildSticker(Device d) async {
    if (categoryKey(d.category) == 'Printer') {
      final bg = await _muatLogo(_printerBgAsset);
      final font = await _muatLogo(_printerFontAsset);
      return compute(_rakitStikerPrinter, PrinterStikerJob(d, bg, font));
    }
    final logo1 = await _muatLogo('assets/img/stiker_header.png');
    final logo2 = await _muatLogo('assets/img/logo_dpr_small.png');
    return compute(_rakitStiker, StikerJob(d, logo1, logo2));
  }

  static Future<Uint8List> _rakitStiker(StikerJob job) {
    final d = job.d;
    final m = PdfPageFormat.mm;
    final doc = pw.Document();
    final bold = pw.Font.helveticaBold();
    final reg = pw.Font.helvetica();

    String isi(String s) {
      final t = s.trim();
      return _latin1(t.isEmpty ? '-' : t);
    }

    // ------------------------------------------------------------ kerangka
    final list = <pw.Widget>[];

    void rule(double x, double y, double w, double h) => list.add(
      pw.Positioned(
        left: _px(x) * m,
        top: _py(y) * m,
        child: pw.Container(
          width: _pl(w) * m,
          height: _pl(h) * m,
          color: PdfColors.black,
        ),
      ),
    );

    rule(_leftRuleX, _borderTop, _leftRuleW, _borderH);
    rule(_rightRuleX, _borderTop, _rightRuleW, _borderH);
    rule(_hlineX, _topHlineY, _hlineW, _hlineH);
    rule(_hlineX, _bottomHlineY, _hlineW, _bottomHlineH);
    for (final y in _rowHlines) {
      rule(_hlineX, y, _hlineW, _hlineH);
    }
    rule(_col1RuleX, _vlineTop, _col1RuleW, _vlineH);
    rule(_col2RuleX, _vlineTop, _col2RuleW, _vlineH);

    list.add(
      pw.Positioned(
        left: _px(_bandX) * m,
        top: _py(_bandY) * m,
        child: pw.Container(
          width: _pl(_bandW) * m,
          height: _pl(_bandH) * m,
          color: PdfColor.fromInt(0xFFD0D0D0),
        ),
      ),
    );

    // Dua logo: kiri (kop) dan kanan (logo DPR), tinggi sama agar sejajar.
    void tambahLogo(Uint8List? bytes, double x, double w) {
      if (bytes == null) return;
      list.add(
        pw.Positioned(
          left: _px(x) * m,
          top: _py(_logoY) * m,
          child: pw.Image(
            pw.MemoryImage(bytes),
            width: _pl(w) * m,
            height: _pl(_logoH) * m,
            fit: pw.BoxFit.contain,
          ),
        ),
      );
    }

    tambahLogo(job.logo1, _logoX, _logoW);
    tambahLogo(job.logo2, _logo2X, _logo2W);

    // ---------------------------------------------------------------- teks
    // judul
    list.add(
      _teks(
        'Inventaris & Spesifikasi',
        left: _titleX,
        width: 109.5,
        baseline: _titleBaseline,
        font: bold,
        pengukur: _ukurBold,
        size: _titleFs,
      ),
    );

    // 2 baris identitas: label tebal + nilai, mengikuti kolom di desain
    const labels1 = <String>['Inventaris :', 'Divisi :', 'No.Dok :'];
    const labels2 = <String>['Kode :', 'PJ :', 'Tgl Brlk :'];
    final values1 = <String>[isi(d.category), isi(d.bagian), noDok];
    final values2 = <String>[
      isi(d.kodeInventaris),
      isi(d.deviceName),
      isi(d.tanggalEvaluasi),
    ];
    const labelW = <double>[18.50, 10.20, 14.50];
    const valueW = <double>[33.70, 35.00, 35.40];

    for (var i = 0; i < 3; i++) {
      list.add(
        _teks(
          labels1[i],
          left: _labelX[i],
          width: labelW[i],
          baseline: _row1Baseline,
          font: bold,
          pengukur: _ukurBold,
          size: _bodyFs,
        ),
      );
      list.add(
        _teks(
          values1[i],
          left: _valueX[i],
          width: valueW[i],
          baseline: _row1Baseline,
          font: reg,
          pengukur: _ukurReg,
          size: _bodyFs,
        ),
      );
      list.add(
        _teks(
          labels2[i],
          left: _labelX[i],
          width: labelW[i],
          baseline: _row2Baseline,
          font: bold,
          pengukur: _ukurBold,
          size: _bodyFs,
        ),
      );
      list.add(
        _teks(
          values2[i],
          left: _valueX[i],
          width: valueW[i],
          baseline: _row2Baseline,
          font: reg,
          pengukur: _ukurReg,
          size: _bodyFs,
        ),
      );
    }

    // baris pita abu
    list.add(
      _teks(
        'Perangkat Keras/Hardware',
        left: _bandTextX,
        width: 96.0,
        baseline: _bandBaseline,
        font: bold,
        pengukur: _ukurBold,
        size: _bodyFs,
      ),
    );

    // header tabel
    list.add(
      _teks(
        'No',
        left: _noColLeft,
        width: _noColW,
        baseline: _headerBaseline,
        font: reg,
        pengukur: _ukurReg,
        size: _bodyFs,
        align: pw.Alignment.topCenter,
      ),
    );
    list.add(
      _teks(
        'Merek Dan Spesifikasi Komponen',
        left: _specLeft,
        width: _specW,
        baseline: _headerBaseline,
        font: reg,
        pengukur: _ukurReg,
        size: _bodyFs,
        align: pw.Alignment.topCenter,
      ),
    );
    list.add(
      _teks(
        'Sub-unit',
        left: _unitX,
        width: _unitW,
        baseline: _headerBaseline,
        font: reg,
        pengukur: _ukurReg,
        size: _bodyFs,
      ),
    );

    // 5 baris komponen
    final subUnit = <String>[
      'Mainboard',
      'Processor(CPU)',
      'RAM',
      'Memory',
      'SSD',
    ];
    final spec = <String>[
      isi(d.motherboard),
      isi(d.prosesor),
      isi(d.ram),
      '-', // tidak ada kolom "Memory" di database
      isi(d.storage),
    ];
    for (var i = 0; i < 5; i++) {
      list.add(
        _teks(
          '${i + 1}',
          left: _noColLeft,
          width: _noColW,
          baseline: _rowBaselines[i],
          font: reg,
          pengukur: _ukurReg,
          size: _bodyFs,
          align: pw.Alignment.topCenter,
        ),
      );
      list.add(
        _teks(
          subUnit[i],
          left: _unitX,
          width: _unitW,
          baseline: _rowBaselines[i],
          font: reg,
          pengukur: _ukurReg,
          size: _bodyFs,
        ),
      );
      list.add(
        _teks(
          spec[i],
          left: _specLeft,
          width: _specW,
          baseline: _rowBaselines[i],
          font: reg,
          pengukur: _ukurReg,
          size: _bodyFs,
          align: pw.Alignment.topCenter,
        ),
      );
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(paperW * m, paperH * m),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Stack(children: list),
      ),
    );

    return doc.save();
  }

  /// Membangun stiker printer: gambar desain sebagai latar penuh, lalu
  /// lima nilai data ditulis di posisinya masing-masing.
  ///
  /// Pemetaan data (lihat `printerSpecLabel` di `lib/utils/field_groups.dart`):
  /// - Nama Barang -> `prosesor` (di form berlabel "Tipe / Model Printer")
  /// - Bagian      -> `bagian`
  /// - Nama PIC    -> `deviceName`
  /// - Kode Unit   -> `kodeInventaris`
  /// - Keterangan  -> `keterangan` (opsional)
  static Future<Uint8List> _rakitStikerPrinter(PrinterStikerJob job) {
    final d = job.d;
    final m = PdfPageFormat.mm;
    final doc = pw.Document();
    final bold = pw.Font.helveticaBold();

    String isi(String s) {
      final t = s.trim();
      return t.isEmpty ? '-' : t;
    }

    final list = <pw.Widget>[];

    // Latar: gambar desain 898 x 449 px (rasio 2:1) mengisi seluruh label.
    final bg = job.background;
    if (bg != null) {
      list.add(
        pw.Positioned(
          left: 0,
          top: 0,
          child: pw.Image(
            pw.MemoryImage(bg),
            width: printerW * m,
            height: printerH * m,
            fit: pw.BoxFit.fill,
          ),
        ),
      );
    }

    pw.Widget tulis(
      String value,
      double x,
      double baseline,
      double width,
    ) =>
        _teksPrinter(
          isi(value),
          x: x,
          baselineFromTop: baseline,
          width: width,
          size: _printerFs,
          font: bold,
          pengukur: _ukurBold,
        );

    // Kolom kiri: Nama Barang / Bagian / Nama PIC.
    list
      ..add(tulis(d.prosesor, _pBarangX, _pBarangY, _pKolW))
      ..add(tulis(d.bagian, _pBagianX, _pBagianY, _pKolW))
      ..add(tulis(d.deviceName, _pPicX, _pPicY, _pKolW))
      // Kanan atas: Kode Unit. Bawah: Keterangan.
      ..add(tulis(d.kodeInventaris, _pKodeX, _pKodeY, _pKodeW))
      ..add(tulis(d.keterangan, _pKetX, _pKetY, _pKetW));

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(printerW * m, printerH * m),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Stack(children: list),
      ),
    );

    return doc.save();
  }

  /// Menempatkan satu nilai pada baseline tertentu (mm dari tepi atas label).
  ///
  /// Berbeda dengan [_teks] yang memakai koordinat ruang desain umum, helper
  /// ini bekerja langsung dalam milimeter label printer. Huruf otomatis
  /// dikecilkan bila teks lebih lebar dari [width].
  static pw.Widget _teksPrinter(
    String text, {
    required double x,
    required double baselineFromTop,
    required double width,
    required double size,
    required pw.Font font,
    required PdfFont pengukur,
  }) {
    final m = PdfPageFormat.mm;
    final s = _latin1(text);
    if (s.isEmpty) return pw.SizedBox();

    var fs = size;
    final em = _emWidth(pengukur, s);
    if (em > 0 && em * fs > width * m) {
      fs = (fs * (width * m) / (em * fs)).clamp(_printerMinFs, size);
    }

    final ascMm = pengukur.ascent * fs / m;
    return pw.Positioned(
      left: x * m,
      top: (baselineFromTop - ascMm) * m,
      child: pw.SizedBox(
        width: width * m,
        height: (ascMm + fs * 0.8 / m) * m,
        child: pw.Text(
          s,
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
          style: pw.TextStyle(font: font, fontSize: fs, lineSpacing: 0),
        ),
      ),
    );
  }

  /// Menempatkan satu teks pada baseline tertentu (mm dari tepi bawah kertas).
  ///
  /// Huruf otomatis dikecilkan bila teks lebih lebar dari [width] supaya tidak
  /// menabrak teks di sebelahnya.
  static pw.Widget _teks(
    String text, {
    required double left,
    required double width,
    required double baseline,
    required pw.Font font,
    required PdfFont pengukur,
    required double size,
    pw.Alignment align = pw.Alignment.topLeft,
  }) {
    final m = PdfPageFormat.mm;
    final s = _latin1(text);
    if (s.isEmpty) return pw.SizedBox();

    // [size] dan [width] masih satuan ruang desain; dipetakan ke kertas nyata.
    final fsCap = size * scale;
    final wMm = _pl(width);
    var fs = fsCap;
    final em = _emWidth(pengukur, s);
    if (em > 0 && em * fs > wMm * m) {
      fs = (fs * (wMm * m) / (em * fs)).clamp(_minFs, fsCap);
    }

    final ascMm = pengukur.ascent * fs / m;
    return pw.Positioned(
      left: _px(left) * m,
      top: (paperH - _pb(baseline) - ascMm) * m,
      child: pw.SizedBox(
        width: wMm * m,
        height: (ascMm + fs * 0.8 / m) * m,
        child: pw.Container(
          alignment: align,
          child: pw.Text(
            s,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: pw.TextStyle(font: font, fontSize: fs, lineSpacing: 0),
          ),
        ),
      ),
    );
  }

  /// Lebar teks dalam satuan "em" (untuk font ukuran 1 pt).
  static double _emWidth(PdfFont font, String s) {
    try {
      return font.stringMetrics(s).width;
    } catch (_) {
      return 0;
    }
  }

  /// Helvetica hanya mendukung Latin-1; karakter lain dibuang agar PDF tidak
  /// gagal dibuat.
  static String _latin1(String s) {
    const ganti = <int, int>{
      0x2013: 0x2D,
      0x2014: 0x2D,
      0x2018: 0x27,
      0x2019: 0x27,
      0x201C: 0x22,
      0x201D: 0x22,
      0x2026: 0x2E,
      0x00A0: 0x20,
      0x00B0: 0x6F,
      0x2022: 0x2D,
    };
    final buf = StringBuffer();
    for (final r in s.runes) {
      final c = ganti[r] ?? r;
      buf.writeCharCode(c > 0xFF ? 0x3F : c);
    }
    return buf.toString();
  }

  /// Membaca byte logo dari aset, dengan cache.
  ///
  /// Mengembalikan null bila aset tidak tersedia supaya stiker tetap bisa
  /// dibuat tanpa logo.
  static Future<Uint8List?> _muatLogo(String path) async {
    if (_cacheLogo.containsKey(path)) return _cacheLogo[path];
    Uint8List? data;
    try {
      final raw = await rootBundle.load(path);
      data = raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
    } catch (_) {
      data = null;
    }
    _cacheLogo[path] = data;
    return data;
  }
}
