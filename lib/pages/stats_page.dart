import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/device.dart';
import '../theme/app_theme.dart';
import '../utils/field_groups.dart';

/// Statistik lanjutan: distribusi per kategori, Bagian, PLAN, status
/// perbaikan, dan kebutuhan upgrade — dari set perangkat yang sedang
/// difilter di dashboard.
class StatsPage extends StatelessWidget {
  final List<Device> devices;
  const StatsPage({super.key, required this.devices});

  static const _kategoriOrder = ['Computer', 'Laptop', 'Printer'];

  Map<String, int> _agregasi(String Function(Device) group) =>
      aggregate(devices, group);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final total = devices.length;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Statistik Lengkap')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _ringkasan(context),
          const SizedBox(height: 16),
          _section(context, 'PER KATEGORI'),
          const SizedBox(height: 8),
          _card(context, child: _kategoriChart(context)),
          const SizedBox(height: 16),
          _section(context, 'PER BAGIAN'),
          const SizedBox(height: 8),
          _card(context, child: _barList(
            context,
            data: _agregasi((d) => d.bagian.trim().isEmpty ? 'Tanpa Bagian' : d.bagian.trim()),
            total: total,
            warna: c.blue,
          )),
          const SizedBox(height: 16),
          _section(context, 'PER PLAN'),
          const SizedBox(height: 8),
          _card(context, child: _barList(
            context,
            data: _agregasi((d) => d.plan.trim().isEmpty ? 'Tanpa PLAN' : d.plan.trim()),
            total: total,
            warna: c.accent,
          )),
          const SizedBox(height: 16),
          _section(context, 'STATUS PERBAIKAN'),
          const SizedBox(height: 8),
          _card(context, child: _barList(
            context,
            data: _agregasi((d) => d.statusUpgrade.trim()),
            total: total,
            warna: kChartColors[3],
          )),
          const SizedBox(height: 16),
          _section(context, 'KEBUTUHAN UPGRADE'),
          const SizedBox(height: 8),
          _card(context, child: _upgradeRingkasan(context, total)),
        ],
      ),
    );
  }

  // ---------- Ringkasan ----------
  Widget _ringkasan(BuildContext context) {
    final c = context.appColors;
    final kategori =
        _agregasi((d) => categoryKey(d.category)).entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${devices.length} perangkat',
            style: TextStyle(
                color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in kategori)
              Chip(
                avatar: Icon(Icons.devices_other,
                    size: 15, color: c.planChipFg),
                label: Text('${k.key} · ${k.value}'),
                labelStyle: TextStyle(
                    color: c.planChipFg,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                backgroundColor: c.planChipBg,
                side: BorderSide.none,
              ),
          ],
        ),
      ],
    );
  }

  // ---------- Bar chart kategori (fl_chart) ----------
  Widget _kategoriChart(BuildContext context) {
    final c = context.appColors;
    final total = devices.length;
    final data = <String, int>{};
    for (final d in devices) {
      final key = categoryKey(d.category);
      data[key] = (data[key] ?? 0) + 1;
    }

    final groups = _kategoriOrder
        .map((k) => (kategori: k, jml: data[k] ?? 0))
        .toList();

    final maxJml = groups.fold<int>(1, (a, g) => g.jml > a ? g.jml : a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 190,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (maxJml + 1).toDouble(),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final g = groups[groupIndex];
                    final pct =
                        total == 0 ? 0.0 : (g.jml / total * 100);
                    return BarTooltipItem(
                      '${g.kategori}\n${g.jml} perangkat (${pct.toStringAsFixed(1)}%)',
                      TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) {
                      final g = groups[value.toInt()];
                      final pct = total == 0
                          ? 0.0
                          : (g.jml / total * 100);
                      final label =
                          g.jml > 0 ? '${pct.round()}%' : '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(label,
                            style: TextStyle(
                                color: c.textMuted, fontSize: 11)),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final g = groups[value.toInt()];
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${g.kategori}\n${g.jml}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: c.textMuted,
                              fontSize: 10,
                              height: 1.2),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (var i = 0; i < groups.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: groups[i].jml.toDouble(),
                        color: kChartColors[i % kChartColors.length],
                        width: 34,
                        borderRadius:
                            BorderRadius.circular(6),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (var i = 0; i < groups.length; i++)
              _miniLegend(
                  context,
                  color: kChartColors[i % kChartColors.length],
                  label: groups[i].kategori),
          ],
        ),
      ],
    );
  }

  Widget _miniLegend(BuildContext context, {required Color color, required String label}) {
    final c = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: c.textMuted, fontSize: 11.5)),
      ],
    );
  }

  // ---------- Daftar bar horizontal ----------
  Widget _barList(BuildContext context,
      {required Map<String, int> data,
      required int total,
      required Color warna}) {
    final c = context.appColors;
    final rows = data.entries.where((e) => e.value > 0).toList();
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Text('Belum ada data',
            style: TextStyle(color: c.textMuted, fontSize: 13)),
      );
    }
    final maxJml = rows.fold<int>(1, (a, e) => e.value > a ? e.value : a);

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  rows[i].key == belumDiInput ? '(Belum di input)' : rows[i].key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text('${rows[i].value}',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              SizedBox(
                width: 42,
                child: Text(
                  total == 0
                      ? ''
                      : '${(rows[i].value / total * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: c.textMuted, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: rows[i].value / maxJml,
              minHeight: 8,
              backgroundColor: c.surfaceAlt,
              color: warna,
            ),
          ),
        ],
      ],
    );
  }

  // ---------- Ringkasan upgrade ----------
  Widget _upgradeRingkasan(BuildContext context, int total) {
    final c = context.appColors;
    int ya(String Function(Device) f) =>
        devices.where((d) => f(d).trim().toLowerCase().startsWith('y')).length;

    final gantiYa = ya((d) => d.perluUpgradeGanti);
    final repairYa = ya((d) => d.perluUpgradeRepair);
    final perlu = devices.where((d) => needsUpgrade(d)).length;

    Widget mini(IconData icon, Color warna, String label, int jml) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: warna, size: 22),
              const SizedBox(height: 8),
              Text('$jml',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(color: c.textMuted, fontSize: 11)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            mini(Icons.swap_horiz, c.danger, 'Perlu Ganti', gantiYa),
            const SizedBox(width: 10),
            mini(Icons.build, kChartColors[4], 'Perlu Repair', repairYa),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            mini(Icons.warning_amber, kChartColors[2],
                'Total perlu tindakan', perlu),
            const SizedBox(width: 10),
            mini(Icons.check_circle, c.accent, 'Sudah tercapai',
                devices.where((d) => isTercapai(d)).length),
          ],
        ),
      ],
    );
  }

  // ---------- Elemen halaman ----------
  Widget _section(BuildContext context, String title) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title,
          style: TextStyle(
              color: c.textMuted,
              fontSize: 12,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}