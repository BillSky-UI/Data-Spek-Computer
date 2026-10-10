import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../database/db_helper.dart';
import '../models/device.dart';
import '../services/public_saver_service.dart';
import '../services/sticker_pdf_service.dart';
import '../theme/app_theme.dart';
import '../utils/field_groups.dart';
import '../utils/kode_normalizer.dart';
import '../widgets/clickable.dart';

/// Halaman "Cetak Stiker Massal": pilih perangkat mana saja yang mau dicetak
/// (via kode inventaris seperti K-030, K-035, K-055 — atau centang di daftar),
/// lalu bangun SATU PDF berisi semua stiker dan unduh/bagikan.
class BulkStickerPage extends StatefulWidget {
  const BulkStickerPage({super.key});

  @override
  State<BulkStickerPage> createState() => _BulkStickerPageState();
}

class _BulkStickerPageState extends State<BulkStickerPage> {
  final DbHelper _db = DbHelper.instance;
  final TextEditingController _kodeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<Device> _all = [];
  bool _loading = true;
  bool _busy = false;
  String _filterCategory = '';

  /// Id perangkat terpilih (urutan penyimpanan = urutan cetak, Set di Dart
  /// mempertahankan urutan penyisipan).
  final Set<int> _terpilih = <int>{};

  static const _categories = ['Computer', 'Laptop', 'Printer'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _kodeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final devices = await _db.getAll();
    if (!mounted) return;
    setState(() {
      _all = devices;
      _loading = false;
    });
  }

  List<Device> get _tercetak =>
      _all.where((d) => _terpilih.contains(d.id)).toList();

  /// Kandidat yang tampil di daftar (filter kategori + pencarian).
  List<Device> get _kandidat {
    final q = _searchController.text.trim().toLowerCase();
    return _all.where((d) {
      if (_filterCategory.isNotEmpty &&
          categoryKey(d.category) != _filterCategory) {
        return false;
      }
      if (q.isEmpty) return true;
      bool c(String? v) => v != null && v.toLowerCase().contains(q);
      return c(d.kodeInventaris) ||
          c(d.deviceName) ||
          c(d.bagian) ||
          c(d.plan);
    }).toList();
  }

  /// Ambil kode yang diketik/ditempel (pisahkan koma/enter/spasi), lalu
  /// centang perangkat yang cocok. Format kode toleran: "K-0035" == "K-035".
  void _tambahDariKode() {
    final teks = _kodeController.text;
    final typed = <String>{};
    for (final token in teks.split(RegExp(r'[,\s;]+'))) {
      if (token.trim().isEmpty) continue;
      final key = canonicalKode(token);
      if (key.isNotEmpty) typed.add(key);
    }
    if (typed.isEmpty) return;

    final ditemukan = <Device>[];
    for (final d in _all) {
      if (typed.contains(canonicalKode(d.kodeInventaris))) {
        ditemukan.add(d);
      }
    }
    setState(() {
      for (final d in ditemukan) {
        if (d.id != null) _terpilih.add(d.id!);
      }
    });
    _kodeController.clear();

    final belumTersedia =
        typed.length - ditemukan.map((d) => canonicalKode(d.kodeInventaris)).toSet().length;
    final c = context.appColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: c.accent,
        content: Text(
          ditemukan.isEmpty
              ? 'Tidak ada kode yang cocok dengan data.'
              : '${ditemukan.length} kode ditemukan dan dipilih.'
                  '${belumTersedia > 0 ? ' $belumTersedia tidak tersedia.' : ''}',
        ),
      ),
    );
  }

  void _toggle(Device d) {
    final id = d.id;
    if (id == null) return;
    setState(() {
      if (!_terpilih.add(id)) _terpilih.remove(id);
    });
  }

  Future<Uint8List> _build() =>
      StickerPdfService.instance.buildStickerBatch(_tercetak);

  String get _fileName {
    final t = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    return 'Stiker_Massal_${t.year}${p(t.month)}${p(t.day)}_${p(t.hour)}${p(t.minute)}.pdf';
  }

  Future<void> _cetak() async {
    setState(() => _busy = true);
    try {
      final bytes = await _build();
      final target = await PublicSaverService.instance.savePdfToDownloads(
        bytes,
        _fileName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF166534),
          content: Text(
            '${_tercetak.length} stiker tersimpan di ${target.location}: ${target.path}',
          ),
        ),
      );
    } catch (e) {
      _toast('Gagal mencetak stiker: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bagikan() async {
    setState(() => _busy = true);
    try {
      final bytes = await _build();
      final name = _fileName;
      if (kIsWeb) {
        final target = await PublicSaverService.instance.savePdfToDownloads(
          bytes,
          name,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF166534),
            content: Text(
              '${_tercetak.length} stiker tersimpan di ${target.location}: ${target.path}',
            ),
          ),
        );
      } else {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(bytes, mimeType: 'application/pdf', name: name),
            ],
            subject: 'Stiker Massal',
            text: 'PDF stiker inventaris (${_tercetak.length} unit)',
          ),
        );
      }
    } catch (e) {
      _toast('Gagal membagikan stiker: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final n = _tercetak.length;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Cetak Stiker Massal')),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                _kodeSection(context),
                const SizedBox(height: 16),
                if (n > 0) ...[
                  _ringkasanTerpilih(context),
                  const SizedBox(height: 16),
                ],
                _searchBar(context),
                const SizedBox(height: 10),
                _kategoriChips(context),
                const SizedBox(height: 8),
                if (_kandidat.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(Icons.search_off, size: 48, color: c.emptyIcon),
                        const SizedBox(height: 8),
                        Text('Tidak ada perangkat',
                            style: TextStyle(color: c.textMuted)),
                      ],
                    ),
                  )
                else
                  for (final d in _kandidat) _deviceTile(context, d),
              ],
            ),
      bottomNavigationBar: _bottomBar(context, n),
    );
  }

  // ---------- Input kode ----------
  Widget _kodeSection(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pilih berdasarkan kode inventaris',
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(
          'Tempel kode, pisahkan koma / enter / spasi. '
          'Format tidak masalah: K-035 dan K-0035 dianggap sama.',
          style: TextStyle(color: c.textMuted, fontSize: 11, height: 1.35),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _kodeController,
          minLines: 2,
          maxLines: 4,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: 'Misal: K-030, K-035, K-055',
            hintStyle: TextStyle(color: c.inputHint),
            filled: true,
            fillColor: c.surface,
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
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: _tambahDariKode,
            icon: const Icon(Icons.task_alt, size: 18),
            label: const Text('Cari & pilih kode',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              backgroundColor: c.blue.withValues(alpha: 0.14),
              foregroundColor: c.blue,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11)),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Ringkasan terpilih ----------
  Widget _ringkasanTerpilih(BuildContext context) {
    final c = context.appColors;
    final list = _tercetak;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.blue.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: c.blue, size: 18),
              const SizedBox(width: 6),
              Text('${list.length} stiker dipilih',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(_terpilih.clear),
                child: Text('Kosongkan',
                    style: TextStyle(color: c.danger, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in list)
                _kodeChip(context, d),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kodeChip(BuildContext context, Device d) {
    final c = context.appColors;
    return Material(
      color: c.surfaceAlt,
      borderRadius: BorderRadius.circular(999),
      child: Clickable(
        child: InkWell(
          onTap: () => _toggle(d),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(d.kodeInventaris,
                    style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                Icon(Icons.close,
                    color: c.textMuted, size: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Pencarian & filter kategori ----------
  Widget _searchBar(BuildContext context) {
    final c = context.appColors;
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      style: TextStyle(color: c.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Cari kode / nama / bagian...',
        hintStyle: TextStyle(color: c.inputHint),
        prefixIcon: Icon(Icons.search, color: c.textMuted, size: 20),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.clear, color: c.textMuted, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              ),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
    );
  }

  Widget _kategoriChips(BuildContext context) {
    final c = context.appColors;
    Widget chip(String key, String label, IconData icon) {
      final selected = _filterCategory == key;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Clickable(
          child: ChoiceChip(
            selected: selected,
            showCheckmark: false,
            avatar: Icon(icon,
                size: 15, color: selected ? c.onAccent : c.textMuted),
            label: Text(label),
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
            onSelected: (_) =>
                setState(() => _filterCategory = selected ? '' : key),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('', 'Semua', Icons.apps),
          for (final k in _categories)
            chip(k, k, k == 'Laptop' ? Icons.laptop_mac : (k == 'Printer' ? Icons.print : Icons.computer)),
        ],
      ),
    );
  }

  // ---------- Baris perangkat ----------
  Widget _deviceTile(BuildContext context, Device d) {
    final c = context.appColors;
    final dipilih = d.id != null && _terpilih.contains(d.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        child: Clickable(
          child: InkWell(
            onTap: () => _toggle(d),
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: dipilih ? c.blue : c.border,
                    width: dipilih ? 1.5 : 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: dipilih ? c.blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: dipilih ? c.blue : c.textMuted),
                    ),
                    alignment: Alignment.center,
                    child: dipilih
                        ? Icon(Icons.check, color: c.onAccent, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${d.kodeInventaris} · ${display(d.deviceName)}',
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${display(d.bagian)}${d.plan.trim().isNotEmpty ? ' · ${d.plan.trim()}' : ''}',
                          style:
                              TextStyle(color: c.textMuted, fontSize: 11.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(categoryKey(d.category),
                        style: TextStyle(
                            color: c.blue,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Bar bawah: Bagikan / Cetak ----------
  Widget _bottomBar(BuildContext context, int n) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: n == 0 || _busy ? null : _bagikan,
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Bagikan',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1565C0),
                  side: const BorderSide(color: Color(0xFF1565C0)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: n == 0 || _busy ? null : _cetak,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download, size: 18),
                label: Text(n == 0 ? 'Pilih stiker' : 'Cetak $n stiker',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}