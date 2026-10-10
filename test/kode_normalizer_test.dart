import 'package:flutter_test/flutter_test.dart';

import 'package:spek_komputer/utils/kode_normalizer.dart';

void main() {
  test('canonicalKode normalisasi format toleran (K-035 == K-0035)', () {
    expect(canonicalKode('K-035'), 'K-035');
    expect(canonicalKode('K-0035'), 'K-035');
    expect(canonicalKode('k-35'), 'K-035');
    expect(canonicalKode('K 035'), 'K-035');
    expect(canonicalKode('  K-0035\t'), 'K-035');
  });

  test('canonicalKode menangani semua prefix kategori', () {
    expect(canonicalKode('l-1'), 'L-001');
    expect(canonicalKode('P-0120'), 'P-120');
    expect(canonicalKode('K-030'), 'K-030');
  });

  test('canonicalKode membiarkan input tanpa format kode', () {
    expect(canonicalKode('PC-123'), 'PC-123');
    expect(canonicalKode(''), '');
  });
}