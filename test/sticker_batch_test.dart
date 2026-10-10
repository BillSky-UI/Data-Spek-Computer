import 'package:flutter_test/flutter_test.dart';

import 'package:spek_komputer/models/device.dart';
import 'package:spek_komputer/services/sticker_pdf_service.dart';

void main() {
  Device pc() => Device(
        kodeInventaris: 'K-030',
        deviceName: 'PC A',
        category: 'Komputer',
        bagian: 'IT',
        motherboard: 'H81M-K',
        prosesor: 'Core i5',
        ram: '16 GBytes',
        storage: '256GB SSD',
      );

  Device printer() => Device(
        kodeInventaris: 'P-010',
        deviceName: 'Budi',
        category: 'Printer',
        bagian: 'Finance',
        prosesor: 'Epson L3210',
        tanggalEvaluasi: '10/10/2026',
      );

  test('buildStickerBatch menghasilkan satu PDF berisi banyak stiker', () async {
    final bytes = await StickerPdfService.instance
        .buildStickerBatch([pc(), pc(), printer()]);

    expect(bytes.length, greaterThan(2000));
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
  });

  test('buildStickerBatch tetap valid walau campuran hanya printer', () async {
    final bytes = await StickerPdfService.instance
        .buildStickerBatch([printer(), printer()]);
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
  });

  test('buildStickerBatch menghasilkan PDF valid untuk daftar kosong', () async {
    final bytes =
        await StickerPdfService.instance.buildStickerBatch(const []);
    expect(bytes.isNotEmpty, isTrue);
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
  });
}