/// Normalisasi kode inventaris untuk pembandingan yang toleran format.
///
/// Kode dianggap sama walau beda format: huruf besar-kecil, spasi, dan jumlah
/// digit (angka diisi nol depan menjadi 3 digit). Contoh:
///   "K-0035", "k-35", "K 035"  -> semuanya menjadi "K-035"
String canonicalKode(String raw) {
  final s = raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  final m = RegExp(r'^([A-Z]+)-?(\d+)$').firstMatch(s);
  if (m == null) return s;
  final n = int.tryParse(m.group(2)!) ?? 0;
  if (n <= 0) return s;
  return '${m.group(1)}-${n.toString().padLeft(3, '0')}';
}