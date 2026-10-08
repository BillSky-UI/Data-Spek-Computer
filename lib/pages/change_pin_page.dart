import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database/db_helper.dart';
import '../services/pin_controller.dart';
import '../theme/app_theme.dart';

/// Halaman untuk mengubah PIN — wajib memasukkan PIN lama terlebih dahulu.
class ChangePinPage extends StatefulWidget {
  const ChangePinPage({super.key});

  @override
  State<ChangePinPage> createState() => _ChangePinPageState();
}

class _ChangePinPageState extends State<ChangePinPage> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  List<TextInputFormatter> get _formatters => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(PinController.maxLength),
      ];

  Future<void> _save() async {
    final oldP = _oldCtrl.text.trim();
    final newP = _newCtrl.text.trim();
    final conf = _confirmCtrl.text.trim();

    if (!PinController.instance.isValidFormat(oldP) ||
        !PinController.instance.isValidFormat(newP) ||
        !PinController.instance.isValidFormat(conf)) {
      _error = 'PIN harus berupa angka ${PinController.minLength}–'
          '${PinController.maxLength} digit';
      setState(() {});
      return;
    }
    if (newP != conf) {
      _error = 'PIN baru dan konfirmasi tidak sama';
      setState(() {});
      return;
    }

    setState(() {
      _busy = true;
      _error = '';
    });
    // Ubah PIN ke cloud → semua perangkat lain ikut berubah (real-time).
    final ok = await DbHelper.instance.changePin(oldP, newP);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('PIN berhasil diubah')));
      Navigator.pop(context, true);
    } else {
      _error = 'PIN lama salah';
      setState(() {});
    }
  }

  Widget _pinField(BuildContext context, TextEditingController ctr,
      String label, String hint) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctr,
        obscureText: true,
        keyboardType: TextInputType.number,
        inputFormatters: _formatters,
        style: TextStyle(color: c.textPrimary, fontSize: 18, letterSpacing: 5),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: c.inputHint),
          filled: true,
          fillColor: c.surface,
          labelStyle: TextStyle(color: c.textMuted),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Ubah PIN')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: c.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'PIN digunakan untuk membuka aplikasi. '
                    'Default: 0000. Harus berupa angka '
                    '${PinController.minLength}–${PinController.maxLength} digit.',
                    style: TextStyle(color: c.textMuted, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _pinField(context, _oldCtrl, 'PIN Lama', '••••'),
          _pinField(context, _newCtrl, 'PIN Baru', '••••'),
          _pinField(context, _confirmCtrl, 'Konfirmasi PIN Baru', '••••'),
          if (_error.isNotEmpty) ...[
            Text(_error, style: TextStyle(color: c.danger, fontSize: 13)),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: c.onAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: c.onAccent))
                : const Text('Simpan PIN Baru',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}