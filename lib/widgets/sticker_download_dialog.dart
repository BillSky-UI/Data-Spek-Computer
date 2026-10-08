import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/device.dart';
import '../services/public_saver_service.dart';
import '../services/sticker_pdf_service.dart';
import '../theme/app_theme.dart';
import '../utils/field_groups.dart';
import 'clickable.dart';

/// Dialog "Download Stiker PDF (Template)".
///
/// Membangun PDF stiker sesuai kategori perangkat:
/// - Printer -> label 7,6 x 3,8 cm (`Logo/Label Inventaris Kantor.pdf`);
/// - lainnya -> stiker 15,5 x 6 cm (`Logo/Template Stiker.pdf`).
///
/// Hasilnya disimpan ke folder Download publik (atau dibagikan).
class StickerDownloadDialog extends StatefulWidget {
  final Device device;
  const StickerDownloadDialog({super.key, required this.device});

  @override
  State<StickerDownloadDialog> createState() => _StickerDownloadDialogState();
}

class _StickerDownloadDialogState extends State<StickerDownloadDialog> {
  static const List<String> _storageOptions = [
    '8 GB',
    '16 GB',
    '32 GB',
    '64 GB',
    '128 GB',
    '256 GB',
    '512 GB',
    '1TB',
    '2TB',
  ];

  /// Tipe media penyimpanan yang bisa dipilih tiap ukuran storage.
  static const List<String> _typeOptions = ['SSD', 'HDD'];

  bool _busy = false;

  /// Jumlah unit tiap ukuran + tipe storage yang dipilih untuk dicetak (boleh
  /// lebih dari satu ukuran, tiap ukuran bisa lebih dari satu unit). Kunci map
  /// berbentuk `kapasitas spasi tipe`, misal `256 GB SSD`. Diinput nilai
  /// `storage` di database sering tidak konsisten namanya (mis. "256GB SSD
  /// Sata"), jadi saat cetak bisa dipilih ulang dengan rapi, misal 256 GB SSD
  /// ada 2 unit + 128 GB HDD ada 3 unit.
  final Map<String, int> _storageCount = <String, int>{};

  /// Pilihan tipe (SSD/HDD) per ukuran; kosong = pakai [_typeOf] bawaan.
  final Map<String, String> _storageType = <String, String>{};

  Device get _d => widget.device;
  String get _safeKode =>
      _d.kodeInventaris.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  String get _fileName => 'Stiker_$_safeKode.pdf';

  /// Tinggal format cetak untuk ukuran + tipe yang dipilih.
  ///
  /// Kapasitas ditulis dulu lalu jumlah unitnya ("256GB SSD 3x") supaya
  /// urutannya sama dengan data asal di perangkat. Spasi antara angka dan
  /// satuan dihapus agar ringkas, spasi sebelum tipe (SSD/HDD) tetap dijaga
  /// supaya terbaca, dan jumlah 1 unit tidak diulang.
  String _formatStorage(String o, int n) {
    final teks = o
        .replaceAll(' ', '')
        .replaceAllMapped(
          RegExp(r'(SSD|HDD)$'),
          (m) => ' ${m[1]}',
        );
    return n == 1 ? teks : '$teks ${n}x';
  }

  /// Total unit storage yang dicetak, untuk ringkasan di bawah daftar.
  int get _totalUnit => _storageCount.values.fold(0, (a, b) => a + b);

  /// Kunci map untuk (ukuran, tipe), misal `'256 GB SSD'`.
  String _entryKey(String size, String tipe) => '$size $tipe';

  /// Tipe bawaan tiap ukuran: SSD, kecuali data asli berisi "HDD".
  String _typeOf(String size) {
    final tersimpan = _storageType[size];
    if (tersimpan != null) return tersimpan;
    return _d.storage.toLowerCase().contains('hdd') ? 'HDD' : 'SSD';
  }

  /// Posisi ukuran dalam daftar [_storageOptions], dipakai untuk mengurutkan
  /// ringkasan supaya urutannya sama dengan daftarnya.
  int _indexOfSize(String key) {
    for (var i = 0; i < _storageOptions.length; i++) {
      if (key.startsWith('${_storageOptions[i]} ')) return i;
    }
    return _storageOptions.length;
  }

  /// Ringkasan storage terpilih, misal "256GB SSD 3x + 128GB HDD 2x".
  String get _storageTerpilih {
    final keys = _storageCount.keys.toList()..sort((a, b) {
      final i = _indexOfSize(a).compareTo(_indexOfSize(b));
      return i != 0 ? i : a.compareTo(b);
    });
    return keys.map((k) => _formatStorage(k, _storageCount[k]!)).join(' + ');
  }

  Future<Uint8List> _build() {
    if (_storageTerpilih.isNotEmpty) {
      final d = _d.copyWith()..storage = _storageTerpilih;
      return StickerPdfService.instance.buildSticker(d);
    }
    return StickerPdfService.instance.buildSticker(_d);
  }

  /// Keterangan label sesuai desain yang dipakai kategori ini.
  String get _deskripsi => _isPrinter
      ? 'PDF label printer 7,6 x 3,8 cm persis mengikuti '
        '"Label Inventaris Kantor": Nama Barang (Tipe/Model), Bagian, '
        'Nama PIC, Kode Unit, dan Tanggal Penyerahan.'
      : 'PDF stiker 15,5 x 6 cm (landscape) persis mengikuti '
        '"Template Stiker" (INVENTARIS & SPESIFIKASI, '
        'FRM-06/SOP-001-IT): grid identitas dan tabel perangkat '
        'keras (Mainboard/CPU/RAM/Memory/SSD).';

  bool get _isPrinter => categoryKey(_d.category) == 'Printer';

  Future<void> _download() async {
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
          content: Text(
            'Stiker PDF tersimpan di ${target.location}: ${target.path}',
          ),
          backgroundColor: const Color(0xFF166534),
        ),
      );
    } catch (e) {
      _toast('Gagal mengunduh stiker: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
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
            content: Text(
              'Stiker PDF tersimpan di ${target.location}: ${target.path}',
            ),
            backgroundColor: const Color(0xFF166534),
          ),
        );
      } else {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(bytes, mimeType: 'application/pdf', name: name),
            ],
            subject: 'Stiker ${_d.kodeInventaris}',
            text: 'Stiker PDF ${_d.kodeInventaris} - ${_d.deviceName}',
          ),
        );
      }
    } catch (e) {
      _toast('Gagal membagikan stiker: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Satu baris ukuran storage: label + pemilih tipe (SSD/HDD) + stepper
  /// jumlah unit (- 0 +). Barisnya bisa diklik untuk menambah 1 unit.
  Widget _storageRow(String size, int n) {
    final c = context.appColors;
    final dipakai = n > 0;
    return Material(
      color: dipakai ? c.blue.withValues(alpha: 0.08) : Colors.transparent,
      child: Clickable(
        child: InkWell(
        onTap: () => _ubahStorage(size, 1),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  size,
                  style: TextStyle(
                    color: dipakai ? c.textPrimary : c.textMuted,
                    fontSize: 12,
                    fontWeight: dipakai ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _typeToggle(size),
              const SizedBox(width: 6),
              _stepper(
                  icon: Icons.remove, onTap: n > 0 ? () => _ubahStorage(size, -1) : null),
              SizedBox(
                width: 24,
                child: Text(
                  '$n',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dipakai ? c.textPrimary : c.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _stepper(icon: Icons.add, onTap: () => _ubahStorage(size, 1)),
            ],
          ),
        ),
        ),
      ),
    );
  }

  /// Pilih tipe storage (SSD/HDD) untuk satu ukuran.
  Widget _typeToggle(String size) {
    final c = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _typeOptions.length; i++) ...[
            if (i > 0) Container(width: 1, height: 16, color: c.border),
            _typeChip(size, _typeOptions[i]),
          ],
        ],
      ),
    );
  }

  Widget _typeChip(String size, String tipe) {
    final c = context.appColors;
    final aktif = _typeOf(size) == tipe;
    return Clickable(
      child: InkWell(
        onTap: () => _gantiTipe(size, tipe),
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: aktif ? c.blue.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            tipe,
            style: TextStyle(
              color: aktif ? c.blue : c.textMuted,
              fontSize: 10,
              fontWeight: aktif ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepper({required IconData icon, VoidCallback? onTap}) {
    final c = context.appColors;
    return Material(
      color: c.surfaceAlt,
      borderRadius: BorderRadius.circular(8),
      child: Clickable(
        child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 30,
          height: 26,
          child: Icon(
            icon,
            size: 16,
            color: onTap == null ? c.textMuted.withValues(alpha: 0.35) : c.blue,
          ),
        ),
        ),
      ),
    );
  }

  void _ubahStorage(String size, int delta) {
    setState(() {
      final key = _entryKey(size, _typeOf(size));
      final hasil = (_storageCount[key] ?? 0) + delta;
      if (hasil <= 0) {
        _storageCount.remove(key);
      } else {
        _storageCount[key] = hasil;
      }
    });
  }

  /// Ganti tipe (SSD/HDD) untuk satu ukuran. Jumlah unit yang sudah dipilih
  /// ikut dipindahkan ke tipe baru supaya nilainya tidak hilang.
  void _gantiTipe(String size, String tipe) {
    if (_typeOf(size) == tipe) return;
    setState(() {
      final keyLama = _entryKey(size, _typeOf(size));
      final jum = _storageCount.remove(keyLama) ?? 0;
      if (jum > 0) _storageCount[_entryKey(size, tipe)] = jum;
      _storageType[size] = tipe;
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.sticky_note_2_outlined,
                      color: c.blue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Download Stiker PDF (Template)',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: c.textMuted, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _d.kodeInventaris,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _d.deviceName.trim().isEmpty
                          ? 'Tanpa nama'
                          : _d.deviceName.trim(),
                      style: TextStyle(color: c.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _deskripsi,
                style: TextStyle(
                  color: c.textMuted,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
              if (!_isPrinter) ...[
                const SizedBox(height: 14),
                Text(
                  'Storage yang dicetak (pilih kapasitas + tipe)',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pilih SSD atau HDD, ketuk baris untuk +1 unit, '
                  'atau pakai tombol - / +.',
                  style: TextStyle(color: c.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: c.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < _storageOptions.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, thickness: 1, color: c.border),
                        _storageRow(
                          _storageOptions[i],
                          _storageCount[
                                  _entryKey(
                                    _storageOptions[i],
                                    _typeOf(_storageOptions[i]),
                                  )] ??
                              0,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _storageTerpilih.isEmpty
                      ? 'Akan mengikuti data input: '
                          '${_d.storage.trim().isEmpty ? '(kosong)' : _d.storage.trim()}'
                      : 'Storage yang dicetak: $_storageTerpilih '
                          '($_totalUnit unit)',
                  style: TextStyle(color: c.textMuted, fontSize: 11),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _share,
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text(
                        'Bagikan',
                        style: TextStyle(color: Color(0xFF1565C0)),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1565C0),
                        side: const BorderSide(color: Color(0xFF1565C0)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _download,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download, size: 18),
                      label: const Text(
                        'Download PDF',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
