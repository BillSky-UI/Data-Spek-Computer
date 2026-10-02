import 'package:flutter/material.dart';

import '../models/device.dart';
import '../theme/app_theme.dart';
import '../widgets/clickable.dart';
import 'variant_devices_page.dart';

/// Rincian statistik per varian spesifikasi.
/// Setiap varian bisa diketuk untuk melihat daftar device-nya.
class SpecBreakdownPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final Map<String, int> data;
  final List<Device> devices;
  final String Function(Device) grouper;

  const SpecBreakdownPage({
    super.key,
    required this.title,
    required this.icon,
    required this.data,
    required this.devices,
    required this.grouper,
  });

  void _openVariant(BuildContext context, String variant) {
    final matching =
        devices.where((d) => grouper(d) == variant).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VariantDevicesPage(
          title: title,
          variant: variant,
          icon: icon,
          devices: matching,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final entries = data.entries.toList();
    final total = entries.fold<int>(0, (a, e) => a + e.value);
    final maxVal = entries.isEmpty ? 1 : entries.first.value;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text('Rincian $title')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(context, total, entries.length),
          const SizedBox(height: 16),
          Text('RINCIAN PER VARIAN',
              style: TextStyle(
                  color: c.textMuted,
                  fontSize: 12,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border),
              ),
              child: Text('Tidak ada varian terisi',
                  style: TextStyle(color: c.textMuted)),
            )
          else
            for (var i = 0; i < entries.length; i++)
              _variantRow(context, entries[i], maxVal, total, i),
        ],
      ),
    );
  }

  Widget _headerCard(BuildContext context, int total, int variantCount) {
    final c = context.appColors;
    return Container(
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
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('$total perangkat · $variantCount varian',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _variantRow(BuildContext context, MapEntry<String, int> entry,
      int maxVal, int total, int index) {
    final c = context.appColors;
    final percent = total == 0 ? 0.0 : (entry.value / total * 100);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Clickable(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openVariant(context, entry.key),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(entry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(color: c.textPrimary, fontSize: 13)),
                    ),
                    Text('${entry.value} (${percent.round()}%)',
                        style: TextStyle(
                            color:
                                kChartColors[index % kChartColors.length],
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: maxVal == 0 ? 0 : entry.value / maxVal,
                    minHeight: 10,
                    color: kChartColors[index % kChartColors.length],
                    backgroundColor: c.surfaceAlt,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.list_alt, size: 13, color: c.blue),
                    const SizedBox(width: 4),
                    Text('Lihat device ($title → ${entry.key})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.blue, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
