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
      await tester.tap(_stepperDi(tester, '256 GB', Icons.add));
      await tester.pump();
    }
    for (var i = 0; i < 3; i++) {
      await tester.tap(_stepperDi(tester, '128 GB', Icons.add));
      await tester.pump();
    }

    expect(
      find.text('Storage yang dicetak: 128 GB 3x + 256 GB 2x'),
      findsOneWidget,
      reason: 'urutan mengikuti daftar ukuran, tiap ukuran punya jumlah unit',
    );

    // Kurangi 128 GB kembali ke 0 -> hilang dari ringkasan.
    for (var i = 0; i < 3; i++) {
      await tester.tap(_stepperDi(tester, '128 GB', Icons.remove));
      await tester.pump();
    }
    expect(
      find.text('Storage yang dicetak: 256 GB 2x'),
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