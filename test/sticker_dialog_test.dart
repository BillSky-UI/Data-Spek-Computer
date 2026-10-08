import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spek_komputer/models/device.dart';
import 'package:spek_komputer/theme/app_theme.dart';
import 'package:spek_komputer/widgets/sticker_download_dialog.dart';

Widget _app(Device d) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(child: StickerDownloadDialog(device: d)),
      ),
    );

Finder _stepperDi(WidgetTester tester, String label, IconData ikon) {
  final row = find
      .ancestor(of: find.text(label), matching: find.byType(Row))
      .first;
  return find.descendant(of: row, matching: find.byIcon(ikon));
}

/// Ketuk tombol sambil memastikan barisnya terlihat (daftar storage bisa
/// lebih tinggi dari layar uji sehingga perlu di-scroll dulu).
Future<void> _ketuk(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

void main() {
  testWidgets('storage dihitung per ukuran dan digabung saat dipilih',
      (tester) async {
    final d = Device(
      kodeInventaris: 'PC-1',
      deviceName: 'PC 1',
      category: 'Komputer',
      storage: '256 GB SSD Sata',
    );
    await tester.pumpWidget(_app(d));

    // Tanpa pilihan: mengikuti data input.
    expect(find.textContaining('Akan mengikuti data input'), findsOneWidget);

    // 256 GB -> 2 unit, 128 GB -> 3 unit.
    for (var i = 0; i < 2; i++) {
      await _ketuk(tester, _stepperDi(tester, '256 GB', Icons.add));
    }
    for (var i = 0; i < 3; i++) {
      await _ketuk(tester, _stepperDi(tester, '128 GB', Icons.add));
    }

    expect(
      find.text('Storage yang dicetak: 128GB SSD 3x + 256GB SSD 2x (5 unit)'),
      findsOneWidget,
      reason: 'kapasitas + tipe dulu lalu jumlah unit, urutan mengikuti daftar',
    );

    // Kurangi 128 GB kembali ke 0 -> hilang dari ringkasan.
    for (var i = 0; i < 3; i++) {
      await _ketuk(tester, _stepperDi(tester, '128 GB', Icons.remove));
    }
    expect(
      find.text('Storage yang dicetak: 256GB SSD 2x (2 unit)'),
      findsOneWidget,
    );
  });

  testWidgets('tipe storage bisa diganti SSD/HDD per ukuran',
      (tester) async {
    final d = Device(
      kodeInventaris: 'PC-1',
      deviceName: 'PC 1',
      category: 'Komputer',
      storage: '512 GB HDD',
    );
    await tester.pumpWidget(_app(d));

    // Bawaan mengikuti data input: HDD.
    for (var i = 0; i < 2; i++) {
      await _ketuk(tester, _stepperDi(tester, '512 GB', Icons.add));
    }
    expect(
      find.text('Storage yang dicetak: 512GB HDD 2x (2 unit)'),
      findsOneWidget,
    );

    // Ganti ke SSD -> jumlah pindah ke tipe baru.
    final row512 = find
        .ancestor(of: find.text('512 GB'), matching: find.byType(Row))
        .first;
    await _ketuk(tester, find.descendant(of: row512, matching: find.text('SSD')));
    await tester.pump();
    expect(
      find.text('Storage yang dicetak: 512GB SSD 2x (2 unit)'),
      findsOneWidget,
    );
  });

  testWidgets('stiker printer tidak menampilkan pilihan storage',
      (tester) async {
    final d = Device(
      kodeInventaris: 'PR-1',
      deviceName: 'Printer 1',
      category: 'Printer',
    );
    await tester.pumpWidget(_app(d));
    expect(find.textContaining('Storage yang dicetak'), findsNothing);
    expect(find.text('1TB'), findsNothing);
  });
}