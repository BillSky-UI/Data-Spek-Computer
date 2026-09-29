import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/device.dart';
import '../services/public_saver_service.dart';
import '../services/sticker_pdf_service.dart';
import '../theme/app_theme.dart';
import '../utils/field_groups.dart';

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
  bool _busy = false;

  Device get _d => widget.device;
  String get _safeKode =>
      _d.kodeInventaris.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  String get _fileName => 'Stiker_$_safeKode.pdf';

  Future<Uint8List> _build() => StickerPdfService.instance.buildSticker(_d);

  /// Keterangan label sesuai desain yang dipakai kategori ini.
  String get _deskripsi => _isPrinter
      ? 'PDF label printer 7,6 x 3,8 cm persis mengikuti '
        '"Label Inventaris Kantor": Nama Barang (Tipe/Model), Bagian, '
        'Nama PIC, Kode Unit, dan Keterangan.'
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
