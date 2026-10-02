import 'package:flutter/material.dart';

import '../models/device.dart';
import '../theme/app_theme.dart';
import '../utils/field_groups.dart';
import '../widgets/clickable.dart';
import 'detail_page.dart';

/// Rincian Status Stiker: menampilkan daftar device yang stikernya
/// Sudah dicetak/ditempel dan yang masih Belum.
class StickerDetailPage extends StatelessWidget {
  final List<Device> devices;
  const StickerDetailPage({super.key, required this.devices});

  static const _sudahColor = Color(0xFF16A34A);
  static const _belumColor = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final sudah = devices
        .where((d) => d.statusStiker.trim().toLowerCase() == 'sudah')
        .toList();
    final belum = devices
        .where((d) => d.statusStiker.trim().toLowerCase() != 'sudah')
        .toList();

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Status Stiker'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: _summaryBox(context,
                      color: _sudahColor,
                      label: 'Sudah',
                      count: sudah.length),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryBox(context,
                      color: _belumColor,
                      label: 'Belum',
                      count: belum.length),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(context, 'SUDAH DITEMPEK / DIKERJAKAN',
              sudah, _sudahColor, Icons.check_circle_outline),
          const SizedBox(height: 20),
          _section(context, 'BELUM DITEMPEK', belum, _belumColor,
              Icons.pending_outlined),
        ],
      ),
    );
  }

  Widget _summaryBox(BuildContext context,
      {required Color color, required String label, required int count}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 8),
          Text('$label: $count',
              style: TextStyle(
                  color: context.appColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Device> list,
      Color color, IconData icon) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    color: c.textMuted,
                    fontSize: 12,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        if (list.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Text('Tidak ada device',
                style: TextStyle(color: c.textMuted, fontSize: 12)),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++)
                  _row(context, list[i], color, isLast: i == list.length - 1),
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, Device d, Color color, {required bool isLast}) {
    final c = context.appColors;
    return Clickable(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetailPage(device: d)),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: isLast ? null : Border(bottom: BorderSide(color: c.border)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.computer, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${d.kodeInventaris} · ${display(d.deviceName)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600)),
                    if (d.bagian.trim().isNotEmpty)
                      Text(display(d.bagian),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.textMuted, fontSize: 11.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: c.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
