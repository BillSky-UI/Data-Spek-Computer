/// Konfigurasi koneksi Cloud Database (Supabase).
///
/// Isi nilai saat build:
///   flutter build apk --release \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
abstract final class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR-PROJECT.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_PUBLIC_ANON_KEY',
  );

  /// Base URL halaman web publik untuk mode "scan tanpa aplikasi".
  ///
  /// Jika diisi (misal https://nama-proyek.netlify.app), QR Code pada stiker
  /// akan berisi `PUBLIC_BASE_URL?kode=K-001` sehingga kamera HP standar
  /// langsung membuka halaman detail perangkat tanpa menginstal aplikasi.
  static const String publicBaseUrl = String.fromEnvironment(
    'PUBLIC_BASE_URL',
    defaultValue: '',
  );

  static bool get hasPublicBaseUrl =>
      publicBaseUrl.isNotEmpty &&
      (publicBaseUrl.startsWith('http://') ||
          publicBaseUrl.startsWith('https://'));

  /// Isi QR Code stiker: tautan publik bila dikonfigurasi, selain itu
  /// langsung Kode Inventaris (kompatibel dengan scanner internal).
  static String qrPayload(String kode) {
    if (!hasPublicBaseUrl) return kode;
    final base =
        publicBaseUrl.endsWith('/') ? publicBaseUrl : '$publicBaseUrl/';
    return '$base?kode=${Uri.encodeComponent(kode)}';
  }

  static bool get isConfigured =>
      !supabaseUrl.contains('YOUR-PROJECT') &&
      !supabaseAnonKey.contains('YOUR_PUBLIC');
}