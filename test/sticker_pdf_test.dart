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
      expect(probe.dimensiGambar, {
        (w: 623, h: 400),
        (w: 12368, h: 9966),
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
