import 'package:flutter_test/flutter_test.dart';

import 'package:spek_komputer/utils/kode_generator.dart';

void main() {
  test('kosong memulai dari nomor 1', () {
    expect(nomorKodeBebas([]), 1);
  });

  test('mengisi nomor kosong terkecil (bukan maks + 1)', () {
    // K-001, K-002, K-004 terpakai -> K-003 yang hilang diisi dulu.
    expect(nomorKodeBebas([1, 2, 4]), 3);
  });

  test('mengisi kembali kode yang pernah dihapus', () {
    // K-003 dihapus -> penambahan berikutnya memakai 3 lagi.
    expect(nomorKodeBebas([1, 2, 4, 5]), 3);
  });

  test('tanpa lubang memakai nomor setelah yang terakhir', () {
    expect(nomorKodeBebas([1, 2, 3, 4, 5]), 6);
  });

  test('nomor ganda dan tak berurutan diperlakukan sama', () {
    expect(nomorKodeBebas([9, 1, 1, 3, 2, 5]), 4);
  });
}