import 'package:flutter/material.dart';

import '../database/db_helper.dart';
import '../models/device.dart';
import '../theme/app_theme.dart';
import '../utils/field_groups.dart';

class DeviceFormPage extends StatefulWidget {
  final Device? device;
  final String? nextKode;
  /// Kategori terpilih dari halaman pemilihan awal (Computer/Laptop/Printer).
  /// Saat diisi untuk data baru, dropdown Category dikunci sesuai pilihan.
  final String? category;
  const DeviceFormPage(
      {super.key, this.device, this.nextKode, this.category});

  @override
  State<DeviceFormPage> createState() => _DeviceFormPageState();
}

class _DeviceFormPageState extends State<DeviceFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _db = DbHelper.instance;

  late final TextEditingController _kode;
  late final TextEditingController _tanggal;
  String _plan = '';
  String _bagian = '';
  late final TextEditingController _deviceName;
  String _category = 'Computer';
  late final TextEditingController _prosesor;
  late final TextEditingController _motherboard;
  late final TextEditingController _ram;
  late final TextEditingController _storage;
  late final TextEditingController _os;
  late final TextEditingController _goal;
  String _ganti = 'No';
  String _repair = 'No';
  String _status = 'Pending';
  late final TextEditingController _keterangan;
  String _stiker = 'Belum';
  late final TextEditingController _driveLink;

  List<String> _bagianMaster = [];
  List<String> _planMaster = [];

  /// Kategori terkunci saat tambah data baru yang berasal dari halaman
  /// pemilihan kategori (tidak bisa diganti manual di dropdown).
  bool get _categoryLocked => !_isEdit && widget.category != null;

  /// Form khusus Printer: label spesifikasi disesuaikan untuk printer
  /// (bukan Processor/Motherboard/RAM/OS Windows ala PC).
  bool get _isPrinter => categoryKey(_category) == 'Printer';

  bool get _isEdit => widget.device != null;

  @override
  void initState() {
    super.initState();
    final d = widget.device;
    _kode = TextEditingController(
        text: d?.kodeInventaris ?? widget.nextKode ?? '');
    _tanggal = TextEditingController(text: d?.tanggalEvaluasi ?? '');
    _plan = d?.plan ?? '';
    _bagian = d?.bagian ?? '';
    _deviceName = TextEditingController(text: d?.deviceName ?? '');
    _category = d?.category.trim().isNotEmpty == true
        ? d!.category.trim()
        : (widget.category ?? 'Computer');
    if (d == null && _kode.text.trim().isEmpty) {
      _fillNextKode();
    }
    _prosesor = TextEditingController(text: d?.prosesor ?? '');
    _motherboard = TextEditingController(text: d?.motherboard ?? '');
    _ram = TextEditingController(text: d?.ram ?? '');
    _storage = TextEditingController(text: d?.storage ?? '');
    _os = TextEditingController(text: d?.osWindows ?? '');
    _goal = TextEditingController(text: d?.goal ?? '');
    _ganti = d?.perluUpgradeGanti.trim().isNotEmpty == true
        ? d!.perluUpgradeGanti.trim()
        : 'No';
    _repair = d?.perluUpgradeRepair.trim().isNotEmpty == true
        ? d!.perluUpgradeRepair.trim()
        : 'No';
    _status = d?.statusUpgrade.trim().isNotEmpty == true
        ? d!.statusUpgrade.trim()
        : 'Pending';
    _keterangan = TextEditingController(text: d?.keterangan ?? '');
    _stiker = d?.statusStiker.trim().isNotEmpty == true
        ? d!.statusStiker.trim()
        : 'Belum';
    _driveLink = TextEditingController(text: d?.driveLink ?? '');
    _loadMasters();
  }

  /// Isi kode inventaris otomatis per kategori (K-/L-/P-).
  Future<void> _fillNextKode() async {
    final cat = _category.isNotEmpty ? _category : (widget.category ?? 'Computer');
    final next = await _db.nextKode(cat);
    if (!mounted) return;
    _kode.text = next;
  }

  Future<void> _loadMasters() async {
    final bagian = await _db.getBagianMaster();
    final plan = await _db.getPlanMaster();
    if (!mounted) return;
    setState(() {
      _bagianMaster = bagian;
      _planMaster = plan;
      // pastikan nilai yang sedang aktif tetap ada di daftar
      if (_bagian.isNotEmpty && !_bagianMaster.contains(_bagian)) {
        _bagianMaster = [_bagian, ..._bagianMaster];
      }
      if (_plan.isNotEmpty && !_planMaster.contains(_plan)) {
        _planMaster = [_plan, ..._planMaster];
      }
    });
  }

  @override
  void dispose() {
    for (final c in [
      _kode, _tanggal, _deviceName, _prosesor,
      _motherboard, _ram, _storage, _os, _goal, _keterangan, _driveLink
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final c = context.appColors;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _parseDate(_tanggal.text) ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: c.accent,
                onPrimary: c.onAccent,
                surface: c.surface,
                onSurface: c.textPrimary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final dd = picked.day.toString().padLeft(2, '0');
      final mm = picked.month.toString().padLeft(2, '0');
      setState(() => _tanggal.text = '$dd/$mm/${picked.year}');
    }
  }

  DateTime? _parseDate(String s) {
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(s);
    if (m != null) {
      return DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!),
          int.parse(m.group(1)!));
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final d = Device(
      id: widget.device?.id,
      kodeInventaris: _kode.text.trim(),
      tanggalEvaluasi: _tanggal.text.trim(),
      plan: _plan,
      bagian: _bagian,
      deviceName: _deviceName.text.trim(),
      category: _category,
      prosesor: _prosesor.text.trim(),
      motherboard: _motherboard.text.trim(),
      ram: _ram.text.trim(),
      storage: _storage.text.trim(),
      osWindows: _os.text.trim(),
      goal: _goal.text.trim(),
      perluUpgradeGanti: _ganti,
      perluUpgradeRepair: _repair,
      statusUpgrade: _status,
      keterangan: _keterangan.text.trim(),
      statusStiker: _stiker,
      driveLink: _driveLink.text.trim(),
    );

    if (_isEdit) {
      await _db.update(d);
    } else {
      await _db.insert(d);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Data diperbarui' : 'Data ditambahkan')));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Data' : 'Tambah Data'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle(context, 'INFORMASI PERANGKAT'),
            _lockedKode(context),
            _field(context, _tanggal, 'Tanggal Evaluasi', 'dd/mm/yyyy',
                onTap: _pickDate, suffix: Icons.calendar_today),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _dropdown(context,
                      label: 'PLAN', value: _plan, options: _planMaster,
                      onChanged: (v) => setState(() => _plan = v ?? ''),
                      hint: 'Pilih PLAN'),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: IconButton(
                    tooltip: 'Tambah PLAN baru',
                    icon: Icon(Icons.add_circle_outline, color: c.blue),
                    onPressed: _showAddPlanDialog,
                  ),
                ),
              ],
            ),
            _dropdown(context, label: 'Bagian', value: _bagian, options: _bagianMaster,
                onChanged: (v) => setState(() => _bagian = v ?? ''), hint: 'Pilih Bagian'),
            _field(context, _deviceName, 'Device Name *', 'Nama device / user',
                required: true),
            if (_categoryLocked)
              _lockedCategory(context)
            else
              _dropdown(context, label: 'Category',
                  value: _category,
                  options: _fixedOptions(_category, const ['Computer', 'Printer', 'Laptop']),
                  onChanged: (v) {
                    setState(() => _category = v ?? _category);
                    if (!_isEdit) _fillNextKode();
                  },
                  hint: 'Pilih Kategori'),
            _sectionTitle(context, _isPrinter ? 'DETAIL PRINTER' : 'SPECIFIKASI LENGKAP'),
            _field(context, _prosesor, labelFor('prosesor', _category),
                _isPrinter ? 'cth: Epson L3210' : 'cth: Intel Core i5',
                maxLines: 3),
            _field(context, _motherboard, labelFor('motherboard', _category),
                _isPrinter ? 'cth: USB + WiFi + LAN' : 'cth: H81M-K'),
            if (!_isPrinter)
            _field(context, _ram, labelFor('ram', _category),
                _isPrinter ? 'cth: 33 ppm monokrom' : 'cth: 16 GBytes'),
            if (!_isPrinter)
            _field(context, _storage, labelFor('storage', _category),
                _isPrinter ? 'cth: A4, tray 2 x 250 lembar' : 'Detail storage / disk',
                maxLines: 3),
            if (!_isPrinter)
            _field(context, _os, labelFor('osWindows', _category),
                _isPrinter ? 'cth: Windows 10 / macOS / Linux' : 'cth: Windows 10 Pro',
                maxLines: 2),
            if (!_isPrinter)
            _field(context, _goal, labelFor('goal', _category),
                _isPrinter ? 'cth: Tinta terisi' : 'cth: Tercapai'),
            _dropdown(context, label: labelFor('perluUpgradeGanti', _category),
                value: _ganti,
                options: _fixedOptions(_ganti, const ['Yes', 'No']),
                onChanged: (v) => setState(() => _ganti = v ?? _ganti),
                hint: 'Pilih Yes / No'),
            _dropdown(context, label: labelFor('perluUpgradeRepair', _category),
                value: _repair,
                options: _fixedOptions(_repair, const ['Yes', 'No']),
                onChanged: (v) => setState(() => _repair = v ?? _repair),
                hint: 'Pilih Yes / No'),
            _dropdown(context, label: labelFor('statusUpgrade', _category),
                value: _status,
                options: _fixedOptions(_status, const ['Complated', 'Pending']),
                onChanged: (v) => setState(() => _status = v ?? _status),
                hint: 'Pilih Complated / Pending'),
            _field(context, _keterangan, 'Keterangan', 'Catatan', maxLines: 3),
            _dropdown(context, label: 'Status Stiker',
                value: _stiker,
                options: _fixedOptions(_stiker, const ['Sudah', 'Belum']),
                onChanged: (v) => setState(() => _stiker = v ?? _stiker),
                hint: 'Pilih Sudah / Belum'),
            _field(context, _driveLink,
                'Link Google Drive Spesifikasi (opsional)',
                'https://drive.google.com/file/d/... (di-encode ke QR barcode)',
                maxLines: 3),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: c.onAccent,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_isEdit ? 'Simpan Perubahan' : 'Simpan',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Gabungkan nilai yang sedang aktif dengan daftar tetap, agar
  /// DropdownButtonFormField tidak error saat nilai lama (mis. "Komputer")
  /// tidak tercantum di daftar pilihan baru.
  List<String> _fixedOptions(String current, List<String> fixed) {
    final v = current.trim();
    if (v.isEmpty || fixed.contains(v)) return fixed;
    return [v, ...fixed];
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Row(
        children: [
          Text(title,
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 2, color: c.accent)),
        ],
      ),
    );
  }

  /// Tampilan kategori terkunci (dari halaman pemilihan awal), bukan dropdown.
  Future<void> _showAddPlanDialog() async {
    final c = context.appColors;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah PLAN Baru'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'cth: PLAN 1'),
          style: TextStyle(color: c.textPrimary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Simpan')),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty) return;
    final ok = await _db.addPlan(result);
    if (!mounted) return;
    if (ok) {
      final list = await _db.getPlanMaster();
      if (!mounted) return;
      setState(() {
        _planMaster = list;
        _plan = result.trim();
      });
      final saved = result.trim();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PLAN "' + saved + '" ditambahkan')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menambah PLAN')));
    }
  }

  Widget _lockedKode(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kode Inventaris',
              style: TextStyle(color: c.textMuted, fontSize: 13)),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: c.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.blue.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: [
                Icon(Icons.confirmation_number_outlined, color: c.blue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_kode.text,
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
                Icon(Icons.lock_outline, color: c.textMuted, size: 16),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('Terisi otomatis per kategori dan tidak bisa diubah.',
              style: TextStyle(color: c.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _lockedCategory(BuildContext context) {
    final c = context.appColors;
    final icon = _isPrinter
        ? Icons.print
        : (_category.toLowerCase().contains('laptop')
            ? Icons.laptop_mac
            : Icons.computer);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Category',
              style: TextStyle(color: c.textMuted, fontSize: 13)),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: c.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.blue.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: [
                Icon(icon, color: c.blue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_category,
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
                Icon(Icons.lock_outline, color: c.textMuted, size: 16),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('Kategori terkunci sesuai pilihan tadi.',
              style: TextStyle(color: c.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _dropdown(
    BuildContext context, {
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    required String hint,
  }) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: c.textMuted, fontSize: 13)),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            initialValue: value.isEmpty ? null : value,
            isExpanded: true,
            dropdownColor: c.surface,
            style: TextStyle(color: c.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: c.inputHint),
              filled: true,
              fillColor: c.surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.accent, width: 1.5),
              ),
            ),
            items: [
              ...options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o))),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _field(BuildContext context, TextEditingController ctr, String label,
      String hint,
      {int maxLines = 1,
      bool required = false,
      VoidCallback? onTap,
      IconData? suffix}) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: c.textMuted, fontSize: 13)),
          const SizedBox(height: 5),
          TextFormField(
            controller: ctr,
            readOnly: onTap != null,
            onTap: onTap,
            maxLines: maxLines,
            style: TextStyle(color: c.textPrimary),
            validator: (v) => required && (v == null || v.trim().isEmpty)
                ? 'Wajib diisi'
                : null,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: c.inputHint),
              suffixIcon: suffix != null
                  ? Icon(suffix, color: c.accent)
                  : null,
              filled: true,
              fillColor: c.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.accent, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}