import 'package:flutter/foundation.dart';

/// Konfigurasi koneksi Cloud Database (MySQL + REST API PHP).
///
/// Isi nilai saat build:
///   flutter build apk --release \
///     --dart-define=MYSQL_API_URL=https://domain.com/backend \
///     --dart-define=MYSQL_API_KEY=rahasia-anda
///
/// Di web, URL bisa relatif (mis. "backend") terhadap origin halaman yang
/// dibuka, dan dapat ditimpa runtime melalui file `web/config.json`:
///   {
///     "mysqlApiUrl": "https://domain.com/backend",
///     "mysqlApiKey": "rahasia-anda"
///   }
/// `config.json` di-fetch di `main()` sebelum inisialisasi database.
abstract final class AppConfig {
  static const String mysqlApiUrl = String.fromEnvironment(
    'MYSQL_API_URL',
    defaultValue: '',
  );

  static const String mysqlApiKey = String.fromEnvironment(
    'MYSQL_API_KEY',
    defaultValue: '',
  );

  /// Override runtime (dari web/config.json).
  static String? _runtimeUrl;
  static String? _runtimeKey;

  static void applyRuntimeConfig({
    String? mysqlApiUrl,
    String? mysqlApiKey,
  }) {
    if (mysqlApiUrl != null && mysqlApiUrl.trim().isNotEmpty) {
      _runtimeUrl = mysqlApiUrl.trim();
    }
    if (mysqlApiKey != null && mysqlApiKey.trim().isNotEmpty) {
      _runtimeKey = mysqlApiKey.trim();
    }
  }

  static String? get runtimeUrl => _runtimeUrl;
  static String? get runtimeKey => _runtimeKey;

  /// Base URL folder backend (berisi api.php) yang dipakai aplikasi.
  static String get apiBase {
    final overridden = _runtimeUrl;
    if (overridden != null && overridden.isNotEmpty) return overridden;

    final fromEnv = mysqlApiUrl.trim();
    if (fromEnv.isNotEmpty) return fromEnv;

    // Di web, bila tidak dikonfigurasi, coba relatif ke origin halaman
    // ("backend/api.php" se-folder dengan halaman yang dibuka).
    if (kIsWeb) {
      final origin = Uri.base;
      if (origin.scheme == 'http' || origin.scheme == 'https') {
        return 'backend';
      }
    }
    return '';
  }

  static String get apiKey {
    final overridden = _runtimeKey;
    if (overridden != null && overridden.isNotEmpty) return overridden;
    return mysqlApiKey;
  }

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

  /// `true` bila konfigurasi cloud tersedia (baik dart-define maupun runtime).
  static bool get isConfigured => apiBase.isNotEmpty;
}