import 'package:flutter_test/flutter_test.dart';
import 'package:spek_komputer/models/device.dart';
import 'package:spek_komputer/services/sticker_pdf_service.dart';

import 'pdf_probe.dart';

/// Toleransi posisi mm. Mengukur ulang PDF selalu menghasilkan selisih
/// pembulatan desimal, jadi 0,3 mm sudah jauh di bawah ketelitian cetak.
const double toleransi = 0.3;

Device contoh({
  String kode = 'K-001',
  String processor = 'Intel Core i7-12700KF',
}) => Device(
  kodeInventaris: kode,
  tanggalEvaluasi: '20/10/2025',
  bagian: 'IT',
  deviceName: 'Eky',
  category: 'Dekstop',
  prosesor: processor,
  motherboard: 'Asus H610',
  ram: '32 GB DDR4',
  storage: '256 GB SSD Sata',
);

Device contohPrinter({
  String model = 'Canon i-SENSYS LBP226dw',
  String kode = 'PR-001',
  String pic = 'Eky',
  String ket = 'Unit Aktif',
  String tgl = '20/10/2025',
}) =>
    Device(
      kodeInventaris: kode,
      tanggalEvaluasi: tgl,
      bagian: 'IT',
      deviceName: pic,
      category: 'Printer',
      // Di form berlabel "Tipe / Model Printer" untuk kategori Printer.
      prosesor: model,
      keterangan: ket,
    );

void main() {
  // Wajib: tanpa ini `rootBundle.load` melempar "Binding has not yet been
  // initialized", aset logo gagal dimuat, dan PDF tanpa logo.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF stiker 155 x 60 mm', () {
    late PdfProbe probe;

    setUpAll(() async {
      final bytes = await StickerPdfService.instance.buildSticker(contoh());
      probe = PdfProbe.fromBytes(bytes);
    });

    test('ukuran kertas sesuai desain', () {
      final box = probe.mediaBox!;
      expect(box.width, closeTo(155, toleransi));
      expect(box.height, closeTo(60, toleransi));
    });

    test('kedua logo tertanam', () {
      expect(probe.hasImage, isTrue);
      // Dua logo berbeda: stiker_header.png (623x400) dan logo_dpr.png.
      // Dua logo berbeda: stiker_header.png (623x400) dan
      // logo_dpr_small.png (400x322). Resolusi logo DPR sengaja dikecilkan
      // dari master 12368x9966 karena yang dicetak hanya 8 x 7 mm.
      expect(probe.dimensiGambar, {
        (w: 623, h: 400),
        (w: 400, h: 322),
      }, reason: 'harus ada logo kiri + logo DPR');
    });

    test('logo tidak menempel garis atas dan garis tabel', () {
      // Band header di ruang desain: y 2,07 (garis atas) .. 12,42 (garis
      // tabel). Logo 7,2 mm harus menyisakan 1,575 mm di atas dan bawah.
      const top = 2.07;
      const bot = 12.42;
      const logoH = 7.20;
      final s = StickerPdfService.scale;
      final expectedTop = (top + (bot - top - logoH) / 2) * s;
      final expectedBottom = expectedTop + logoH * s;
      final garisTabelDariAtas = bot * s;

      // Kotak tiap gambar dalam mm, diukur dari tepi bawah halaman.
      for (final mm in probe.kotakGambar) {
        final atas = 60 - (mm.y + mm.h); // posisi tepi atas logo
        final bawah = 60 - mm.y; // posisi tepi bawah logo
        expect(
          atas,
          closeTo(expectedTop, 0.3),
          reason:
              'jarak logo atas ${atas.toStringAsFixed(2)} mm '
              '(harus ~${expectedTop.toStringAsFixed(2)})',
        );
        expect(
          bawah,
          closeTo(expectedBottom, 0.3),
          reason:
              'jarak logo bawah ${bawah.toStringAsFixed(2)} mm '
              '(harus ~${expectedBottom.toStringAsFixed(2)})',
        );
        expect(atas, greaterThan(0.5), reason: 'logo menempel garis atas');
        expect(
          bawah,
          lessThan(garisTabelDariAtas),
          reason: 'logo menabrak garis tabel',
        );
      }
    });

    test('judul di baris paling atas', () {
      final judul = probe.items
          .where((e) => e.yMm > 50 * StickerPdfService.scale)
          .map((e) => e.text)
          .toList();
      expect(judul.join(' '), 'Inventaris & Spesifikasi');
    });

    test('dua baris identitas terbaca penuh', () {
      final t = probe.teksGabung;
      expect(t, contains('Inventaris:Dekstop'));
      expect(t, contains('Divisi:IT'));
      expect(t, contains('No.Dok:FRM-06/SOP-001-IT'));
      expect(t, contains('Kode:K-001'));
      expect(t, contains('PJ:Eky'));
      expect(t, contains('TglBrlk:20/10/2025'));
    });

    test('tabel punya 5 baris komponen dari database', () {
      final t = probe.teksGabung;
      expect(t, contains('Sub-unit'));
      expect(t, contains('MerekDanSpesifikasiKomponen'));
      expect(t, contains('PerangkatKeras/Hardware'));
      expect(t, contains('MainboardAsusH610'));
      expect(t, contains('Processor(CPU)IntelCorei7-12700KF'));
      expect(t, contains('RAM32GBDDR4'));
      expect(t, contains('Memory-'));
      expect(t, contains('SSD256GBSSDSata'));
    });

    test('baseline tiap baris mengikuti skala desain', () {
      // Nilai diukur dari template 157x63, lalu dikali skala ke kertas nyata.
      const desain = <double>[
        54.6, // judul
        46.8, // baris identitas 1
        41.4, // baris identitas 2
        35.9, // pita abu
        30.5, // header tabel
        25.0, // baris komponen 1
        19.5, // 2
        14.1, // 3
        8.6, // 4
        3.2, // 5
      ];
      final s = StickerPdfService.scale;
      final ada = probe.baselines;
      for (final d in desain) {
        final tunggu = d * s;
        expect(
          ada.any((v) => (v - tunggu).abs() < toleransi),
          isTrue,
          reason:
              'tidak ada teks pada baseline $tunggu mm '
              '(desain $d mm x skala $s)',
        );
      }
    });

    test('tidak ada teks keluar kertas', () {
      for (final e in probe.items) {
        expect(e.xMm, greaterThanOrEqualTo(0), reason: '"${e.text}" di kiri');
        expect(
          e.xMm,
          lessThan(155),
          reason: '"${e.text}" mulai di x=${e.xMm} > 155 mm',
        );
        expect(e.yMm, greaterThan(0), reason: '"${e.text}" di bawah');
        expect(e.yMm, lessThan(60), reason: '"${e.text}" di atas');
      }
    });

    test('tanpa barcode dan QR', () {
      final raw = probe.raw;
      expect(raw.contains('/Type /Barcode'), isFalse);
      expect(raw.contains('BWSC'), isFalse);
      expect(probe.teksGabung, isNot(contains('http')));
    });

    test('ukuran huruf mengikuti skala desain', () {
      // desain: judul 11,2 pt, isi 8,75 pt; dikali skala ke kertas nyata
      final s = StickerPdfService.scale;
      final judul = probe.items.firstWhere((e) => e.yMm > 50 * s);
      expect(judul.fontSizePt, closeTo(11.2 * s, 0.05));
      final isi = probe.items.firstWhere(
        (e) => e.yMm > 40 * s && e.yMm < 47 * s,
      );
      expect(isi.fontSizePt, closeTo(8.75 * s, 0.05));
    });
  });

  group('PDF stiker printer 76 x 38 mm', () {
    late PdfProbe probe;

    setUpAll(() async {
      final bytes =
          await StickerPdfService.instance.buildSticker(contohPrinter());
      probe = PdfProbe.fromBytes(bytes);
    });

    test('ukuran kertas sesuai desain Label Inventaris Kantor', () {
      // CropBox PDF 215,52 x 107,76 pt -> 76,03 x 38,02 mm.
      final box = probe.mediaBox!;
      expect(box.width, closeTo(76.03, toleransi));
      expect(box.height, closeTo(38.02, toleransi));
    });

    test('gambar desain tertanam sebagai latar penuh', () {
      expect(probe.hasImage, isTrue);
      expect(
        probe.dimensiGambar,
        contains((w: 898, h: 449)),
        reason: 'latar harus gambar desain 898x449 px (rasio 2:1)',
      );
    });

    test('lima nilai data tercetak', () {
      final t = probe.teksGabung;
      expect(t, contains('Canoni-SENSYSLBP226dw'), reason: 'Nama Barang');
      expect(t, contains('IT'), reason: 'Bagian');
      expect(t, contains('Eky'), reason: 'Nama PIC');
      expect(t, contains('PR-001'), reason: 'Kode Unit');
      expect(t, contains('20/10/2025'), reason: 'Tanggal Penyerahan');
      // Kolom Keterangan tidak ada di desain, jadi tidak boleh tercetak.
      expect(
        t,
        isNot(contains('UnitAktif')),
        reason: 'desain tidak punya kolom Keterangan',
      );
    });

    test('teks memakai font Carlito-Bold (bukan Helvetica)', () {
      // Font desain adalah Calibri-Bold yang tidak boleh disertakan karena
      // proprietary; penggantinya Carlito-Bold, klon metrik-identik.
      expect(
        probe.raw.contains('Carlito-Bold'),
        isTrue,
        reason: 'file PDF harus menyematkan subset Carlito-Bold',
      );
      expect(probe.raw.contains('Helvetica'), isFalse);
    });

    test('posisi tiap nilai mengikuti desain', () {
      // (x dari tepi kiri, baseline dari tepi bawah) hasil ukur content stream.
      const desain = <List<double>>[
        [15.82, 28.24], // Nama Barang       (44,832 pt, baseline 80,051 pt)
        [15.74, 24.35], // Bagian            (44,623 pt, baseline 69,023 pt)
        [15.69, 19.53], // Nama PIC          (44,478 pt, baseline 55,347 pt)
        [53.96, 28.55], // Kode Unit         (152,945 pt, baseline 80,918 pt)
        [48.07, 14.69], // Tanggal Penyerahan(136,248 pt, baseline 41,623 pt)
      ];
      for (final d in desain) {
        final ada = probe.items.any(
          (e) =>
              (e.xMm - d[0]).abs() < toleransi &&
              (e.yMm - d[1]).abs() < toleransi,
        );
        expect(
          ada,
          isTrue,
          reason: 'tidak ada teks di x=${d[0]}, y=${d[1]}',
        );
      }
      // Tanggal Penyerahan tidak boleh lagi tercetak di bawah Kode Unit.
      final salah = probe.items.any(
        (e) =>
            (e.xMm - 53.96).abs() < toleransi &&
            (e.yMm - 24.35).abs() < toleransi,
      );
      expect(salah, isFalse, reason: 'tanggal tidak boleh di bawah Kode Unit');
    });

    test('ukuran huruf mengikuti desain 6 pt', () {
      for (final e in probe.items) {
        // Boleh mengecil kalau kolom sempit, tapi tidak boleh lebih besar
        // dari desain dan tidak boleh turun di bawah batas 3 pt.
        expect(e.fontSizePt, lessThanOrEqualTo(6.05), reason: '"${e.text}"');
        expect(e.fontSizePt, greaterThanOrEqualTo(3.0), reason: '"${e.text}"');
      }
      // Nilai pendek tidak perlu dikecilkan, jadi tetap tepat 6 pt.
      final pic = probe.items.firstWhere((e) => e.text == 'Eky');
      expect(pic.fontSizePt, closeTo(6.0, 0.01));
    });

    test('tidak ada teks keluar kertas', () {
      for (final e in probe.items) {
        expect(e.xMm, greaterThanOrEqualTo(0), reason: '"${e.text}" di kiri');
        expect(e.xMm, lessThan(76.03), reason: '"${e.text}" di kanan');
        expect(e.yMm, greaterThan(0), reason: '"${e.text}" di bawah');
        expect(e.yMm, lessThan(38.02), reason: '"${e.text}" di atas');
      }
    });

    test('tanpa barcode dan QR', () {
      expect(probe.raw.contains('/Type /Barcode'), isFalse);
      expect(probe.raw.contains('BWSC'), isFalse);
    });
  });

  test('kategori printer memakai stiker printer, selainnya stiker biasa', () async {
    // Varian penulisan kategori di database tetap dianggap printer.
    for (final cat in <String>['Printer', 'printer', 'Printer Laser']) {
      final probe = PdfProbe.fromBytes(
        await StickerPdfService.instance
            .buildSticker(contohPrinter()..category = cat),
      );
      expect(
        probe.mediaBox!.width,
        closeTo(76.03, toleransi),
        reason: '"$cat" harus memakai label printer',
      );
      expect(
        probe.dimensiGambar,
        contains((w: 898, h: 449)),
        reason: '"$cat" harus memakai latar desain printer',
      );
    }

    // Komputer tetap memakai stiker 155 x 60 mm.
    final pc = PdfProbe.fromBytes(
      await StickerPdfService.instance.buildSticker(contoh()),
    );
    expect(pc.mediaBox!.width, closeTo(155, toleransi));
    expect(pc.teksGabung, contains('Inventaris&Spesifikasi'));
  });

  test('stiker printer: model panjang dikecilkan tapi tetap utuh', () async {
    // Panjang realistis untuk model printer: masih muat di kolom 28 mm.
    final panjang = 'HP LaserJet Enterprise MFP M428fdw';
    final probe = PdfProbe.fromBytes(
      await StickerPdfService.instance.buildSticker(
        contohPrinter(model: panjang, kode: 'IT-PR-2026-0001'),
      ),
    );
    expect(probe.teksGabung, contains(panjang.replaceAll(' ', '')));
    expect(probe.teksGabung, contains('IT-PR-2026-0001'));
    // Hurufnya harus benar-benar mengecil, bukan overflowing.
    final model = probe.items.firstWhere(
      (e) => (e.yMm - 28.24).abs() < toleransi,
    );
    expect(model.fontSizePt, lessThan(6.0));
    for (final e in probe.items) {
      expect(e.xMm, lessThan(76.03), reason: '"${e.text}" keluar kanan');
    }
  });

  test('stiker printer: nilai ekstrem tetap di dalam kertas', () async {
    final probe = PdfProbe.fromBytes(
      await StickerPdfService.instance.buildSticker(
        contohPrinter(
          model:
              'HP LaserJet Enterprise MFP M428fdw Mono Laser Printer Duplex',
          kode: 'IT-PR-2026-0001-VERY-LONG-CODE',
        ),
      ),
    );
    // Teks sepanjang itu memang tidak muat di kolom sempit, tapi PDF harus
    // tetap valid dan tidak ada isi yang keluar dari area cetak.
    for (final e in probe.items) {
      expect(e.fontSizePt, greaterThanOrEqualTo(3.0), reason: '"${e.text}"');
      expect(e.xMm, greaterThanOrEqualTo(0), reason: '"${e.text}" di kiri');
      expect(e.xMm, lessThan(76.03), reason: '"${e.text}" di kanan');
      expect(e.yMm, greaterThan(0), reason: '"${e.text}" di bawah');
      expect(e.yMm, lessThan(38.02), reason: '"${e.text}" di atas');
    }
    // Keterangan tidak boleh dicetak (desain tidak punya kolomnya).
    expect(probe.teksGabung, isNot(contains('UnitAktif')));
  });

  test('stiker printer: data kosong tidak membuat PDF gagal', () async {
    final probe = PdfProbe.fromBytes(
      await StickerPdfService.instance.buildSticker(Device(category: 'Printer')),
    );
    expect(probe.mediaBox!.width, closeTo(76.03, toleransi));
    expect(probe.dimensiGambar, contains((w: 898, h: 449)));
    // Lima slot kosong tetap ditulis sebagai "-".
    expect(probe.items.where((e) => e.text == '-').length, 5);
  });

  test('kode inventaris panjang tetap muat dan tidak terpotong', () async {
    final bytes = await StickerPdfService.instance.buildSticker(
      contoh(kode: 'IT-LAP-2026-0001-VERY-LONG-CODE'),
    );
    final probe = PdfProbe.fromBytes(bytes);
    expect(probe.teksGabung, contains('IT-LAP-2026-0001-VERY-LONG-CODE'));
    for (final e in probe.items) {
      expect(e.xMm, greaterThanOrEqualTo(0), reason: '"${e.text}" di kiri');
      expect(e.xMm, lessThan(155), reason: '"${e.text}" di kanan');
    }
  });

  test('prosesor panjang mengecilkan huruf, bukan terpotong', () async {
    final panjang = 'AMD Ryzen Threadripper 3970X 32-Core Processor Socket AM4';
    final bytes = await StickerPdfService.instance.buildSticker(
      contoh(processor: panjang),
    );
    final probe = PdfProbe.fromBytes(bytes);
    expect(probe.teksGabung, contains(panjang.replaceAll(' ', '')));
    for (final e in probe.items) {
      expect(e.xMm, greaterThanOrEqualTo(0));
      expect(e.xMm, lessThan(155), reason: '"${e.text}" di kanan');
    }
  });

  test('data kosong tidak membuat PDF gagal', () async {
    final bytes = await StickerPdfService.instance.buildSticker(Device());
    final probe = PdfProbe.fromBytes(bytes);
    expect(probe.mediaBox!.width, closeTo(155, toleransi));
    expect(probe.items, isNotEmpty);
  });
}
