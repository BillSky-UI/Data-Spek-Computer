import 'package:flutter_test/flutter_test.dart';

import 'package:spek_komputer/models/device.dart';
import 'package:spek_komputer/utils/device_diff.dart';

void main() {
  Device dasar({String bagian = 'HRD', String storage = '256GB'}) => Device(
        kodeInventaris: 'K-001',
        deviceName: 'PC 1',
        bagian: bagian,
        storage: storage,
      );

  test('diffDevice kosong bila tidak ada perubahan', () {
    expect(diffDevice(dasar(), dasar()), '');
  });

  test('diffDevice menampilkan satu kolom yang berubah', () {
    final diff = diffDevice(dasar(), dasar(bagian: 'Keuangan'));
    expect(diff, 'Bagian: HRD → Keuangan');
  });

  test('diffDevice menggabungkan beberapa kolom dengan pemisah ;', () {
    final diff = diffDevice(dasar(), dasar(bagian: 'Keuangan', storage: '512GB'));
    expect(diff, contains('Bagian: HRD → Keuangan'));
    expect(diff, contains('Storage: 256GB → 512GB'));
    expect(diff, 'Bagian: HRD → Keuangan; Storage: 256GB → 512GB');
  });

  test('diffDevice menampilkan (kosong) bila nilai lama kosong', () {
    final zero = Device(kodeInventaris: 'K-001', deviceName: 'PC 1');
    final diff = diffDevice(zero, dasar());
    expect(diff, contains('Bagian: (kosong) → HRD'));
  });

  test('diffDevice menangani lama null → kosong', () {
    expect(diffDevice(null, dasar()), '');
  });
}