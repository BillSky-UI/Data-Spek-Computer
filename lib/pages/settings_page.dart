import 'package:flutter/material.dart';

import '../app_info.dart';
import '../database/db_helper.dart';
import '../services/export_service.dart';
import '../services/saved_target.dart';
import '../services/settings_controller.dart';
import '../theme/app_theme.dart';
import 'change_pin_page.dart';

class SettingsPage extends StatefulWidget {
  final SettingsController settings;
  const SettingsPage({super.key, required this.settings});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;

  ThemeMode get _mode => widget.settings.mode;

  Future<void> _setTheme(ThemeMode m) async {
    await widget.settings.setMode(m);
    if (mounted) setState(() {});
  }

  Future<void> _export(String kind) async {
    setState(() => _busy = true);
    try {
      final devices = await DbHelper.instance.getAll();
      final service = ExportService.instance;
      final SavedTarget saved = kind == 'csv'
          ? await service.saveCsvToDownloads(devices)
          : await service.saveExcelToDownloads(devices);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Tersimpan di ${saved.location}: ${saved.path}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal ekspor: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Pengaturan')),
      body: _busy
          ? Center(child: CircularProgressIndicator(color: c.accent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle(context, 'Tema Aplikasi'),
                _card(
                  context,
                  children: [
                    _themeTile(context, ThemeMode.system, Icons.brightness_auto,
                        'Mengikuti sistem'),
                    _themeTile(context, ThemeMode.light, Icons.light_mode,
                        'Terang'),
                    _themeTile(context, ThemeMode.dark, Icons.dark_mode, 'Gelap'),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionTitle(context, 'Keamanan Aplikasi'),
                _card(
                  context,
                  children: [
                    _actionTile(context, Icons.password, 'Ubah PIN',
                        'Ganti PIN untuk membuka aplikasi', () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ChangePinPage()));
                    }),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionTitle(context, 'Master Data'),
                const SizedBox(height: 8),
                _masterCard(context),
                const SizedBox(height: 20),
                _sectionTitle(context, 'Data'),
                _card(
                  context,
                  children: [
                    _actionTile(context, Icons.table_chart, 'Ekspor ke Excel',
                        'Simpan .xlsx ke folder Download HP', () => _export('xlsx')),
                    const SizedBox(height: 6),
                    _actionTile(context, Icons.description, 'Ekspor ke CSV',
                        'Simpan .csv ke folder Download HP', () => _export('csv')),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionTitle(context, 'Informasi Aplikasi'),
                _card(
                  context,
                  children: [
                    _infoTile(context, Icons.computer, 'Nama Aplikasi',
                        AppInfo.name),
                    _infoTile(context, Icons.info_outline, 'Versi',
                        AppInfo.versionLabel),
                    _infoTile(
                        context,
                        Icons.storage,
                        'Basis Data',
                        DbHelper.instance.localMode
                            ? 'Lokal (SQLite) — offline'
                            : 'Supabase Cloud (real-time sync)'),
                    _infoTile(
                        context,
                        Icons.auto_awesome,
                        'Data Awal',
                        'Dimuat otomatis dari file Excel '
                            'saat aplikasi pertama kali dibuka'),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.computer, color: c.accent, size: 40),
                      const SizedBox(height: 8),
                      Text(AppInfo.name,
                          style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Versi ${AppInfo.versionLabel}',
                          style: TextStyle(
                              color: c.accent,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Manajemen inventaris spesifikasi komputer',
                          style: TextStyle(color: c.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title,
          style: TextStyle(
              color: c.textMuted,
              fontSize: 12,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _card(BuildContext context, {required List<Widget> children}) {
    final c = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.border),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _themeTile(
      BuildContext context, ThemeMode mode, IconData icon, String label) {
    final c = context.appColors;
    final selected = _mode == mode;
    return ListTile(
      leading: Icon(icon, color: selected ? c.accent : c.textMuted),
      title: Text(label, style: TextStyle(color: c.textPrimary)),
      trailing: selected
          ? Icon(Icons.check_circle, color: c.accent)
          : Icon(Icons.circle_outlined, color: c.border),
      onTap: () => _setTheme(mode),
    );
  }

  Widget _actionTile(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    final c = context.appColors;
    return ListTile(
      leading: Icon(icon, color: c.blue, size: 26),
      title: Text(title, style: TextStyle(color: c.textPrimary, fontSize: 14)),
      subtitle:
          Text(subtitle, style: TextStyle(color: c.textMuted, fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: c.textMuted),
      onTap: onTap,
    );
  }

  Widget _infoTile(BuildContext context, IconData icon, String label, String value) {
    final c = context.appColors;
    return ListTile(
      leading: Icon(icon, color: c.accent, size: 24),
      title: Text(label, style: TextStyle(color: c.textMuted, fontSize: 13)),
      subtitle: Text(value,
          style: TextStyle(color: c.textPrimary, fontSize: 14)),
    );
  }

  // ---------- Master Data (sembunyi sampai diklik) ----------

  Widget _masterCard(BuildContext context) {
    final c = context.appColors;
    return _card(
      context,
      children: [
        _masterToggle(
          context,
          icon: Icons.business_outlined,
          title: 'Edit Bagian',
          count: _bagianList.length,
          expanded: _showBagian,
          onTap: () => setState(() => _showBagian = !_showBagian),
        ),
        Divider(height: 1, color: c.border),
        _masterToggle(
          context,
          icon: Icons.account_tree_outlined,
          title: 'Edit Plan',
          count: _planList.length,
          expanded: _showPlan,
          onTap: () => setState(() => _showPlan = !_showPlan),
        ),
        if (_showBagian) ...[
          Divider(height: 1, color: c.border),
          ..._bagianItems(context),
        ],
        if (_showPlan) ...[
          Divider(height: 1, color: c.border),
          ..._planItems(context),
        ],
      ],
    );
  }

  Widget _masterToggle(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int count,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    final c = context.appColors;
    return ListTile(
      leading: Icon(icon, color: c.blue, size: 26),
      title: Text(title, style: TextStyle(color: c.textPrimary, fontSize: 14)),
      subtitle: Text(count == 0 ? 'Belum ada data' : '$count data tersimpan',
          style: TextStyle(color: c.textMuted, fontSize: 12)),
      trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more,
          color: c.textMuted),
      onTap: onTap,
    );
  }

  List<Widget> _bagianItems(BuildContext context) {
    final c = context.appColors;
    return <Widget>[
      if (_bagianList.isEmpty)
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text('Belum ada bagian. Tambah bagian baru di bawah.',
              style: TextStyle(color: c.textMuted, fontSize: 13)),
        )
      else
        for (var i = 0; i < _bagianList.length; i++)
          ListTile(
            dense: true,
            leading: Icon(Icons.business_outlined, color: c.accent, size: 22),
            title: Text(_bagianList[i],
                style: TextStyle(color: c.textPrimary, fontSize: 14)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit bagian',
                  icon: Icon(Icons.edit_outlined, color: c.blue, size: 20),
                  onPressed: () => _showEditBagianDialog(_bagianList[i]),
                ),
                IconButton(
                  tooltip: 'Hapus bagian',
                  icon: Icon(Icons.delete_outline, color: c.danger, size: 20),
                  onPressed: () => _deleteBagian(_bagianList[i]),
                ),
              ],
            ),
          ),
      Divider(height: 1, color: c.border),
      ListTile(
        leading: Icon(Icons.add_circle_outline, color: c.blue, size: 24),
        title: Text('Tambah Bagian Baru',
            style: TextStyle(color: c.textPrimary, fontSize: 14)),
        subtitle: Text('Nama bagian baru untuk pilihan di form',
            style: TextStyle(color: c.textMuted, fontSize: 12)),
        onTap: _showAddBagianDialog,
      ),
    ];
  }

  List<Widget> _planItems(BuildContext context) {
    final c = context.appColors;
    return <Widget>[
      if (_planList.isEmpty)
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text('Belum ada PLAN. Tambah PLAN baru di bawah.',
              style: TextStyle(color: c.textMuted, fontSize: 13)),
        )
      else
        for (var i = 0; i < _planList.length; i++)
          ListTile(
            dense: true,
            leading:
                Icon(Icons.account_tree_outlined, color: c.accent, size: 22),
            title: Text(_planList[i],
                style: TextStyle(color: c.textPrimary, fontSize: 14)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit PLAN',
                  icon: Icon(Icons.edit_outlined, color: c.blue, size: 20),
                  onPressed: () => _showEditPlanDialog(_planList[i]),
                ),
                IconButton(
                  tooltip: 'Hapus PLAN',
                  icon: Icon(Icons.delete_outline, color: c.danger, size: 20),
                  onPressed: () => _deletePlan(_planList[i]),
                ),
              ],
            ),
          ),
      Divider(height: 1, color: c.border),
      ListTile(
        leading: Icon(Icons.add_circle_outline, color: c.blue, size: 24),
        title: Text('Tambah PLAN Baru',
            style: TextStyle(color: c.textPrimary, fontSize: 14)),
        subtitle: Text('PLAN ini muncul di dropdown form perangkat',
            style: TextStyle(color: c.textMuted, fontSize: 12)),
        onTap: _showAddPlanDialog,
      ),
    ];
  }

  List<String> _bagianList = [];
  List<String> _planList = [];
  bool _showBagian = false;
  bool _showPlan = false;

  @override
  void initState() {
    super.initState();
    _reloadBagian();
    _reloadPlan();
    // Update otomatis saat bagian berubah di cloud / perangkat lain.
    DbHelper.instance.addListener(_onDbChanged);
  }

  @override
  void dispose() {
    DbHelper.instance.removeListener(_onDbChanged);
    super.dispose();
  }

  void _onDbChanged() {
    _reloadBagian();
    _reloadPlan();
  }

  Future<void> _reloadBagian() async {
    final list = await DbHelper.instance.getBagianMaster();
    if (mounted) setState(() => _bagianList = list);
  }

  Future<void> _reloadPlan() async {
    final list = await DbHelper.instance.getPlanMaster();
    if (mounted) setState(() => _planList = list);
  }

  Future<void> _showAddBagianDialog() async {
    final c = context.appColors;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Bagian Baru'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'cth: Keuangan'),
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
    if (result == null || result.trim().isEmpty) return;
    final ok = await DbHelper.instance.addBagian(result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Bagian baru ditambahkan' : 'Gagal menambah bagian')));
  }

  Future<void> _showEditBagianDialog(String oldName) async {
    final c = context.appColors;
    final controller = TextEditingController(text: oldName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Bagian'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nama bagian'),
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
    if (result == null || result.trim().isEmpty || result.trim() == oldName) {
      return;
    }
    final ok = await DbHelper.instance.updateBagian(oldName, result.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(ok ? 'Bagian diperbarui (sinkron cloud)' : 'Gagal update bagian')));
  }

  Future<void> _deleteBagian(String name) async {
    final c = context.appColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Bagian', style: TextStyle(fontSize: 17)),
        content: Text(
          'Hapus bagian "$name"? Perangkat yang memakai bagian ini '
          'tidak ikut terhapus.',
          style: TextStyle(color: c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await DbHelper.instance.deleteBagian(name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(ok ? 'Bagian dihapus (sinkron cloud)' : 'Gagal hapus bagian')));
  }

  // ---------- Master Data PLAN (CRUD, sinkron cloud) ----------

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
          decoration: const InputDecoration(hintText: 'cth: PLAN 4'),
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
    final ok = await DbHelper.instance.addPlan(result);
    await _reloadPlan();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'PLAN baru ditambahkan' : 'Gagal menambah PLAN')));
  }

  Future<void> _showEditPlanDialog(String oldName) async {
    final c = context.appColors;
    final controller = TextEditingController(text: oldName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit PLAN'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nama PLAN'),
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
    if (result == null || result.trim().isEmpty || result.trim() == oldName) {
      return;
    }
    final ok = await DbHelper.instance.updatePlan(oldName, result.trim());
    await _reloadPlan();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'PLAN diperbarui' : 'Gagal update PLAN')));
  }

  Future<void> _deletePlan(String name) async {
    final c = context.appColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus PLAN', style: TextStyle(fontSize: 17)),
        content: Text(
          'Hapus PLAN "$name"? Perangkat yang memakai PLAN ini '
          'tidak ikut terhapus.',
          style: TextStyle(color: c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await DbHelper.instance.deletePlan(name);
    await _reloadPlan();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'PLAN dihapus' : 'Gagal hapus PLAN')));
  }
}