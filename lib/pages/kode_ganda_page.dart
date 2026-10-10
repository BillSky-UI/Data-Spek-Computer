import 'package:flutter/material.dart';

import '../database/db_helper.dart';
import '../models/device.dart';
import '../theme/app_theme.dart';
import '../utils/field_groups.dart';
import '../utils/kode_normalizer.dart';
import '../widgets/clickable.dart';
import 'detail_page.dart';

/// Halaman "Cek Kode Inventaris Ganda".
///
/// Memindai seluruh perangkat lalu mengelompokkan yang memakai kode sama
/// (format toleran: K-035 dianggap sama dengan K-0035). Setiap kelompok bisa
/// dibuka satu per satu ke halaman detail untuk diselesaikan.
class KodeGandaPage extends StatefulWidget {
  const KodeGandaPage({super.key});

  @override
  State<KodeGandaPage> createState() => _KodeGandaPageState();
}

class _KodeGandaPageState extends State<KodeGandaPage> {
  final DbHelper _db = DbHelper.instance;
  List<List<Device>> _grup = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _db.getAll();
    if (!mounted) return;
    setState(() {
      _grup = _db.temukanKodeGanda();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Cek Kode Ganda')),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.accent))
          : RefreshIndicator(
              color: c.accent,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  _banner(context),
                  const SizedBox(height: 12),
                  if (_grup.isEmpty)
                    _bersihState(context)
                  else
                    for (final g in _grup) _grupCard(context, g),
                ],
              ),
            ),
    );
  }

  Widget _banner(BuildContext context) {
    final c = context.appColors;
    final totalGanda = _grup.fold<int>(0, (a, g) => a + g.length);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.blue.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.rule, color: c.blue, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _grup.isEmpty
                  ? 'Tidak ada kode ganda. Semua kode inventaris unik.'
                  : '${_grup.length} kelompok kode ganda '
                      '($totalGanda perangkat) ditemukan.',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bersihState(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, size: 56, color: c.accent),
          const SizedBox(height: 12),
          Text('Data bersih — tidak ada kode ganda',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Kode dianggap sama walau beda format '
            '(K-035 = K-0035).',
            style: TextStyle(color: c.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _grupCard(BuildContext context, List<Device> grup) {
    final c = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.dangerBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: c.dangerBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  canonicalKode(grup.first.kodeInventaris),
                  style: TextStyle(
                      color: c.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8),
                ),
              ),
              const SizedBox(width: 8),
              Text('${grup.length} perangkat',
                  style: TextStyle(color: c.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          for (final (i, d) in grup.indexed) ...[
            if (i > 0) const SizedBox(height: 6),
            _deviceRow(context, d),
          ],
        ],
      ),
    );
  }

  Widget _deviceRow(BuildContext context, Device d) {
    final c = context.appColors;
    return Material(
      color: c.surfaceAlt,
      borderRadius: BorderRadius.circular(10),
      child: Clickable(
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetailPage(device: d)),
          ),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.avatarGrad1, c.avatarGrad2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (d.deviceName.trim().isNotEmpty
                            ? d.deviceName.trim()[0].toUpperCase()
                            : '?'),
                    style: TextStyle(
                        color: c.avatarFg,
                        fontSize: 14,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        display(d.deviceName),
                        style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${display(d.bagian)} · ${display(d.plan).isEmpty ? '-' : d.plan} · ${categoryKey(d.category)}',
                        style:
                            TextStyle(color: c.textMuted, fontSize: 11.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: c.textMuted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}