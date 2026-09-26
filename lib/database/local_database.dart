import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/device.dart';
import 'web_db_factory.dart';

/// Penyimpanan lokal (SQLite) sebagai fallback saat cloud tidak tersedia.
/// Struktur tabel identik dengan skema cloud (Supabase) sehingga migrasi
/// antar mode aman. Seed dari Excel dilakukan jika tabel masih kosong.
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  static const _dbName = 'inventaris_local.db';
  static const _dbVersion = 2;
  static const _tableDevices = 'devices';
  static const _tableBagian = 'bagian_master';
  static const _tablePlan = 'plan_master';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    String path;
    if (kIsWeb) {
      await initDatabaseFactory();
      path = webDbPath(_dbName);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = p.join(dir.path, _dbName);
    }
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  /// Migrasi skema lama → baru. Sangat aman dijalankan berulang:
  /// hanya menambah kolom bila belum tersedia.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _ensureColumns(db);
  }

  Future<void> _ensureColumns(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info($_tableDevices)');
    final names = cols.map((c) => (c['name'] ?? '').toString()).toSet();
    if (!names.contains('drive_link')) {
      await db.execute(
          'ALTER TABLE $_tableDevices ADD COLUMN drive_link TEXT DEFAULT ""');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableDevices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kode_inventaris TEXT,
        tanggal_evaluasi TEXT,
        plan TEXT,
        bagian TEXT,
        device_name TEXT,
        category TEXT,
        prosesor TEXT,
        motherboard TEXT,
        ram TEXT,
        storage TEXT,
        os_windows TEXT,
        goal TEXT,
        perlu_upgrade_ganti TEXT,
        perlu_upgrade_repair TEXT,
        status_upgrade TEXT,
        keterangan TEXT,
        status_stiker TEXT,
        drive_link TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE $_tableBagian (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');
    await db.execute('''
      CREATE TABLE $_tablePlan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');
    await db.insert(_tablePlan, {'name': 'Sentul'},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // ============================================================
  //  SEED DARI EXCEL (hanya jika kosong)
  // ============================================================

  Future<void> seedIfEmpty(List<Device> fromExcel) async {
    if (fromExcel.isEmpty) return;
    final db = await database;
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_tableDevices'),
        ) ??
        0;
    if (count > 0) return;
    final batch = db.batch();
    for (final d in fromExcel) {
      batch.insert(_tableDevices, d.toMap());
    }
    await batch.commit(noResult: true);
    await _seedMastersFromDevices(db);
  }

  Future<void> _seedMastersFromDevices(Database db) async {
    final bagian = await db.rawQuery(
        'SELECT DISTINCT bagian FROM $_tableDevices WHERE bagian IS NOT NULL AND bagian != ""');
    for (final r in bagian) {
      final name = (r['bagian'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      await db.insert(_tableBagian, {'name': name},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    final plans = await db.rawQuery(
        'SELECT DISTINCT plan FROM $_tableDevices WHERE plan IS NOT NULL AND plan != ""');
    for (final r in plans) {
      final name = (r['plan'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      await db.insert(_tablePlan, {'name': name},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ============================================================
  //  CRUD PERANGKAT
  // ============================================================

  Future<List<Device>> getAll() async {
    final db = await database;
    final rows = await db.query(_tableDevices);
    final list = rows.map(Device.fromMap).toList();
    list.sort((a, b) => _byKode(a, b));
    return list;
  }

  Future<int> insert(Device d) async {
    final db = await database;
    final id = await db.insert(_tableDevices, d.toMap());
    _syncMastersFrom(d);
    return id;
  }

  Future<int> update(Device d) async {
    if (d.id == null) return 0;
    final db = await database;
    final n = await db.update(_tableDevices, d.toMap(),
        where: 'id = ?', whereArgs: [d.id]);
    _syncMastersFrom(d);
    return n;
  }

  Future<int> delete(int id) async {
    final db = await database;
    return db.delete(_tableDevices, where: 'id = ?', whereArgs: [id]);
  }

  Future<Device?> getByKode(String kode) async {
    final db = await database;
    final normalized = kode.trim().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) return null;
    final rows = await db.query(
      _tableDevices,
      where: 'REPLACE(kode_inventaris, " ", "") = ? COLLATE NOCASE',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Device.fromMap(rows.first);
  }

  static String _prefixFor(String category) {
    final t = category.trim().toLowerCase();
    if (t.contains('laptop')) return 'L';
    if (t.contains('print')) return 'P';
    return 'K';
  }

  Future<String> nextKode(String category) async {
    final prefix = _prefixFor(category);
    final db = await database;
    final rows = await db.query(_tableDevices, columns: ['kode_inventaris']);
    var maxNum = 0;
    final regex = RegExp('^${RegExp.escape(prefix)}-(\\d+)',
        caseSensitive: false);
    for (final r in rows) {
      final m = regex.firstMatch((r['kode_inventaris'] ?? '').toString());
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > maxNum) maxNum = n;
      }
    }
    return '$prefix-${(maxNum + 1).toString().padLeft(3, '0')}';
  }

  int _byKode(Device a, Device b) {
    final ma = RegExp(r'^([KLP])-(\d+)', caseSensitive: false)
        .firstMatch(a.kodeInventaris);
    final mb = RegExp(r'^([KLP])-(\d+)', caseSensitive: false)
        .firstMatch(b.kodeInventaris);
    if (ma != null && mb != null) {
      final pa = ma.group(1)!.toUpperCase();
      final pb = mb.group(1)!.toUpperCase();
      if (pa != pb) return pa.compareTo(pb);
      final na = int.tryParse(ma.group(2)!) ?? 0;
      final nb = int.tryParse(mb.group(2)!) ?? 0;
      return na.compareTo(nb);
    }
    return a.kodeInventaris.compareTo(b.kodeInventaris);
  }

  /// Pastikan bagian/plan baru ikut ke tabel master.
  Future<void> _syncMastersFrom(Device d) async {
    if (d.bagian.trim().isNotEmpty) {
      await addBagian(d.bagian);
    }
    if (d.plan.trim().isNotEmpty) {
      await addPlan(d.plan);
    }
  }

  // ============================================================
  //  MASTER BAGIAN & PLAN
  // ============================================================

  Future<List<String>> getBagianMaster() async {
    final db = await database;
    final rows = await db.query(_tableBagian, orderBy: 'name COLLATE NOCASE ASC');
    return rows
        .map((r) => (r['name'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toList();
  }

  Future<bool> addBagian(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final db = await database;
    try {
      final id = await db.insert(_tableBagian, {'name': trimmed},
          conflictAlgorithm: ConflictAlgorithm.ignore);
      return id != -1;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateBagian(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;
    final db = await database;
    final n = await db.update(_tableBagian, {'name': trimmed},
        where: 'name = ?', whereArgs: [oldName]);
    return n > 0;
  }

  Future<bool> deleteBagian(String name) async {
    final db = await database;
    final n = await db.delete(_tableBagian, where: 'name = ?', whereArgs: [name]);
    return n > 0;
  }

  Future<bool> addPlan(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final db = await database;
    try {
      final id = await db.insert(_tablePlan, {'name': trimmed},
          conflictAlgorithm: ConflictAlgorithm.ignore);
      return id != -1;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updatePlan(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;
    final db = await database;
    final n = await db.update(_tablePlan, {'name': trimmed},
        where: 'name = ?', whereArgs: [oldName]);
    return n > 0;
  }

  Future<bool> deletePlan(String name) async {
    final db = await database;
    final n =
        await db.delete(_tablePlan, where: 'name = ?', whereArgs: [name]);
    return n > 0;
  }

  Future<List<String>> getPlanMaster() async {
    final db = await database;
    final rows = await db.query(_tablePlan, orderBy: 'name COLLATE NOCASE ASC');
    return rows
        .map((r) => (r['name'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toList();
  }

  Future<List<String>> distinctBagian() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT DISTINCT bagian FROM $_tableDevices WHERE bagian IS NOT NULL AND bagian != "" ORDER BY bagian ASC');
    return rows.map((r) => (r['bagian'] ?? '').toString()).toList();
  }

  Future<List<String>> distinctPlan() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT DISTINCT plan FROM $_tableDevices WHERE plan IS NOT NULL AND plan != "" ORDER BY plan ASC');
    return rows.map((r) => (r['plan'] ?? '').toString()).toList();
  }
}