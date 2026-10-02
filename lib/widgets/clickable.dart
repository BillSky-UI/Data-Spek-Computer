import 'package:flutter/material.dart';

/// Memberi kursor "pointer/tangan" pada area yang bisa diklik.
///
/// Di web & desktop kursor bawaan Flutter adalah panah biasa, sehingga tombol,
/// kartu, dan baris daftar yang bisa diklik tidak terlihat interaktif. Widget
/// ini membungkus [child] dengan [MouseRegion] kursor klik. Tombol Material
/// sudah mendapat kursor lewat [ButtonStyle] di tema, jadi [Clickable] dipakai
/// untuk widget non-tombol seperti [InkWell], [ListTile], [ChoiceChip], dan
/// dropdown.
///
/// Di Android/iOS kursor layar sentuh diabaikan, jadi widgets ini aman
/// dipasang di kedua platform.
class Clickable extends StatelessWidget {
  const Clickable({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: child,
      );
}
