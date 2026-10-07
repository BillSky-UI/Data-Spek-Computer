import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../env/app_config.dart';

/// Galat dari server API (HTTP status != 2xx) atau galat transpor.
class ApiException implements Exception {
  const ApiException(this.message, {this.status});

  /// Pesan `error` dari respon server bila ada, selain itu deskripsi umum.
  final String message;

  /// Kode HTTP (kicuali null untuk galat jaringan/timeout/manajemen).
  final int? status;

  @override
  String toString() => message;
}

/// Klien REST untuk `backend/api.php`.
///
/// Kontrak op yang dikirim (`backend/api.php?op=...`):
///   - `ping`, `rev`, `migrate`
///   - `select`  → `rows`
///   - `insert`  → `count` (+ `rows` bila `returning`)
///   - `update`  → `affected`
///   - `delete`  → `affected`
///   - `upsert`  → `inserted` / `updated`
///
/// Semua request memakai header `X-Api-Key` bila kunci terisi.
class CloudApi {
  CloudApi({String? baseUrl, String? apiKey, http.Client? client})
      : _client = client ?? http.Client(),
        _apiKey = (apiKey ?? AppConfig.apiKey).trim(),
        _baseUrl = _normalizeBase(baseUrl ?? AppConfig.apiBase);

  static const Duration _timeout = Duration(seconds: 20);
  static const String _opPath = 'api.php';

  final http.Client _client;
  final String _apiKey;
  final String _baseUrl;

  static String _normalizeBase(String raw) {
    var base = raw.trim();
    if (base.isEmpty) return '';
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    return base;
  }

  Uri _uri(String op) {
    final base = _baseUrl;
    if (base.isEmpty) {
      throw const ApiException('URL API cloud belum dikonfigurasi.');
    }
    var raw = base;
    if (!raw.endsWith(_opPath)) {
      raw = raw.endsWith('/') ? '$raw$_opPath' : '$raw/$_opPath';
    }
    return Uri.parse(raw).replace(queryParameters: {'op': op});
  }

  Map<String, String> _headers() => <String, String>{
        'Content-Type': 'application/json',
        if (_apiKey.isNotEmpty) 'X-Api-Key': _apiKey,
      };

  Future<Map<String, dynamic>> _op(
    String op, [
    Map<String, dynamic>? body,
  ]) async {
    final res = await _client
        .post(
          _uri(op),
          headers: _headers(),
          body: body == null ? null : jsonEncode({'op': op, ...body}),
        )
        .timeout(_timeout);

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw ApiException(
        'Respon server tidak valid (HTTP ${res.statusCode}): '
        '${utf8.decode(res.bodyBytes, allowMalformed: true)}',
        status: res.statusCode,
      );
    }

    final ok = data['ok'] == true;
    if (res.statusCode >= 200 && res.statusCode < 300 && ok) return data;
    throw ApiException(
      (data['error'] as String?) ?? 'Galat server (HTTP ${res.statusCode}).',
      status: res.statusCode,
    );
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> data) =>
      ((data['rows'] as List?) ?? const [])
          .map((r) => (r as Map).cast<String, dynamic>())
          .toList();

  // ============================================================
  //  PEMBANTU FILTER WHERE (op = / != / IN)
  // ============================================================

  static Map<String, dynamic> eq(String col, Object? value) =>
      {'col': col, 'op': '=', 'value': value};

  static Map<String, dynamic> ne(String col, Object? value) =>
      {'col': col, 'op': '!=', 'value': value};

  static Map<String, dynamic> inList(String col, List<Object?> values) =>
      {'col': col, 'op': 'IN', 'values': values};

  // ============================================================
  //  OP DASAR
  // ============================================================

  /// Uji koneksi + validasi kunci API.
  Future<void> ping() async {
    await _op('ping');
  }

  /// Revisi data (token polling) + jumlah baris per tabel.
  Future<Map<String, dynamic>> rev() async {
    return _op('rev');
  }

  /// Buat tabel bila belum ada (idempoten, `CREATE TABLE IF NOT EXISTS`).
  Future<void> migrate() async {
    await _op('migrate');
  }

  Future<List<Map<String, dynamic>>> select(
    String table, {
    List<String>? columns,
    List<Map<String, dynamic>>? where,
    String? orderBy,
    String? orderDir,
    int? limit,
  }) async {
    final data = await _op('select', <String, dynamic>{
      'table': table,
      if (columns != null && columns.isNotEmpty) 'columns': columns,
      if (where != null && where.isNotEmpty) 'where': where,
      if (orderBy != null && orderBy.isNotEmpty)
        'order': {'by': orderBy, if (orderDir != null && orderDir.isNotEmpty) 'dir': orderDir},
      if (limit != null && limit > 0) 'limit': limit,
    });
    return _rows(data);
  }

  Future<List<Map<String, dynamic>>> insert(
    String table,
    List<Map<String, dynamic>> rows, {
    bool returning = false,
  }) async {
    final data = await _op('insert', <String, dynamic>{
      'table': table,
      'rows': rows,
      if (returning) 'returning': true,
    });
    return _rows(data);
  }

  Future<int> update(
    String table,
    Map<String, dynamic> set,
    List<Map<String, dynamic>> where,
  ) async {
    final data = await _op('update', <String, dynamic>{
      'table': table,
      'set': set,
      'where': where,
    });
    return (data['affected'] as num?)?.toInt() ?? 0;
  }

  Future<int> delete(
    String table,
    List<Map<String, dynamic>> where,
  ) async {
    final data = await _op('delete', <String, dynamic>{
      'table': table,
      'where': where,
    });
    return (data['affected'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>> upsert(
    String table,
    List<Map<String, dynamic>> rows, {
    String? onConflict,
  }) async {
    return _op('upsert', <String, dynamic>{
      'table': table,
      'rows': rows,
      if (onConflict != null && onConflict.isNotEmpty)
        'on_conflict': onConflict,
    });
  }
}