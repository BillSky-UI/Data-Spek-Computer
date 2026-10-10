import 'package:flutter_test/flutter_test.dart';

import 'package:spek_komputer/models/device.dart';
import 'package:spek_komputer/services/report_pdf_service.dart';

void main() {
  test('buildReport menghasilkan PDF valid untuk data campuran', () async {
    final devices = [
      Device(
        kodeInventaris: 'C-001',
        deviceName: 'PC A',
        category: 'Komputer',
        bagian: 'IT',
        ram: '8GB',
        storage: '256GB',
        prosesor: 'Core i5',
      ),
      Device(
        kodeInventaris: 'L-001',
        deviceName: 'Laptop B',
        category: 'Laptop',
        bagian: 'HRD',
      ),
      Device(
        kodeInventaris: 'P-001',
        deviceName: 'Printer C',
        category: 'Printer',
        bagian: 'Finance',
        prosesor: 'LaserJet',
      ),
    ];

    final bytes = await ReportPdfService.instance
        .buildReport(devices, subtitle: 'Bagian IT');

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
  });

  test('buildReport tetap menghasilkan PDF walau daftar kosong', () async {
    final bytes = await ReportPdfService.instance.buildReport(const []);
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
  });
}
