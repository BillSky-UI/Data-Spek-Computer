import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../database/db_helper.dart';
import '../models/device.dart';
import '../services/settings_controller.dart';
import '../theme/app_theme.dart';
import '../utils/field_groups.dart';
import '../widgets/app_popup_menu.dart';
import 'category_picker_page.dart';
import 'detail_page.dart';
import 'device_form_page.dart';
import 'scan_page.dart';

class DeviceListPage extends StatefulWidget {
  final SettingsController settings;
  const DeviceListPage({super.key, required this.settings});

  @override
  State<DeviceListPage> createState() => _DeviceListPageState();
}

class _DeviceListPageState extends State<DeviceListPage> {
  final DbHelper _db = DbHelper.instance;

  List<Device> _all = [];
  List<Device> _filtered = [];
  List<String> _bagianList = [];

  String _query = '';
  String _filterBagian = '';
  String _filterCategory = '';
  Map<String, int> _catCounts = {};
  bool _loading = true;

  static const _categories = ['Computer', 'Laptop', 'Printer'];

  @override
  void initState() {
    super.initState();
    _load();
    // real-time: update otomatis saat data berubah di cloud / perangkat lain.
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
    if (!mounted) return;
    setState(() {
      _all = devices;
      _bagianList =
          devices.map((d) => d.bagian).where((b) => b.trim().isNotEmpty).toSet().toList()
            ..sort();
      final counts = <String, int>{for (final k in _categories) k: 0};
      for (final d in devices) {
        final k = categoryKey(d.category);
        counts[k] = (counts[k] ?? 0) + 1;
      }
      _catCounts = counts;
      if (_filterCategory.isNotEmpty && !counts.containsKey(_filterCategory)) {
        _filterCategory = '';
      }
      _applyFilter();
      _loading = false;
    });
  }

  void _applyFilter() {
    final q = _query.trim().toLowerCase();
    _filtered = _all.where((d) {
      final matchQ = q.isEmpty ||
          d.kodeInventaris.toLowerCase().contains(q) ||
          d.deviceName.toLowerCase().contains(q);
      final matchBagian = _filterBagian.isEmpty || d.bagian == _filterBagian;
      final matchCat = _filterCategory.isEmpty ||
          categoryKey(d.category) == _filterCategory;
      return matchQ && matchBagian && matchCat;
    }).toList();
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
        title: const Text('Daftar Perangkat'),
        actions: [
          IconButton(
            tooltip: 'Scan QR / Barcode',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanPage()),
            ),
          ),
                    IconButton(
            tooltip: 'Impor dari Excel',
            icon: const Icon(Icons.upload_file),
            onPressed: () => _importExcel(context),
          ),
          AppPopupMenu(settings: widget.settings),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.accent))
          : Column(
              children: [
                _searchAndFilter(context),
                Expanded(child: _buildList(context)),
              ],
            ),
    );
  }

  // ---------- Tab utama kategori: Semua / Computer / Laptop / Printer ----------
  Widget _categoryTabs(BuildContext context) {
    final c = context.appColors;

    Widget chip(String value, String label, IconData icon, int count) {
      final selected = _filterCategory == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          selected: selected,
          showCheckmark: false,
          avatar: Icon(icon,
              size: 16,
              color: selected ? c.onAccent : c.textMuted),
          label: Text('$label ($count)'),
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
            _filterCategory = value;
            _applyFilter();
          }),
        ),
      );
    }

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('', 'Semua', Icons.apps, _all.length),
          for (final k in _categories)
            chip(k, k, _iconFor(k), _catCounts[k] ?? 0),
        ],
      ),
    );
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'Laptop':
        return Icons.laptop_mac;
      case 'Printer':
        return Icons.print;
      default:
        return Icons.computer;
    }
  }

  Widget _searchAndFilter(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() {
              _query = v;
              _applyFilter();
            }),
            style: TextStyle(color: c.textPrimary),
            decoration: InputDecoration(
              hintText: 'Cari Kode / Nama device...',
              hintStyle: TextStyle(color: c.inputHint),
              prefixIcon: Icon(Icons.search, color: c.textMuted),
              filled: true,
              fillColor: c.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _categoryTabs(context),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _filterBagian.isEmpty ? null : _filterBagian,
                  isExpanded: true,
                  dropdownColor: c.surface,
                  style: TextStyle(color: c.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Semua Bagian',
                    hintStyle: TextStyle(color: c.textMuted),
                    filled: true,
                    fillColor: c.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.border),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua Bagian')),
                    ..._bagianList.map((b) =>
                        DropdownMenuItem(value: b, child: Text(b))),
                  ],
                  onChanged: (v) => setState(() {
                    _filterBagian = v ?? '';
                    _applyFilter();
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border),
                ),
                child: Text(
                  '${_filtered.length}/${_all.length}',
                  style: TextStyle(
                      color: c.accent, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Impor file .xlsx -> tulis ke cloud Supabase (devices) + cache lokal
  /// sehingga WEB & APK memakai data impor ini sebagai default.
  Future<void> _importExcel(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final c = context.appColors;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      final file = result.isEmpty ? null : result.first;
      if (file == null) return;
      final bytes = await file.xFile.readAsBytes();
      final count = await DbHelper.instance.importExcelFile(bytes);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          backgroundColor: c.accent,
          content: Text(count > 0
              ? 'Impor Excel berhasil: $count perangkat tersimpan.'
              : 'File Excel kosong / kolom tidak dikenali.'),
        ));
      await _load();
    } catch (e) {
      debugPrintFallback('Gagal impor Excel: $e');
      if (!mounted) return;
      messenger
          .showSnackBar(SnackBar(content: Text('Gagal impor Excel: $e')));
    }
  }

  Widget _buildList(BuildContext context) {
    final c = context.appColors;
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: c.emptyIcon),
            const SizedBox(height: 10),
            Text('Tidak ada data yang cocok',
                style: TextStyle(color: c.textMuted)),
          ],
        ),
      );
    }
    // Pengelompokan per kategori dengan garis pemisah + judul.
    const order = <String>['Printer', 'Laptop', 'Computer'];
    const labels = <String, String>{
      'Printer': 'PRINTER',
      'Laptop': 'LAPTOP',
      'Computer': 'KOMPUTER',
    };
    final items = <Object>[];
    for (final key in order) {
      final group =
          _filtered.where((d) => categoryKey(d.category) == key).toList();
      if (group.isEmpty) continue;
      items.add(_GroupHeader(key, labels[key]!, _iconFor(key), group.length));
      items.addAll(group);
    }
    final known = order.toSet();
    final others =
        _filtered.where((d) => !known.contains(categoryKey(d.category))).toList();
    if (others.isNotEmpty) {
      items.add(const _GroupHeader('Lainnya', 'LAINNYA', Icons.devices_other, 0));
      items.addAll(others);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final it = items[i];
        if (it is _GroupHeader) {
          return _groupHeader(ctx, it.label, it.icon, it.count);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _card(context, it as Device),
        );
      },
    );
  }

  Widget _groupHeader(
      BuildContext context, String label, IconData icon, int count) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: c.blue),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6)),
          const SizedBox(width: 6),
          Text('($count)',
              style: TextStyle(color: c.textMuted, fontSize: 12)),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: c.border, thickness: 1)),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Device d) {
    final c = context.appColors;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailPage(device: d)),
        );
        await _load();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
                color: Color(0x22000000),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c.avatarGrad1, c.avatarGrad2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                (d.deviceName.trim().isNotEmpty
                        ? d.deviceName.trim()[0].toUpperCase()
                        : '?'),
                style: TextStyle(
                    color: c.avatarFg,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${d.kodeInventaris} · ${display(d.deviceName)}',
                    style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${display(d.bagian)}${d.plan.isNotEmpty ? ' · ${d.plan}' : ''}',
                    style: TextStyle(color: c.textMuted, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _chip(context, categoryKey(d.category), c.blueFg, c.blue
                    .withValues(alpha: 0.12), c.blue),
                const SizedBox(height: 5),
                _chip(context, d.plan.isEmpty ? '-' : d.plan, c.planChipFg,
                    c.planChipBg, c.planChipBg),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text, Color fg, Color bg,
      Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Text(text,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

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

class _GroupHeader {
  final String key;
  final String label;
  final IconData icon;
  final int count;
  const _GroupHeader(this.key, this.label, this.icon, this.count);
}