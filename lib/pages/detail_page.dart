import 'package:flutter/material.dart';

import '../database/db_helper.dart';
import '../models/device.dart';
import '../theme/app_theme.dart';
import '../utils/field_groups.dart';
import '../widgets/print_options_sheet.dart';
import '../widgets/status_badge.dart';
import 'device_form_page.dart';

class DetailPage extends StatefulWidget {
  final Device device;
  const DetailPage({super.key, required this.device});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late Device _device;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
  }

  Future<void> _delete() async {
    final c = context.appColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Data', style: TextStyle(fontSize: 17)),
        content: Text(
          'Hapus ${_device.kodeInventaris} — ${_device.deviceName}?\nData akan dihapus permanen.',
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
    await DbHelper.instance.delete(_device.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Data dihapus')));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _hero(context),
                  const SizedBox(height: 14),
                  _barcodeButton(context),
                  const SizedBox(height: 12),
                  _detailCard(context),
                  const SizedBox(height: 14),
                  _actions(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: c.textPrimary,
          ),
          Text('Detail Perangkat',
              style: TextStyle(
                  color: c.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final c = context.appColors;
    final sticker = _device.statusStiker.trim();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.heroGrad1, c.heroGrad2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _device.kodeInventaris,
            style: TextStyle(
                color: c.heroKode,
                fontSize: 12,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            _device.deviceName.isNotEmpty ? _device.deviceName : 'Tanpa nama',
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _heroChip(context, _device.plan.isNotEmpty ? _device.plan : '-'),
              if (sticker.isNotEmpty) _heroChip(context, sticker),
              if (_device.category.isNotEmpty) _heroChip(context, _device.category),
            ],
          ),
          const SizedBox(height: 12),
          StatusBadge(device: _device),
        ],
      ),
    );
  }

  Widget _heroChip(BuildContext context, String t) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.heroChipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(t,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }

  List<(String, String)> _fields() => [
        ('Tanggal Evaluasi', _device.tanggalEvaluasi),
        ('PLAN', _device.plan),
        ('Bagian', _device.bagian),
        ('Device Name', _device.deviceName),
        ('Category', _device.category),
        (labelFor('prosesor', _device.category), _device.prosesor),
        (labelFor('motherboard', _device.category), _device.motherboard),
        if (showSpecField('ram', _device.category))
          (labelFor('ram', _device.category), _device.ram),
        if (showSpecField('storage', _device.category))
          (labelFor('storage', _device.category), _device.storage),
        if (showSpecField('osWindows', _device.category))
          (labelFor('osWindows', _device.category), _device.osWindows),
        if (showSpecField('goal', _device.category))
          (labelFor('goal', _device.category), _device.goal),
        (labelFor('perluUpgradeGanti', _device.category), _device.perluUpgradeGanti),
        (labelFor('perluUpgradeRepair', _device.category), _device.perluUpgradeRepair),
        (labelFor('statusUpgrade', _device.category), _device.statusUpgrade),
        ('Keterangan', _device.keterangan),
        ('Status Stiker', _device.statusStiker),
        ('Link Spesifikasi (Google Drive)', _device.driveLink),
      ];

  Widget _detailCard(BuildContext context) {
    final c = context.appColors;
    final fields = _fields();

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Text('DETAIL SPESIFIKASI',
                style: TextStyle(
                    color: c.textMuted,
                    fontSize: 13,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600)),
          ),
          ...fields.indexed
              .map((e) => _infoRow(context, e.$1, e.$2.$1, e.$2.$2)),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, int index, String k, String v) {
    final c = context.appColors;
    final empty = v.trim().isEmpty;
    final isLast = index == _fields().length - 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(k,
                style: TextStyle(color: c.textMuted, fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: k.startsWith('Link')
                ? SelectableText(
                    empty ? belumDiInput : v.trim(),
                    style: TextStyle(
                      color: empty ? c.textMuted : c.blueFg,
                      fontSize: 14,
                      height: 1.35,
                      decoration: empty
                          ? TextDecoration.none
                          : TextDecoration.underline,
                    ),
                  )
                : Text(
                    empty ? belumDiInput : v,
                    style: empty
                        ? TextStyle(
                            color: c.textMuted,
                            fontStyle: FontStyle.italic,
                            fontSize: 14)
                        : TextStyle(
                            color: c.textPrimary, fontSize: 14, height: 1.35),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _barcodeButton(BuildContext context) {
    final c = context.appColors;
    return OutlinedButton.icon(
      onPressed: () => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: c.surface,
        builder: (_) => PrintOptionsSheet(device: _device),
      ),
      icon: Icon(Icons.print_outlined, color: c.blueFg),
      label: const Text('Cetak / Download'),
      style: OutlinedButton.styleFrom(
        backgroundColor: c.surface,
        foregroundColor: c.blueFg,
        side: BorderSide(color: c.blue),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final c = context.appColors;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final edited = await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => DeviceFormPage(device: _device)),
              );
              if (edited == true) {
                final list = await DbHelper.instance.getAll();
                if (!mounted) return;
                setState(() {
                  _device = list.firstWhere((d) => d.id == _device.id);
                });
              }
            },
            icon: Icon(Icons.edit, color: c.blueFg),
            label: Text('Edit', style: TextStyle(color: c.blueFg)),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.blue,
              foregroundColor: c.blueFg,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _delete,
            icon: Icon(Icons.delete, color: c.dangerFg),
            label: Text('Hapus', style: TextStyle(color: c.dangerFg)),
            style: OutlinedButton.styleFrom(
              backgroundColor: c.dangerBg,
              side: BorderSide(color: c.dangerBorder),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}