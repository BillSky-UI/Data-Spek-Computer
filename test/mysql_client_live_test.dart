import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:spek_komputer/database/mysql_client.dart';

/// Uji integrasi NYATA terhadap `backend/api.php` yang sedang berjalan.
///
/// Secara default dilewati. Aktifkan hanya saat menguji backend lokal:
///   php -S 127.0.0.1:8099 -t backend   (config.php dengan DSN sqlite)
///   $env:MYSQL_TEST_URL="http://127.0.0.1:8099/backend"
///   $env:MYSQL_TEST_KEY="rahasia123"
///   flutter test test/mysql_client_live_test.dart
void main() {
  test('round-trip penuh ke backend/api.php', () async {
    final url = Platform.environment['MYSQL_TEST_URL'] ?? '';
    if (url.isEmpty) {
      markTestSkipped('MYSQL_TEST_URL kosong — lewati uji live API.');
      return;
    }
    final key = Platform.environment['MYSQL_TEST_KEY'] ?? '';

    final api = CloudApi(baseUrl: url, apiKey: key);

    await api.ping();
    await api.migrate();
    await api.migrate(); // idempoten

    // Upsert: baris baru, lalu baris yang sama (case-insensitive bagikan nama).
    final up1 = await api.upsert('bagian', [
      {'name': 'Probe'},
    ], onConflict: 'name');
    final up2 = await api.upsert('bagian', [
      {'name': 'probe'},
    ], onConflict: 'name');

    // Insert + select.
    final ins = await api.insert('devices', [
      {'kode_inventaris': 'PR-001', 'device_name': 'Perangkat Probe', 'bagian': 'Probe'},
    ], returning: true);
    final id = (ins.first['id'] as num).toInt();
    expect(id, greaterThan(0));

    final rows = await api.select('devices',
        where: [CloudApi.eq('kode_inventaris', 'pr-001')], limit: 5);
    expect(rows, isNotEmpty);

    // Update + delete.
    final aff = await api.update('devices', {'device_name': 'Probe Renamed'},
        [CloudApi.eq('id', id)]);
    expect(aff, 1);
    final del = await api.delete('devices', [CloudApi.eq('id', id)]);
    expect(del, 1);

    // Guard: hapus master Probe, lalu verifikasi rev bertambah.
    await api.delete('bagian', [CloudApi.eq('name', 'Probe')]);
    final rev1 = (await api.rev())['rev'] as num;
    expect(rev1, isNotNull);

    // Sanity: nilai upsert benar (baris kedua = update, bukan insert).
    expect(up1['updated'], 0);
    expect(up2['updated'], greaterThanOrEqualTo(1));

    // Galat: update tanpa diizinkan harus menolak.
    await expectLater(
      api.delete('devices', const []),
      throwsA(isA<ApiException>()),
    );
  });
}