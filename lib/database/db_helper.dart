import 'dart:async';

import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../env/app_config.dart';
import '../models/device.dart';
import '../services/pin_controller.dart';
import '../utils/kode_generator.dart';
import 'local_database.dart';

/// Hasil operasi hapus master (Bagian/PLAN).
///
/// [dipakai] berisi jumlah perangkat yang masih memakai nama tersebut, sehingga
/// hapus ditolak dan UI bisa menjelaskan alasannya. [sudahAda] true bila nama
/// baru bentrok dengan master lain (kolom `name` UNIQUE).
class MasterHapusResult {
  const MasterHapusResult({
    required this.berhasil,
    this.dipakai = 0,
    this.sudahAda = false,
  });

  final bool berhasil;
  final int dipakai;
  final bool sudahAda;
}

/// Hasil operasi edit master (Bagian/PLAN).
///
/// [perangkatDiperbarui] = jumlah perangkat yang ikut di-rename mengikuti
/// master yang diedit, sehingga data tidak lagi menunjuk nama lama.
class MasterUbahResult {
  const MasterUbahResult({
    required this.berhasil,
    this.perangkatDiperbarui = 0,
    this.sudahAda = false,
  });

  final bool berhasil;
  final int perangkatDiperbarui;
  final bool sudahAda;
}

/// Dua nilai string dianggap sama bila berbeda hanya spasi / huruf besar-kecil.
bool _samaNama(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();

/// Repository data: Cloud (Supabase) + real-time, atau Local (SQLite) jika
/// Supabase belum dikonfigurasi / gagal terhubung.
///
/// Saat mode lokal aktif, aplikasi otomatis men-seed data dari Excel
/// ("assets/seed_inventaris.xlsx", sheet 'Spesifikasi Komputer')
/// ke SQLite sehingga daftar perangkat langsung terisi tanpa banner error.
///
/// Nama file aset sengaja tanpa spasi: build web menaruh aset dengan nama
/// ter-URL-encode (`%20`), sedangkan server statis (Vercel/Netlify/Express)
/// mendekode-nya kembali menjadi spasi sehingga file tidak ditemukan.
///
/// Menjadi ChangeNotifier: tiap perubahan dari Cloud/lokal langsung memicu
/// rebuild seluruh halaman yang mendengarkan.
///
/// Nama method dipertahankan kompatibel dengan aplikasi sebelumnya sehingga
/// minimal mengubah kode pemanggil.
class DbHelper extends ChangeNotifier {
  DbHelper._();
  static final DbHelper instance = DbHelper._();

  // ----- Tabel (cloud, lihat supabase/schema.sql) -----
  static const String _tDevices = 'devices';
  static const String _tBagian = 'bagian';
  static const String _tPlan = 'plan';
  static const String _tSettings = 'app_settings';

  static const String _assetExcel = 'assets/seed_inventaris.xlsx';
  static const String _sheetName = 'Spesifikasi Komputer';

  SupabaseClient? _client;

  // ----- State cache (real-time) -----
  List<Device> _devices = [];
  List<Map<String, dynamic>> _bagianRows = [];
  List<String> _bagianMaster = [];
  List<String> _planMaster = [];
  String? _cachedPinHash;

  bool synced = false;
  String? lastError;

  /// `true` saat berjalan di SQLite lokal (Supabase tidak dikonfigurasi/gagal).
  bool localMode = false;

  StreamSubscription<List<Map<String, dynamic>>>? _subDev;
  StreamSubscription<List<Map<String, dynamic>>>? _subBag;
  StreamSubscription<List<Map<String, dynamic>>>? _subSet;

  bool get cloudReady => _client != null;
  List<Device> get devices => List.unmodifiable(_devices);

  // ============================================================
  //  INISIALISASI & REALTIME
  // ============================================================

  /// Hubungkan ke Supabase, muat data awal, pasang subscription real-time.
  /// Jika cloud tidak dikonfigurasi atau gagal terhubung → beralih ke SQLite
  /// lokal dan men-seed data dari Excel (tanpa banner error merah).
  Future<void> initCloud() async {
    lastError = null;

    if (AppConfig.isConfigured == false) {
      await _initLocalMode('Konfigurasi cloud belum diisi — memakai database lokal.');
      return;
    }

    try {
      _client = Supabase.instance.client;
      await _fetchAll();
      await _ensureMastersFromDevices();

      _subDev = _client!.from(_tDevices).stream(primaryKey: ['id']).listen(
        (rows) {
          _devices = rows.map(Device.fromMap).toList()..sort(_byKode);
          _derivePlanMaster();
          notifyListeners();
        },
        onError: (Object e) {
          lastError = '$e';
          notifyListeners();
        },
      );

      _subBag = _client!.from(_tBagian).stream(primaryKey: ['id']).listen(
        (rows) {
          _bagianRows = rows;
          _bagianMaster = rows
              .map((r) => (r['name'] ?? '').toString())
              .where((n) => n.trim().isNotEmpty)
              .toList()
            ..sort();
          notifyListeners();
        },
        onError: (Object e) {
          lastError = '$e';
          notifyListeners();
        },
      );

      // PIN tersinkronisasi: ubah di satu perangkat → semua perangkat ikut.
      _subSet = _client!
          .from(_tSettings)
          .stream(primaryKey: ['id'])
          .eq('id', 1)
          .listen(
        (rows) {
          if (rows.isNotEmpty) {
            _cachedPinHash = (rows.first['pin_hash'] ?? '').toString();
          }
          notifyListeners();
        },
        onError: (Object e) {
          lastError = '$e';
          notifyListeners();
        },
      );

      synced = true;
      lastError = null;
    } catch (e) {
      _client = null;
      await _initLocalMode('Gagal tersambung cloud ($e) — memakai database lokal.');
      return;
    }
    notifyListeners();
  }

  /// Aktifkan mode lokal (SQLite): seed dari Excel bila kosong lalu isi cache.
  Future<void> _initLocalMode(String reason) async {
    localMode = true;
    lastError = null;
    synced = false;
    debugPrintFallback('[DbHelper] $reason');
    try {
      final fromExcel = await loadExcelSeed();
      await LocalDatabase.instance.seedIfEmpty(fromExcel);
      await _reloadLocalCache();
      synced = true;
    } catch (e) {
      lastError = '$e';
      debugPrintFallback('[DbHelper] Gagal init lokal: $e');
    }
    notifyListeners();
  }

  /// Muat ulang seluruh cache dari SQLite lokal.
  Future<void> _reloadLocalCache() async {
    final local = LocalDatabase.instance;
    _devices = await local.getAll();
    _bagianMaster = await local.getBagianMaster();
    _planMaster = await local.getPlanMaster();
    _bagianRows = _bagianMaster.map((n) => <String, dynamic>{'name': n}).toList();
    _cachedPinHash = null;
  }

  Future<void> _fetchAll() async {
    if (_client == null) return;
    final devRows = await _client!.from(_tDevices).select().order('id');
    _devices = devRows.map(Device.fromMap).toList()..sort(_byKode);

    final bagRows = await _client!.from(_tBagian).select().order('name');
    _bagianRows = bagRows;
    _bagianMaster = bagRows
        .map((r) => (r['name'] ?? '').toString())
        .where((n) => n.trim().isNotEmpty)
        .toList()
      ..sort();

    // Plan master diambil dari tabel plan, bukan hanya dari perangkat,
    // supaya plan yang belum dipakai perangkat tetap ikut terhitung.
    try {
      final planRows = await _client!.from(_tPlan).select(
        'name',
      );
      _planMaster = planRows
          .map((r) => (r['name'] ?? '').toString())
          .where((n) => n.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    } catch (_) {
      // tabel plan belum tersedia -> andalkan plan dari perangkat
    }
    _derivePlanMaster();

    final setRows = await _client!
        .from(_tSettings)
        .select('pin_hash')
        .eq('id', 1)
        .maybeSingle();
    if (setRows != null) {
      _cachedPinHash = (setRows['pin_hash'] ?? '').toString();
    }
  }

  void _derivePlanMaster() {
    // Plan manual (ditambah user) tetap dipertahankan, digabung dengan
    // plan yang benar-benar dipakai perangkat.
    final all = <String>{
      ..._planMaster.where((p) => p.trim().isNotEmpty),
      ..._devices.map((d) => d.plan).where((p) => p.trim().isNotEmpty),
    };
    _planMaster = all.toList()..sort();
  }

  @override
  void dispose() {
    for (final s in [_subDev, _subBag, _subSet]) {
      s?.cancel();
    }
    super.dispose();
  }

  // ============================================================
  //  CRUD PERANGKAT (Cloud, sinkron real-time)
  // ============================================================

  Future<List<Device>> getAll() async {
    if (localMode) {
      if (_devices.isEmpty) await _reloadLocalCache();
      return devices;
    }
    if (_devices.isEmpty && _client != null) {
      await _fetchAll();
    }
    return devices;
  }

  Future<int> insert(Device d) async {
    if (localMode) return _insertLocal(d);
    if (_client == null) return 0;
    final payload = {...d.toMap()}..remove('id');
    final rows = await _client!.from(_tDevices).insert(payload).select();
    if (rows.isNotEmpty) {
      _upsertLocal(Device.fromMap(rows.first));
      _derivePlanMaster();
      notifyListeners();
      await _ensureMastersFromDevices();
      return (rows.first['id'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  Future<int> _insertLocal(Device d) async {
    final id = await LocalDatabase.instance.insert(d);
    await _reloadLocalCache();
    notifyListeners();
    return id;
  }

  Future<int> update(Device d) async {
    if (localMode) {
      final r = await LocalDatabase.instance.update(d);
      await _reloadLocalCache();
      notifyListeners();
      return r > 0 ? 1 : 0;
    }
    if (_client == null || d.id == null) return 0;
    final payload = {...d.toMap()}..remove('id');
    await _client!.from(_tDevices).update(payload).eq('id', d.id!);
    _upsertLocal(d);
    _derivePlanMaster();
    notifyListeners();
    return 1;
  }

  Future<int> delete(int id) async {
    if (localMode) {
      final n = await LocalDatabase.instance.delete(id);
      await _reloadLocalCache();
      notifyListeners();
      return n > 0 ? 1 : 0;
    }
    if (_client == null) return 0;
    await _client!.from(_tDevices).delete().eq('id', id);
    _devices.removeWhere((d) => d.id == id);
    _derivePlanMaster();
    notifyListeners();
    return 1;
  }

  Future<Device?> getByKode(String kode) async {
    if (localMode) return LocalDatabase.instance.getByKode(kode);
    final normalized = kode.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
    if (normalized.isEmpty) return null;
    for (final d in _devices) {
      if (d.kodeInventaris
          .trim()
          .replaceAll(RegExp(r'\s+'), '')
          .toLowerCase() == normalized) {
        return d;
      }
    }
    return null;
  }

  /// Kode inventaris berikutnya untuk kategori: pakai nomor terkecil yang
  /// belum terpakai (mulai dari 1). Jadi kalau sebuah kode dihapus di cloud,
  /// penambahan berikutnya otomatis mengisi kode kosong itu dulu.
  Future<String> nextKode(String category) async {
    if (localMode) return LocalDatabase.instance.nextKode(category);
    if (_devices.isEmpty && _client != null) {
      await _fetchAll();
    }
    final prefix = _prefixFor(category);
    final used = <int>{};
    final regex =
        RegExp('^${RegExp.escape(prefix)}-(\\d+)', caseSensitive: false);
    for (final d in _devices) {
      final m = regex.firstMatch(d.kodeInventaris);
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > 0) used.add(n);
      }
    }
    final next = nomorKodeBebas(used);
    return '$prefix-${next.toString().padLeft(3, '0')}';
  }

  static String _prefixFor(String category) {
    final t = category.trim().toLowerCase();
    if (t.contains('laptop')) return 'L';
    if (t.contains('print')) return 'P';
    return 'K';
  }

  void _upsertLocal(Device d) {
    var idx = -1;
    if (d.id != null) {
      idx = _devices.indexWhere((x) => x.id == d.id);
    }
    final key = _kodeKey(d.kodeInventaris);
    if (idx < 0 && key.isNotEmpty) {
      idx = _devices.indexWhere((x) => _kodeKey(x.kodeInventaris) == key);
    }
    if (idx >= 0) {
      final old = _devices[idx];
      _devices[idx] = d.id == null ? d.copyWith(id: old.id) : d;
    } else {
      _devices.add(d);
    }
    _devices.sort(_byKode);
  }

  static String _kodeKey(String kode) =>
      kode.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();

  int _byKode(Device a, Device b) {
    final ma =
        RegExp(r'^([KLP])-(\d+)', caseSensitive: false).firstMatch(a.kodeInventaris);
    final mb =
        RegExp(r'^([KLP])-(\d+)', caseSensitive: false).firstMatch(b.kodeInventaris);
    if (ma != null && mb != null) {
      final pa = ma.group(1)!.toUpperCase();
      final pb = mb.group(1)!.toUpperCase();
      if (pa != pb) return pa.compareTo(pb);
      final na = int.tryParse(ma.group(2)!) ?? 0;
      final nb = int.tryParse(mb.group(2)!) ?? 0;
      if (na != nb) return na.compareTo(nb);
    }
    return a.kodeInventaris.compareTo(b.kodeInventaris);
  }

  // ============================================================
  //  MASTER BAGIAN & PLAN (CRUD penuh, sinkron cloud)
  // ============================================================

  Future<List<String>> getBagianMaster() async {
    if (localMode) {
      if (_bagianMaster.isEmpty) await _reloadLocalCache();
      return List.of(_bagianMaster);
    }
    if (_bagianMaster.isEmpty && _client != null) await _fetchAll();
    return List.of(_bagianMaster);
  }

  Future<bool> addBagian(String name) async {
    if (localMode) {
      final ok = await LocalDatabase.instance.addBagian(name);
      if (ok) {
        await _reloadLocalCache();
        notifyListeners();
      }
      return ok;
    }
    if (_client == null) return false;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    try {
      await _client!
          .from(_tBagian)
          .upsert({'name': trimmed}, onConflict: 'name');
      if (!_bagianMaster.contains(trimmed)) {
        _bagianMaster = [..._bagianMaster, trimmed]..sort();
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<MasterUbahResult> updateBagian(String oldName, String newName) async {
    final baru = newName.trim();
    if (baru.isEmpty || _samaNama(baru, oldName)) {
      return const MasterUbahResult(berhasil: false);
    }
    if (_bagianMaster.any((n) => _samaNama(n, baru))) {
      return const MasterUbahResult(berhasil: false, sudahAda: true);
    }
    if (localMode) {
      final ok = await LocalDatabase.instance.updateBagian(oldName, baru);
      if (!ok) {
        return const MasterUbahResult(berhasil: false, sudahAda: true);
      }
      // Data perangkat ikut di-rename supaya tidak tertinggal nama lama.
      final n = await LocalDatabase.instance.renamePakai('bagian', oldName, baru);
      await _reloadLocalCache();
      notifyListeners();
      return MasterUbahResult(berhasil: true, perangkatDiperbarui: n);
    }
    if (_client == null) return const MasterUbahResult(berhasil: false);
    final row = _bagianRows.firstWhere(
      (r) => (r['name'] ?? '').toString() == oldName,
      orElse: () => const {},
    );
    final id = row['id'];
    if (id == null) return const MasterUbahResult(berhasil: false);
    try {
      await _client!.from(_tBagian).update({'name': baru}).eq('id', id);
    } catch (_) {
      return const MasterUbahResult(berhasil: false, sudahAda: true);
    }
    final n = await _renameDevices('bagian', oldName, baru);
    _bagianMaster = _bagianMaster
        .map((n) => _samaNama(n, oldName) ? baru : n)
        .toList()
      ..sort();
    _bagianRows = _bagianRows
        .map((r) => (r['id'] == id ? {...r, 'name': baru} : r))
        .toList();
    notifyListeners();
    return MasterUbahResult(berhasil: true, perangkatDiperbarui: n);
  }

  Future<MasterHapusResult> deleteBagian(String name) async {
    // Bagian yang masih dipakai perangkat tidak boleh dihapus supaya data
    // perangkat tidak menunjuk master yang sudah hilang.
    final dipakai = await countPakaiBagian(name);
    if (dipakai > 0) {
      return MasterHapusResult(berhasil: false, dipakai: dipakai);
    }
    if (localMode) {
      final ok = await LocalDatabase.instance.deleteBagian(name);
      if (ok) {
        await _reloadLocalCache();
        notifyListeners();
      }
      return MasterHapusResult(berhasil: ok);
    }
    if (_client == null) return const MasterHapusResult(berhasil: false);
    final row = _bagianRows.firstWhere(
      (r) => (r['name'] ?? '').toString() == name,
      orElse: () => const {},
    );
    final id = row['id'];
    if (id == null) return const MasterHapusResult(berhasil: false);
    try {
      await _client!.from(_tBagian).delete().eq('id', id);
    } catch (_) {
      return const MasterHapusResult(berhasil: false, sudahAda: true);
    }
    _bagianMaster = _bagianMaster.where((n) => n != name).toList();
    _bagianRows = _bagianRows.where((r) => r['id'] != id).toList();
    notifyListeners();
    return const MasterHapusResult(berhasil: true);
  }

  Future<bool> addPlan(String name) async {
    if (localMode) {
      final ok = await LocalDatabase.instance.addPlan(name);
      if (ok) {
        await _reloadLocalCache();
        notifyListeners();
      }
      return ok;
    }
    if (_client == null) return false;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    try {
      await _client!.from(_tPlan).upsert({'name': trimmed}, onConflict: 'name');
      if (!_planMaster.contains(trimmed)) {
        _planMaster = [..._planMaster, trimmed]..sort();
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> getPlanMaster() async {
    if (localMode) {
      if (_planMaster.isEmpty) await _reloadLocalCache();
      return List.of(_planMaster);
    }
    if (_planMaster.isEmpty && _client != null) await _fetchAll();
    return List.of(_planMaster);
  }

  Future<MasterUbahResult> updatePlan(String oldName, String newName) async {
    final baru = newName.trim();
    if (baru.isEmpty || _samaNama(baru, oldName)) {
      return const MasterUbahResult(berhasil: false);
    }
    if (_planMaster.any((n) => _samaNama(n, baru))) {
      return const MasterUbahResult(berhasil: false, sudahAda: true);
    }
    if (localMode) {
      final ok = await LocalDatabase.instance.updatePlan(oldName, baru);
      if (!ok) {
        return const MasterUbahResult(berhasil: false, sudahAda: true);
      }
      final n = await LocalDatabase.instance.renamePakai('plan', oldName, baru);
      await _reloadLocalCache();
      notifyListeners();
      return MasterUbahResult(berhasil: true, perangkatDiperbarui: n);
    }
    if (_client == null) return const MasterUbahResult(berhasil: false);
    try {
      await _client!.from(_tPlan).update({'name': baru}).eq('name', oldName);
    } catch (_) {
      return const MasterUbahResult(berhasil: false, sudahAda: true);
    }
    final n = await _renameDevices('plan', oldName, baru);
    _planMaster = _planMaster
        .map((p) => _samaNama(p, oldName) ? baru : p)
        .toList()
      ..sort();
    notifyListeners();
    return MasterUbahResult(berhasil: true, perangkatDiperbarui: n);
  }

  Future<MasterHapusResult> deletePlan(String name) async {
    final dipakai = await countPakaiPlan(name);
    if (dipakai > 0) {
      return MasterHapusResult(berhasil: false, dipakai: dipakai);
    }
    if (localMode) {
      final ok = await LocalDatabase.instance.deletePlan(name);
      if (ok) {
        await _reloadLocalCache();
        notifyListeners();
      }
      return MasterHapusResult(berhasil: ok);
    }
    if (_client == null) return const MasterHapusResult(berhasil: false);
    try {
      await _client!.from(_tPlan).delete().eq('name', name);
    } catch (_) {
      return const MasterHapusResult(berhasil: false, sudahAda: true);
    }
    _planMaster = _planMaster.where((p) => p != name).toList();
    notifyListeners();
    return const MasterHapusResult(berhasil: true);
  }

  /// Rename kolom [column] pada semua perangkat yang memakai [oldName], lalu
  /// perbarui cache lokal. Mengembalikan jumlah perangkat yang terpengaruh.
  ///
  /// cloud: satu request `UPDATE ... WHERE id IN (...)` dengan id yang sudah
  /// dicocokkan di memori, sehingga pencocokan tidak bergantung kepekaan huruf
  /// besar-kecil milik PostgREST.
  Future<int> _renameDevices(
    String column,
    String oldName,
    String newName,
  ) async {
    final target = _devices.where((d) {
      final nilai = column == 'bagian' ? d.bagian : d.plan;
      return _samaNama(nilai, oldName);
    }).toList();
    if (target.isEmpty) return 0;
    if (localMode) {
      final n = await LocalDatabase.instance.renamePakai(column, oldName, newName);
      await _reloadLocalCache();
      return n;
    }
    final ids = target.map((d) => d.id).whereType<int>().toList();
    if (ids.isNotEmpty && _client != null) {
      try {
        await _client!.from(_tDevices).update({column: newName}).inFilter('id', ids);
      } catch (_) {
        return 0;
      }
    }
    for (final d in target) {
      if (column == 'bagian') {
        d.bagian = newName;
      } else {
        d.plan = newName;
      }
    }
    _derivePlanMaster();
    return target.length;
  }

  /// Jumlah perangkat yang memakai [name] pada kolom `bagian`.
  Future<int> countPakaiBagian(String name) async {
    if (name.trim().isEmpty) return 0;
    if (localMode) return LocalDatabase.instance.countPakaiBagian(name);
    return _devices.where((d) => _samaNama(d.bagian, name)).length;
  }

  /// Jumlah perangkat yang memakai [name] pada kolom `plan`.
  Future<int> countPakaiPlan(String name) async {
    if (name.trim().isEmpty) return 0;
    if (localMode) return LocalDatabase.instance.countPakaiPlan(name);
    return _devices.where((d) => _samaNama(d.plan, name)).length;
  }

  /// Peta `nama (lowercase) -> jumlah perangkat` untuk kolom `bagian`.
  Future<Map<String, int>> petaPakaiBagian() async {
    if (localMode) return _kunciLower(await LocalDatabase.instance.hitungPakai('bagian'));
    return _pakaiDariCache((d) => d.bagian);
  }

  /// Peta `nama (lowercase) -> jumlah perangkat` untuk kolom `plan`.
  Future<Map<String, int>> petaPakaiPlan() async {
    if (localMode) return _kunciLower(await LocalDatabase.instance.hitungPakai('plan'));
    return _pakaiDariCache((d) => d.plan);
  }

  static Map<String, int> _kunciLower(Map<String, int> src) => <String, int>{
        for (final e in src.entries) e.key.trim().toLowerCase(): e.value,
      };

  Map<String, int> _pakaiDariCache(String Function(Device) kolom) {
    final peta = <String, int>{};
    for (final d in _devices) {
      final key = kolom(d).trim().toLowerCase();
      if (key.isEmpty) continue;
      peta[key] = (peta[key] ?? 0) + 1;
    }
    return peta;
  }

  Future<List<String>> distinctBagian() async {
    if (localMode) return LocalDatabase.instance.distinctBagian();
    final set = _devices
        .map((d) => d.bagian)
        .where((b) => b.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return set;
  }

  Future<List<String>> distinctPlan() async {
    if (localMode) return LocalDatabase.instance.distinctPlan();
    return List.of(_planMaster);
  }

  /// Pastikan bagian & plan dari data perangkat masuk tabel master.
  Future<void> _ensureMastersFromDevices() async {
    if (localMode) {
      await _reloadLocalCache();
      return;
    }
    if (_client == null) return;
    final bagins = _devices
        .map((d) => d.bagian)
        .where((b) => b.trim().isNotEmpty)
        .toSet()
        .map((b) => {'name': b})
        .toList();
    if (bagins.isNotEmpty) {
      await _client!
          .from(_tBagian)
          .upsert(bagins, onConflict: 'name');
    }
    final plans = _devices
        .map((d) => d.plan)
        .where((p) => p.trim().isNotEmpty)
        .toSet()
        .map((p) => {'name': p})
        .toList();
    if (plans.isNotEmpty) {
      await _client!.from(_tPlan).upsert(plans, onConflict: 'name');
    }
    await _fetchAll();
  }

  // ============================================================
  //  PIN TER-SINKRONISASI (cloud + fallback lokal)
  // ============================================================

  Future<String?> _cloudPinHash() async {
    if (_client == null) return null;
    try {
      final rows = await _client!
          .from(_tSettings)
          .select('pin_hash')
          .eq('id', 1)
          .maybeSingle();
      if (rows != null) {
        _cachedPinHash = (rows['pin_hash'] ?? '').toString();
      }
      return _cachedPinHash;
    } catch (_) {
      return _cachedPinHash;
    }
  }

  Future<bool> verifyPin(String pin) async {
    final hash = PinController.hashPin(pin);
    // Selalu ambil PIN terkini dari cloud (realtime-sync) saat online,
    // sehingga PIN yang diubah di HP lain langsung berlaku di sini.
    if (_client != null) {
      await _cloudPinHash();
    }
    final stored = _cachedPinHash;
    // Cloud PIN yang valid (bukan string kosong) dipakai sebagai acuan.
    if (stored != null && stored.isNotEmpty) return hash == stored;
    // PIN cloud belum di-set (masih kosong) atau offline:
    // fallback ke PIN lokal (bawaan 0000).
    return PinController.instance.verify(pin);
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    if (!await verifyPin(oldPin)) return false;
    final np = newPin.trim();
    if (np.length < PinController.minLength ||
        np.length > PinController.maxLength) {
      return false;
    }
    final hash = PinController.hashPin(np);
    if (_client != null) {
      try {
        await _client!
            .from(_tSettings)
            .upsert({'id': 1, 'pin_hash': hash}, onConflict: 'id');
        _cachedPinHash = hash;
        // Sinkronkan juga ke cache lokal agar PIN tetap berfungsi saat
        // offline / PIN cloud belum diisi.
        await PinController.instance.savePin(np);
        return true;
      } catch (_) {
        return false;
      }
    }
    return PinController.instance.changePin(oldPin, np);
  }

  // ============================================================
  //  SEED OTOMATIS DARI EXCEL (hanya jika cloud kosong)
  // ============================================================

  Future<void> seedIfEmpty() async {
    if (localMode) {
      try {
        final fromExcel = await loadExcelSeed();
        await LocalDatabase.instance.seedIfEmpty(fromExcel);
        await _reloadLocalCache();
        notifyListeners();
      } catch (e) {
        debugPrintFallback('Gagal seeding lokal dari Excel: $e');
      }
      return;
    }
    if (_client == null) return;
    try {
      final existing = await _client!.from(_tDevices).select('id');
      if (existing.isEmpty) {
        // Cloud masih kosong → pertahankan data yang sudah ada dengan
        // mengunggah isi database lokal terlebih dahulu (jika ada),
        // baru fallback ke seed Excel bila lokal kosong.
        List<Device> source = const [];
        try {
          source = await LocalDatabase.instance.getAll();
        } catch (e) {
          debugPrintFallback('Tidak bisa baca data lokal untuk migrasi: $e');
        }
        if (source.isEmpty) {
          source = await loadExcelSeed();
        }
        if (source.isNotEmpty) {
          await _client!
              .from(_tDevices)
              .insert(source.map((d) => ({...d.toMap()}..remove('id'))).toList());
        }
      }
      await _ensureMastersFromDevices();
    } catch (e) {
      debugPrintFallback('Gagal seeding cloud dari data lokal/Excel: $e');
    }
  }

  /// Bersihkan semua data lalu import ulang dari Excel (sync penuh).
  Future<int> reseedFromExcel() async {
    if (localMode) {
      final db = await LocalDatabase.instance.database;
      final data = await loadExcelSeed();
      await db.delete('devices');
      await db.delete('bagian_master');
      await db.delete('plan_master');
      await LocalDatabase.instance.seedIfEmpty(data);
      await _reloadLocalCache();
      notifyListeners();
      return data.length;
    }
    if (_client == null) return 0;
    await _client!.from(_tDevices).delete().neq('id', 0);
    final data = await loadExcelSeed();
    if (data.isNotEmpty) {
      await _client!.from(_tDevices).insert(
            data.map((d) => ({...d.toMap()}..remove('id'))).toList(),
          );
      await _ensureMastersFromDevices();
    }
    return data.length;
  }

  // ============================================================
  //  PARSING EXCEL (dipakai seeding — tidak menyentuh cloud)
  // ============================================================

  // ============================================================
  //  IMPORT FILE EXCEL (dipilih user) — web & apk, data SATU cloud
  //  1) baca byte .xlsx -> List<Device>
  //  2) tulis ke cloud (Supabase devices) bila terhubung
  //  3) upsert cache lokal -> sinkron di APK & web
  // ============================================================

  /// Alias nama kolom (lowercase) untuk pencocokan saat impor.
  /// Cocok bila sel header mengandung salah satu alias.
  static const _importAliases = <String, List<String>>{
    'tanggalEvaluasi': ['tanggal evalu'],
    'kodeInventaris': ['kode inventaris'],
    'plan': ['plan'],
    'bagian': ['bagian'],
    'deviceName': ['device name', 'nama device'],
    'category': ['category', 'kategori'],
    'prosesor': ['prosesor', 'processor', 'cpu'],
    'motherboard': ['motherboard', 'mother board'],
    'ram': ['ram'],
    'storage': ['storage', 'penyimpanan'],
    'osWindows': ['os windows', 'sistem operasi'],
    'goal': ['goal'],
    'ganti': ['perlu upgrade ganti', 'ganti'],
    'repair': ['perlu upgrade repair', 'repair', 'perbaikan'],
    'statusUpgrade': ['status upgrade'],
    'keterangan': ['keterangan', 'catatan'],
    'statusStiker': ['status stiker', 'stiker'],
  };

  /// Baca SELURUH sheet pada file .xlsx hasil ekspor aplikasi.
  ///
  /// Ekspor menulis kop + 2 baris header (utama dan sub-header) lalu data, dan
  /// memisahkan kategori ke sheet Computer/Laptop/Printer. Parser mencari baris
  /// header secara otomatis, menggabungkan baris utama dengan sub-header, lalu
  /// membaca data di bawahnya.
  Future<List<Device>> parseExcelBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return const [];
    try {
      final excel = excel_pkg.Excel.decodeBytes(bytes);
      final out = <Device>[];
      for (final entry in excel.tables.entries) {
        final sheet = entry.value;
        out.addAll(_parseSheet(sheet, entry.key));
      }
      return out;
    } catch (e) {
      debugPrintFallback('Gagal membaca Excel impor: $e');
      return const [];
    }
  }

  List<Device> _parseSheet(excel_pkg.Sheet sheet, String sheetName) {
    final rows = sheet.rows;
    if (rows.isEmpty) return const <Device>[];

    String cellAt(int rowIdx, int colIdx) {
      if (rowIdx < 0 || rowIdx >= rows.length) return '';
      final row = rows[rowIdx];
      if (colIdx < 0 || colIdx >= row.length) return '';
      return _cellString(row[colIdx]).trim();
    }

    final allAliases =
        _importAliases.values.expand((e) => e).toList(growable: false);

    // 1) Baris header = baris dengan pencocokan alias terbanyak.
    var headerRow = -1;
    var bestScore = 0;
    for (var r = 0; r < rows.length && r < 30; r++) {
      var score = 0;
      for (final entry in _importAliases.entries) {
        for (var ci = 0; ci < 30; ci++) {
          final v = cellAt(r, ci).toLowerCase();
          if (v.isNotEmpty && entry.value.any((a) => v.contains(a))) {
            score++;
            break;
          }
        }
      }
      if (score > bestScore) {
        bestScore = score;
        headerRow = r;
      }
    }
    if (headerRow < 0 || bestScore < 3) return const <Device>[];

    // 2) Header logis: baris utama digabung dengan sub-header di bawahnya.
    final width = rows[headerRow].length;
    final logical = List<String>.filled(width, '');
    for (var ci = 0; ci < width; ci++) {
      final a = cellAt(headerRow, ci).toLowerCase();
      final b = cellAt(headerRow + 1, ci).toLowerCase();
      logical[ci] = b.isNotEmpty ? '$a $b' : a;
    }

    final col = <String, int>{};
    for (final entry in _importAliases.entries) {
      for (var ci = 0; ci < width; ci++) {
        if (entry.value.any((a) => logical[ci].contains(a))) {
          col[entry.key] = ci;
          break;
        }
      }
    }
    if (col.isEmpty) return const <Device>[];

    String val(String key, int rowIdx) => cellAt(rowIdx, col[key] ?? -1);

    // 3) Baris data berada di bawah header dan sub-header.
    final result = <Device>[];
    for (var r = headerRow + 1; r < rows.length; r++) {
      var any = false;
      for (var ci = 0; ci < width; ci++) {
        if (cellAt(r, ci).isNotEmpty) {
          any = true;
          break;
        }
      }
      if (!any) continue;

      if (r == headerRow + 1) {
        // Lewati baris sub-header bila isinya hanya nama kolom.
        final vals = <String>[];
        for (var ci = 0; ci < width; ci++) {
          final v = cellAt(r, ci).toLowerCase();
          if (v.isNotEmpty) vals.add(v);
        }
        final headerish =
            vals.isNotEmpty && vals.every((v) => allAliases.any((a) => v.contains(a)));
        if (headerish) continue;
      }

      final kode = val('kodeInventaris', r);
      final nama = val('deviceName', r);
      if (kode.isEmpty) continue;
      var kat = val('category', r);
      if (kat.isEmpty) kat = _categoryFromSheet(sheetName);

      result.add(Device(
        kodeInventaris: kode,
        tanggalEvaluasi: val('tanggalEvaluasi', r),
        plan: val('plan', r),
        bagian: val('bagian', r),
        deviceName: nama,
        category: kat,
        prosesor: val('prosesor', r),
        motherboard: val('motherboard', r),
        ram: val('ram', r),
        storage: val('storage', r),
        osWindows: val('osWindows', r),
        goal: val('goal', r),
        perluUpgradeGanti: val('ganti', r),
        perluUpgradeRepair: val('repair', r),
        statusUpgrade: val('statusUpgrade', r),
        keterangan: val('keterangan', r),
        statusStiker: val('statusStiker', r),
      ));
    }
    return result;
  }

  String _categoryFromSheet(String sheetName) {
    final t = sheetName.trim().toLowerCase();
    if (t.contains('laptop')) return 'Laptop';
    if (t.contains('print')) return 'Printer';
    if (t.contains('computer')) return 'Computer';
    return '';
  }

  /// Impor file .xlsx pilihan user ke cloud (Supabase) + cache lokal.
  Future<int> importExcelFile(Uint8List bytes) async {
    List<Device> data;
    try {
      data = await parseExcelBytes(bytes);
    } catch (e) {
      debugPrintFallback('Gagal parse Excel impor: $e');
      return 0;
    }
    if (data.isEmpty) {
      debugPrintFallback('Excel impor kosong / kolom tidak dikenali.');
      return 0;
    }
    if (localMode) {
      for (final d in data) {
        if (_kodeKey(d.kodeInventaris).isEmpty) continue;
        final existing =
            await LocalDatabase.instance.getByKode(d.kodeInventaris);
        if (existing != null && existing.id != null) {
          await LocalDatabase.instance.update(d.copyWith(id: existing.id));
        } else {
          await LocalDatabase.instance.insert(d);
        }
      }
      await _reloadLocalCache();
    } else if (_client != null) {
      var savedToCloud = false;
      try {
        await _client!.from(_tDevices).upsert(
              data
                  .where((d) => _kodeKey(d.kodeInventaris).isNotEmpty)
                  .map((d) => ({...d.toMap()}..remove('id')))
                  .toList(),
              onConflict: 'kode_inventaris',
            );
        savedToCloud = true;
      } catch (e) {
        debugPrintFallback('Cloud impor gagal, simpan lokal saja: $e');
      }
      if (savedToCloud) {
        await _fetchAll();
      } else {
        for (final d in data) {
          _upsertLocal(d);
        }
      }
    } else {
      for (final d in data) {
        _upsertLocal(d);
      }
    }
    await _ensureMastersFromDevices();
    notifyListeners();
    return data.length;
  }

  Future<List<Device>> loadExcelSeed() async {
    final ByteData b = await rootBundle.load(_assetExcel);
    final Uint8List bytes = b.buffer.asUint8List(
      b.offsetInBytes,
      b.lengthInBytes,
    );

    final excel = excel_pkg.Excel.decodeBytes(bytes);
    final sheet = excel.tables[_sheetName];
    if (sheet == null) return [];

    final rows = sheet.rows;
    if (rows.isEmpty) return [];

    final header = rows.first
        .map((c) => _cellString(c).toLowerCase().replaceAll(RegExp(r'\s+'), ' '))
        .toList();

    int colIndex(String sub) {
      final parts = sub.split(' ');
      return header.indexWhere((h) => parts.every(h.contains));
    }

    int getCol(String key) {
      const map = {
        'tanggalEvaluasi': 'tanggal evaluasi',
        'kodeInventaris': 'kode inventaris',
        'plan': 'plan',
        'bagian': 'bagian',
        'deviceName': 'device name',
        'category': 'category',
        'prosesor': 'prosesor',
        'motherboard': 'motherboard',
        'ram': 'ram',
        'storage': 'storage',
        'osWindows': 'os windows',
        'goal': 'goal',
        'ganti': 'perlu upgrade ganti',
        'repair': 'perlu upgrade repair',
        'statusUpgrade': 'status upgrade',
        'keterangan': 'keterangan',
        'statusStiker': 'status stiker',
      };
      return colIndex(map[key]!);
    }

    final c = {
      'tanggalEvaluasi': getCol('tanggalEvaluasi'),
      'kodeInventaris': getCol('kodeInventaris'),
      'plan': getCol('plan'),
      'bagian': getCol('bagian'),
      'deviceName': getCol('deviceName'),
      'category': getCol('category'),
      'prosesor': getCol('prosesor'),
      'motherboard': getCol('motherboard'),
      'ram': getCol('ram'),
      'storage': getCol('storage'),
      'osWindows': getCol('osWindows'),
      'goal': getCol('goal'),
      'ganti': getCol('ganti'),
      'repair': getCol('repair'),
      'statusUpgrade': getCol('statusUpgrade'),
      'keterangan': getCol('keterangan'),
      'statusStiker': getCol('statusStiker'),
    };

    String val(int ci, int ri) {
      if (ci < 0 || ri >= rows.length) return '';
      final row = rows[ri];
      if (ci >= row.length) return '';
      return _cellString(row[ci]);
    }

    final result = <Device>[];
    for (int ri = 1; ri < rows.length; ri++) {
      final row = rows[ri];
      final isEmptyRow = row.every((cell) => _cellString(cell).trim().isEmpty);
      if (isEmptyRow) continue;

      result.add(Device(
        kodeInventaris: val(c['kodeInventaris']!, ri),
        tanggalEvaluasi: val(c['tanggalEvaluasi']!, ri),
        plan: val(c['plan']!, ri),
        bagian: val(c['bagian']!, ri),
        deviceName: val(c['deviceName']!, ri),
        category: val(c['category']!, ri),
        prosesor: val(c['prosesor']!, ri),
        motherboard: val(c['motherboard']!, ri),
        ram: val(c['ram']!, ri),
        storage: val(c['storage']!, ri),
        osWindows: val(c['osWindows']!, ri),
        goal: val(c['goal']!, ri),
        perluUpgradeGanti: val(c['ganti']!, ri),
        perluUpgradeRepair: val(c['repair']!, ri),
        statusUpgrade: val(c['statusUpgrade']!, ri),
        keterangan: val(c['keterangan']!, ri),
        statusStiker: val(c['statusStiker']!, ri),
      ));
    }
    return result;
  }

  // Convert a Sheet cell value to readable string, handling dates & serials.
  String _cellString(excel_pkg.Data? data) {
    if (data == null) return '';
    final v = data.value;
    if (v == null) return '';

    if (v is excel_pkg.DateCellValue) {
      return _formatDate(v.asDateTimeLocal());
    }
    if (v is excel_pkg.TextCellValue) {
      return v.value.text?.toString().trim() ?? '';
    }
    if (v is excel_pkg.IntCellValue) {
      final n = v.value;
      if (n >= 20000 && n <= 60000) {
        return _formatDate(_fromExcelSerial(n.toDouble()));
      }
      return n.toString();
    }
    if (v is excel_pkg.DoubleCellValue) {
      final n = v.value;
      if (n >= 20000 && n <= 60000) {
        return _formatDate(_fromExcelSerial(n));
      }
      return n.toString();
    }
    if (v is excel_pkg.BoolCellValue) {
      return v.value ? 'Yes' : 'No';
    }
    if (v is excel_pkg.TimeCellValue) {
      return '${v.hour.toString().padLeft(2, '0')}:'
          '${v.minute.toString().padLeft(2, '0')}';
    }
    if (v is excel_pkg.FormulaCellValue) {
      return v.formula.toString();
    }
    return v.toString();
  }

  DateTime _fromExcelSerial(num serial) {
    final epoch = DateTime(1899, 12, 30);
    return epoch.add(Duration(days: serial.round()));
  }

  String _formatDate(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year}';
  }
}

void debugPrintFallback(String message) {
  // ignore: avoid_print
  print(message);
}