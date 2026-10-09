/// Nomor kode inventaris berikutnya yang bebas, dimulai dari 1.
///
/// Fungsi ini dipakai oleh `nextKode` (lokal maupun cloud) supaya saat sebuah
/// kode dihapus (misal K-003), penambahan berikutnya otomatis mengisi nomor
/// kosong terkecil itu lebih dulu alih-alih langsung ke nomor terakhir + 1.
int nomorKodeBebas(Iterable<int> terpakai) {
  final used = terpakai.toSet();
  var n = 1;
  while (used.contains(n)) {
    n++;
  }
  return n;
}