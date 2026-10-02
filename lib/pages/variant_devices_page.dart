import 'package:flutter/material.dart';

import '../models/device.dart';
import '../theme/app_theme.dart';
import '../utils/field_groups.dart';
import '../widgets/clickable.dart';
import 'detail_page.dart';

/// Daftar device yang termasuk ke dalam satu varian spesifikasi.
/// Dibuka saat pengguna mengetuk varian pada halaman Rincian (Lihat Rincian).
class VariantDevicesPage extends StatelessWidget {
  final String title;
  final String variant;
  final IconData icon;
  final List<Device> devices;

  const VariantDevicesPage({
    super.key,
    required this.title,
    required this.variant,
    required this.icon,
    required this.devices,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final list = [...devices]
      ..sort((a, b) => a.kodeInventaris.compareTo(b.kodeInventaris));

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Device per Varian')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.heroGrad1, c.heroGrad2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(variant,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${list.length} perangkat',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Text('Tidak ada device pada varian ini',
                  style: TextStyle(color: c.textMuted, fontSize: 13)),
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
                    _row(context, list[i], isLast: i == list.length - 1),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Device d, {required bool isLast}) {
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
                  color: c.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: c.accent),
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
                          style:
                              TextStyle(color: c.textMuted, fontSize: 11.5)),
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
