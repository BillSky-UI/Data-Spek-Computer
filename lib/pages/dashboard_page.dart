import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../database/db_helper.dart';
import '../models/device.dart';
import '../services/settings_controller.dart';
import '../theme/app_theme.dart';
import '../utils/field_groups.dart';
import '../widgets/app_popup_menu.dart';
import '../widgets/clickable.dart';
import '../widgets/export_sheet.dart';
import 'category_picker_page.dart';
import 'device_form_page.dart';
import 'scan_page.dart';
import 'spec_breakdown_page.dart';
import 'stats_page.dart';
import 'sticker_detail_page.dart';

/// Definisi kategori spesifikasi yang ditampilkan sebagai kartu grid 2 kolom.
class SpecCategory {
  final String title;
  final IconData icon;
  final String Function(Device) grouper;
  const SpecCategory(this.title, this.grouper, this.icon);
}

class DashboardPage extends StatefulWidget {
  final SettingsController settings;
  const DashboardPage({super.key, required this.settings});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DbHelper _db = DbHelper.instance;

  List<Device> _all = [];
  List<Device> _filtered = [];
  List<String> _bagianList = [];
  List<String> _planList = [];

  String _filterBagian = '';
  String _filterPlan = '';
  String _filterKategori = '';
  bool _loading = true;

  // Susunan 2 kolom: Processor-Motherboard, Storage-RAM, OS-Category.
  static const _categories = [
    SpecCategory('Processor', _proc, Icons.memory),
    SpecCategory('Motherboard', _mobo, Icons.developer_board),
    SpecCategory('Storage', _stor, Icons.storage),
    SpecCategory('RAM / Memory', _ram, Icons.sd_storage),
    SpecCategory('OS Windows', _os, Icons.desktop_windows),
    SpecCategory('Category Device', _cat, Icons.devices_other),
  ];

  /// Kartu statistik saat filter kategori = Printer.
  ///
  /// Spesifikasi PC (processor/RAM/storage/OS) tidak relevan untuk printer,
  /// jadi gridnya diganti dengan data yang memang diinput di form printer.
  static const _printerCategories = [
    SpecCategory('Tipe / Model Printer', _tipePrinter, Icons.print),
    SpecCategory('Metode Koneksi', _koneksiPrinter, Icons.wifi),
    SpecCategory('Category Device', _cat, Icons.devices_other),
    SpecCategory('Status Perbaikan', _statusPrinter, Icons.build),
  ];

  /// Daftar kartu yang tampil sesuai filter kategori yang aktif.
  List<SpecCategory> get _activeCategories =>
      _filterKategori == 'Printer' ? _printerCategories : _categories;

  static String _proc(Device d) => processorGroup(d.prosesor);
  static String _mobo(Device d) => motherboardGroup(d.motherboard);
  static String _stor(Device d) => storageGroup(d.storage);
  static String _ram(Device d) => ramGroup(d.ram);
  static String _os(Device d) => osGroup(d.osWindows);
  static String _cat(Device d) => categoryKey(d.category);

  static String _tipePrinter(Device d) {
    final t = d.prosesor.trim();
    return t.isEmpty ? belumDiInput : t;
  }

  static String _koneksiPrinter(Device d) {
    final t = d.motherboard.trim();
    return t.isEmpty ? belumDiInput : t;
  }

  static String _statusPrinter(Device d) {
    final t = d.statusUpgrade.trim();
    return t.isEmpty ? belumDiInput : t;
  }

  @override
  void initState() {
    super.initState();
    _load();
    // real-time: dashboard otomatis update saat cloud/lokal berubah.
    _db.addListener(_onDbChanged);
  }

  @override
  void dispose() {
    _db.removeListener(_onDbChanged);
    super.dispose();
  }

  void _onDbChanged() => _load();

  Future<void> _load() async {
    final devices = await _db.getAll();
    // Master dipakai juga supaya plan/bagian yang baru ditambahkan langsung
    // muncul di totalan dan dropdown walau belum ada perangkatnya.
    final bagianMaster = await _db.getBagianMaster();
    final planMaster = await _db.getPlanMaster();
    if (!mounted) return;
    setState(() {
      _all = devices;
      _bagianList = _mergeNames(bagianMaster, devices.map((d) => d.bagian));
      _planList = _mergeNames(planMaster, devices.map((d) => d.plan));
      _applyFilters();
      _loading = false;
    });
  }

  /// Gabungkan daftar master dengan nilai yang dipakai perangkat.
  List<String> _mergeNames(List<String> master, Iterable<String> used) {
    final out = <String>{};
    for (final n in [...master, ...used]) {
      final t = n.trim();
      if (t.isNotEmpty) out.add(t);
    }
    return out.toList()..sort();
  }

  void _applyFilters() {
    _filtered = _all.where((d) {
      final matchKategori = _filterKategori.isEmpty ||
          categoryKey(d.category) == _filterKategori;
      final matchBagian = _filterBagian.isEmpty || d.bagian == _filterBagian;
      final matchPlan = _filterPlan.isEmpty || d.plan == _filterPlan;
      return matchKategori && matchBagian && matchPlan;
    }).toList();
  }

  /// Deskripsi filter aktif untuk judul/label ekspor.
  String get _filterCaption {
    final parts = <String>[];
    if (_filterKategori.isNotEmpty) parts.add(_filterKategori);
    if (_filterBagian.isNotEmpty) parts.add('Bagian $_filterBagian');
    if (_filterPlan.isNotEmpty) parts.add('PLAN $_filterPlan');
    return parts.isEmpty ? 'Semua data' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(null),
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Data'),
      ),
      appBar: AppBar(
        title: const Text('Spek Inventaris DPR'),
        actions: [
          IconButton(
            tooltip: 'Scan QR / Barcode',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanPage()),
            ),
          ),
          AppPopupMenu(settings: widget.settings),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.accent))
          : RefreshIndicator(
              color: c.accent,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  _summaryRow(context),
                  const SizedBox(height: 10),
                  _statsBanner(context),
                  const SizedBox(height: 16),
                  _filters(context),
                  const SizedBox(height: 16),
                  if (_filtered.isEmpty)
                    _emptyState(context)
                  else ...[
                    _stickerPieSection(context),
                    const SizedBox(height: 18),
                    _variantSection(context),
                  ],
                ],
              ),
            ),
    );
  }

  // ---------- Banner Statistik Lengkap ----------
  Widget _statsBanner(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: Colors.transparent,
      child: Clickable(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => StatsPage(devices: List.of(_filtered))),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.stickerChipBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.bar_chart, color: c.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('STATISTIK LENGKAP',
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 13,
                              letterSpacing: 0.4,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text('Per kategori, bagian, PLAN & status perbaikan '
                          '(${_filtered.length})',
                          style: TextStyle(color: c.textMuted, fontSize: 11.5)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Ekspor hasil filter',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.file_download_outlined,
                      color: _filtered.isEmpty ? c.inputHint : c.blue,
                      size: 20),
                  onPressed: _filtered.isEmpty
                      ? null
                      : () => showExportSheet(
                            context,
                            devices: List.of(_filtered),
                            title: 'Ekspor Data Dashboard',
                            subtitle: _filterCaption,
                          ),
                ),
                Icon(Icons.chevron_right, color: c.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Ringkasan singkat ----------
  Widget _summaryRow(BuildContext context) {
    final c = context.appColors;
    return Row(
      children: [
        _summaryCard(context, _all.length.toString(), 'Total Perangkat',
            Icons.computer, c.accent),
        const SizedBox(width: 8),
        _summaryCard(context, _bagianList.length.toString(), 'Total Bagian',
            Icons.business_outlined, c.blue),
        const SizedBox(width: 8),
        _summaryCard(context, _planList.length.toString(), 'Total PLAN',
            Icons.account_tree_outlined, c.planChipFg),
      ],
    );
  }

  Widget _summaryCard(
      BuildContext context, String value, String label, IconData icon, Color color) {
    final c = context.appColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMuted, fontSize: 10, height: 1.2)),
          ],
        ),
      ),
    );
  }

  // ---------- Filter interaktif ----------
  Widget _filters(BuildContext context) {
    final c = context.appColors;
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: c.textMuted),
          filled: true,
          fillColor: c.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.border),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kategoriChips(context),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Clickable(
                child: DropdownButtonFormField<String>(
                  initialValue: _filterBagian.isEmpty ? null : _filterBagian,
                  isExpanded: true,
                  dropdownColor: c.surface,
                  style: TextStyle(color: c.textPrimary, fontSize: 13),
                  decoration: deco('Semua Bagian'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Semua Bagian')),
                    ..._bagianList.map(
                        (b) => DropdownMenuItem(value: b, child: Text(b))),
                  ],
                  onChanged: (v) => setState(() {
                    _filterBagian = v ?? '';
                    _applyFilters();
                  }),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Clickable(
                child: DropdownButtonFormField<String>(
                  initialValue: _filterPlan.isEmpty ? null : _filterPlan,
                  isExpanded: true,
                  dropdownColor: c.surface,
                  style: TextStyle(color: c.textPrimary, fontSize: 13),
                  decoration: deco('Semua PLAN'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Semua PLAN')),
                    ..._planList
                        .map((p) => DropdownMenuItem(value: p, child: Text(p))),
                  ],
                  onChanged: (v) => setState(() {
                    _filterPlan = v ?? '';
                    _applyFilters();
                  }),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Chip filter kategori: Semua / Computer / Laptop / Printer.
  Widget _kategoriChips(BuildContext context) {
    final c = context.appColors;
    int countOf(String key) =>
        key.isEmpty ? _all.length : _all.where((d) => _cat(d) == key).length;

    Widget chip(String key, String label, IconData icon) {
      final selected = _filterKategori == key;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Clickable(
          child: ChoiceChip(
            selected: selected,
            showCheckmark: false,
            avatar: Icon(icon,
                size: 16, color: selected ? c.onAccent : c.textMuted),
            label: Text('$label (${countOf(key)})'),
            labelStyle: TextStyle(
                color: selected ? c.onAccent : c.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600),
            backgroundColor: c.surface,
            selectedColor: c.accent,
            side: BorderSide(
                color: selected ? c.accent : c.border,
                width: selected ? 1.5 : 1),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999)),
            onSelected: (_) => setState(() {
              _filterKategori = key;
              _applyFilters();
            }),
          ),
        ),
      );
    }

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('', 'Semua', Icons.apps),
          chip('Computer', 'Computer', Icons.computer),
          chip('Laptop', 'Laptop', Icons.laptop),
          chip('Printer', 'Printer', Icons.print),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.pie_chart_outline, size: 52, color: c.emptyIcon),
          const SizedBox(height: 10),
          Text('Tidak ada data untuk filter ini',
              style: TextStyle(color: c.textMuted)),
        ],
      ),
    );
  }

  // ---------- Pie Chart Aggregate: Status Stiker (kartu klik) ----------
  Widget _stickerPieSection(BuildContext context) {
    final c = context.appColors;
    final total = _filtered.length;

    final sudah = _filtered
        .where((d) => d.statusStiker.trim().toLowerCase() == 'sudah')
        .length;
    final belum = total - sudah;

    const sudahColor = Color(0xFF16A34A);
    const belumColor = Color(0xFFF59E0B);

    double pct(int n) => total == 0 ? 0 : (n / total * 100);

    return Material(
      color: Colors.transparent,
      child: Clickable(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openStickerDetail(),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sticky_note_2_outlined, size: 20, color: c.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('STATUS STIKER',
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 13,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w700)),
                    ),
                    Icon(Icons.chevron_right, color: c.textMuted, size: 20),
                  ],
                ),
                const SizedBox(height: 14),
                total == 0
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                            child: Text('Belum ada data perangkat',
                                style: TextStyle(color: c.textMuted))),
                      )
                    : Row(
                        children: [
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 3,
                                centerSpaceRadius: 40,
                                sections: [
                                  PieChartSectionData(
                                    value: sudah.toDouble(),
                                    color: sudahColor,
                                    radius: 44,
                                    title:
                                        sudah > 0 ? '${pct(sudah).round()}%' : '',
                                    titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800),
                                  ),
                                  PieChartSectionData(
                                    value: belum.toDouble(),
                                    color: belumColor,
                                    radius: 44,
                                    title:
                                        belum > 0 ? '${pct(belum).round()}%' : '',
                                    titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _legendRow(context,
                                    color: sudahColor,
                                    label: 'Sudah',
                                    value:
                                        '$sudah perangkat (${pct(sudah).toStringAsFixed(1)}%)'),
                                const SizedBox(height: 10),
                                _legendRow(context,
                                    color: belumColor,
                                    label: 'Belum',
                                    value:
                                        '$belum perangkat (${pct(belum).toStringAsFixed(1)}%)'),
                                const SizedBox(height: 8),
                                Text('Ketuk untuk lihat daftar device',
                                    style: TextStyle(
                                        color: c.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendRow(BuildContext context,
      {required Color color, required String label, required String value}) {
    final c = context.appColors;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              Text(value,
                  style: TextStyle(color: c.textMuted, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  void _openStickerDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StickerDetailPage(devices: _filtered)),
    );
  }

  // ---------- Grid 2 kolom: statistik per varian ----------
  Widget _variantSection(BuildContext context) {
    final c = context.appColors;
    final categories = _activeCategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_filterKategori == 'Printer'
            ? 'STATISTIK PRINTER'
            : 'STATISTIK SPESIFIKASI',
            style: TextStyle(
                color: c.textMuted,
                fontSize: 12,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.86,
          ),
          itemCount: categories.length,
          itemBuilder: (context, i) => _variantCard(context, categories[i]),
        ),
      ],
    );
  }

  Widget _variantCard(BuildContext context, SpecCategory spec) {
    final c = context.appColors;
    final data = aggregate(_filtered, spec.grouper);
    final total = data.values.fold<int>(0, (a, b) => a + b);
    final rows = data.entries.toList();

    return Clickable(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openBreakdown(spec),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(spec.icon, size: 17, color: c.accent),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(spec.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('$total perangkat',
                  style: TextStyle(color: c.textMuted, fontSize: 11)),
              const SizedBox(height: 6),
              // Hanya 2 data teratas/utama pada tampilan awal.
              for (final entry in rows.take(2))
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(entry.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: c.textPrimary, fontSize: 12)),
                      ),
                      Text(entry.value.toString(),
                          style: TextStyle(
                              color: c.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              if (rows.isEmpty || rows.length < 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(rows.isEmpty ? 'Belum ada variant terisi' : '',
                      style: TextStyle(color: c.textMuted, fontSize: 11)),
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 34,
                child: OutlinedButton(
                  onPressed: () => _openBreakdown(spec),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.accent,
                    side: BorderSide(color: c.accent, width: 1.2),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                  child: const Text('Lihat Rincian',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openBreakdown(SpecCategory spec) {
    final data = aggregate(_filtered, spec.grouper);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpecBreakdownPage(
          title: spec.title,
          icon: spec.icon,
          data: data,
          devices: _filtered,
          grouper: spec.grouper,
        ),
      ),
    );
  }

  // ---------- CRUD ----------
  Future<void> _openForm(Device? device) async {
    final nextKode = null;
    if (!mounted) return;
    // Tambah data baru → pilih kategori dulu (Computer/Laptop/Printer),
    // lalu form terbuka dengan kategori terkunci. Edit → langsung ke form.
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => device == null
            ? CategoryPickerPage(nextKode: nextKode)
            : DeviceFormPage(device: device, nextKode: nextKode),
      ),
    );
    if (result == true) await _load();
  }
}
