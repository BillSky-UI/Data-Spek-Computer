import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Pembaca posisional sederhana untuk content stream PDF.
///
/// Cukup untuk memverifikasi hasil `package:pdf`: membaca matriks CTM
/// (operator `cm` dengan tumpukan `q`/`Q`) lalu menggabungkannya dengan
/// matriks teks (`Tm`/`Td`) supaya posisi baseline tiap potongan teks
/// bisa dibaca dalam milimeter dari tepi bawah kertas.
class PdfMatrix {
  const PdfMatrix(this.a, this.b, this.c, this.d, this.e, this.f);

  static const identity = PdfMatrix(1, 0, 0, 1, 0, 0);

  final double a, b, c, d, e, f;

  /// [this] x [m]
  PdfMatrix mul(PdfMatrix m) => PdfMatrix(
    a * m.a + b * m.c,
    a * m.b + b * m.d,
    c * m.a + d * m.c,
    c * m.b + d * m.d,
    e * m.a + f * m.c + m.e,
    e * m.b + f * m.d + m.f,
  );

  /// Mengubah titik (x, y) lewat matriks ini.
  (double, double) apply(double x, double y) =>
      (a * x + c * y + e, b * x + d * y + f);
}

class PdfTextItem {
  const PdfTextItem(this.text, this.xMm, this.yMm, this.fontSizePt);

  final String text;

  /// Posisi awal baseline, mm dari tepi kiri.
  final double xMm;

  /// Baseline, mm dari tepi bawah kertas.
  final double yMm;

  final double fontSizePt;

  @override
  String toString() =>
      'x=${xMm.toStringAsFixed(2).padLeft(7)} '
      'y=${yMm.toStringAsFixed(2).padLeft(7)} '
      'fs=${fontSizePt.toStringAsFixed(1).padLeft(5)} "$text"';
}

/// Pembungkus literal string PDF agar tidak tertukar dengan operator
/// (keduanya bertipe `String`).
class PdfString {
  const PdfString(this.value);
  final String value;
}

class PdfProbe {
  PdfProbe._(this._raw, this._streams, this._hexToChar);

  final String _raw;
  final List<String> _streams;

  /// Peta cid -> unicode hasil parsing CMap ToUnicode (untuk font TTF/CID).
  ///
  /// `package:pdf` menulis teks font TTF sebagai string hex `<xxxx>` yang
  /// isinya *indeks karakter dalam subset*, bukan nilai unicode, sehingga
  /// untuk membacanya kembali perlu disilangkan dengan CMap ToUnicode yang
  /// disisipkan ke PDF (`<indeks> <unicode>` baris per baris).
  final Map<int, int> _hexToChar;

  static const double mmPerPt = 25.4 / 72;

  /// Median halaman dalam mm, atau null bila tidak ada `/MediaBox`.
  ({double width, double height})? get mediaBox {
    final m = RegExp(
      r'/MediaBox\s*\[\s*([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s*\]',
    ).firstMatch(_raw);
    if (m == null) return null;
    final x0 = double.parse(m.group(1)!);
    final y0 = double.parse(m.group(2)!);
    final x1 = double.parse(m.group(3)!);
    final y1 = double.parse(m.group(4)!);
    return (width: (x1 - x0) * mmPerPt, height: (y1 - y0) * mmPerPt);
  }

  /// Banyaknya gambar yang benar-benar tertanam.
  ///
  /// Penting: jangan pakai `raw.contains('/Image')` — string itu juga muncul
  /// di `/ProcSet[/PDF/Text/ImageB/ImageC]`, sehingga hasilnya true palsu
  /// walau PDF tidak memuat satu pun gambar.
  bool get hasImage => jumlahGambar > 0;

  /// Jumlah objek gambar (/Subtype /Image) yang tertulis di PDF.
  ///
  /// Catatan: dart_pdf menulis tiap gambar lebih dari sekali, jadi angka ini
  /// bukan jumlah logo yang tampil. Pakai [dimensiGambar] untuk menghitung
  /// gambar yang benar-benar berbeda.
  int get jumlahGambar => RegExp(r'/Subtype\s*/Image').allMatches(_raw).length;

  /// Dimensi unik tiap gambar tertanam, sebagai himpunan (lebar, tinggi) px.
  Set<({int w, int h})> get dimensiGambar {
    final out = <({int w, int h})>{};
    final re = RegExp(
      r'/Subtype\s*/Image[^>]*?/Width\s+(\d+)[^>]*?/Height\s+(\d+)',
    );
    for (final m in re.allMatches(_raw)) {
      out.add((w: int.parse(m.group(1)!), h: int.parse(m.group(2)!)));
    }
    return out;
  }

  /// Kotak tiap gambar yang digambar di content stream, dalam mm:
  /// (x, y, lebar, tinggi) dengan `y` diukur dari tepi bawah halaman.
  ///
  /// Mengambil angka tepat setelah perintah `cm`, karena `pw.Image` menulis
  /// matriks posisi di situ.
  List<({double x, double y, double w, double h})> get kotakGambar {
    final mmPerPt = 72 / 25.4;
    final out = <({double x, double y, double w, double h})>[];
    final re = RegExp(
      r'([-\d.]+)\s+0\s+0\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+cm',
    );
    for (final m in re.allMatches(_raw)) {
      final w = double.parse(m.group(1)!) * mmPerPt;
      final h = double.parse(m.group(2)!) * mmPerPt;
      final x = double.parse(m.group(3)!) * mmPerPt;
      final y = double.parse(m.group(4)!) * mmPerPt;
      if (w > 0.5 && h > 0.5) out.add((x: x, y: y, w: w, h: h));
    }
    return out;
  }

  /// Seluruh teks yang digabung tanpa spasi, untuk pengecekan isi.
  String get teksGabung =>
      items.map((e) => e.text).join().replaceAll(RegExp(r'\s+'), '');

  List<PdfTextItem> get items => _items ??= _baca(_streams, _hexToChar);
  List<PdfTextItem>? _items;

  /// Baseline unik (mm, pembulatan 0,1) yang dipakai di halaman ini.
  Set<double> get baselines =>
      items.map((e) => (e.yMm * 10).round() / 10).toSet();

  /// Isi mentah PDF (untuk pengecekan struktur).
  String get raw => _raw;

  static PdfProbe fromBytes(Uint8List bytes) {
    final raw = latin1.decode(bytes);
    final streams = _inflate(bytes, raw);
    return PdfProbe._(
      raw,
      streams.where((s) => s.contains('BT')).toList(),
      _parseToUnicode(streams, raw),
    );
  }

  /// Membaca CMap ToUnicode pertama yang ditemukan: tiap baris berbentuk
  /// `<0001> <0043>` — kiri = indeks karakter subset, kanan = unicode.
  static Map<int, int> _parseToUnicode(List<String> streams, String raw) {
    final map = <int, int>{};
    for (final s in streams.isEmpty ? [raw] : <String>[...streams, raw]) {
      final re = RegExp(r'beginbfchar\s*(.*?)\s*endbfchar', dotAll: true);
      for (final m in re.allMatches(s)) {
        final hex = RegExp(r'<([0-9A-Fa-f\s]+)>\s*<([0-9A-Fa-f\s]+)>');
        for (final p in hex.allMatches(m.group(1)!)) {
          final src = p.group(1)!.replaceAll(RegExp(r'\s'), '').toLowerCase();
          final dst = p.group(2)!.replaceAll(RegExp(r'\s'), '').toLowerCase();
          if (src.length != 4 || (dst.length != 4 && dst.length != 8)) {
            continue;
          }
          final key = int.parse(src, radix: 16);
          final u = int.parse(dst.substring(0, 4), radix: 16);
          if (dst.length == 4) {
            map[key] = u;
          } else {
            final lo = int.parse(dst.substring(4, 8), radix: 16);
            map[key] = 0x10000 + ((u - 0xD800) << 10) + (lo - 0xDC00);
          }
        }
        return map;
      }
    }
    return map;
  }

  // ------------------------------------------------------------- tokenizer
  static List<PdfTextItem> _baca(List<String> streams, Map<int, int> hexToChar) {
    final hasil = <PdfTextItem>[];
    for (final s in streams) {
      _bacaStream(s, hexToChar, hasil);
    }
    return hasil;
  }

  static void _bacaStream(
    String s,
    Map<int, int> hexToChar,
    List<PdfTextItem> hasil,
  ) {
    final stack = <PdfMatrix>[];
    var ctm = PdfMatrix.identity;
    var tm = PdfMatrix.identity;
    var fontSize = 0.0;
    final operand = <Object?>[];

    for (final t in _tokenize(s, hexToChar)) {
      if (t is PdfString) {
        operand.add(t.value);
        continue;
      }
      if (t is! String) {
        operand.add(t);
        continue;
      }
      switch (t) {
        case 'q':
          stack.add(ctm);
          break;
        case 'Q':
          ctm = stack.isEmpty ? PdfMatrix.identity : stack.removeLast();
          break;
        case 'cm':
          if (operand.length >= 6) {
            final m = PdfMatrix(
              _num(operand[operand.length - 6]),
              _num(operand[operand.length - 5]),
              _num(operand[operand.length - 4]),
              _num(operand[operand.length - 3]),
              _num(operand[operand.length - 2]),
              _num(operand[operand.length - 1]),
            );
            ctm = m.mul(ctm);
          }
          break;
        case 'BT':
          tm = PdfMatrix.identity;
          break;
        case 'Tf':
          if (operand.isNotEmpty) fontSize = _num(operand.last);
          break;
        case 'Td':
        case 'TD':
          if (operand.length >= 2) {
            final tx = _num(operand[operand.length - 2]);
            final ty = _num(operand[operand.length - 1]);
            tm = PdfMatrix(1, 0, 0, 1, tx, ty).mul(tm);
          }
          break;
        case 'Tm':
          if (operand.length >= 6) {
            tm = PdfMatrix(
              _num(operand[operand.length - 6]),
              _num(operand[operand.length - 5]),
              _num(operand[operand.length - 4]),
              _num(operand[operand.length - 3]),
              _num(operand[operand.length - 2]),
              _num(operand[operand.length - 1]),
            );
          }
          break;
        case 'Tj':
        case 'TJ':
        case "'":
        case '"':
          for (final o in operand) {
            if (o is String && o.isNotEmpty) {
              final p = tm.mul(ctm).apply(0, 0);
              hasil.add(
                PdfTextItem(
                  o,
                  p.$1 * PdfProbe.mmPerPt,
                  p.$2 * PdfProbe.mmPerPt,
                  fontSize,
                ),
              );
            }
          }
      }
      operand.clear();
    }
  }

  static double _num(Object? o) => o is double ? o : 0;

  /// Mengubah content stream menjadi daftar operand (angka/string) dan
  /// operator (String tanpa spasi).
  ///
  /// String literal `(...)` dibaca apa adanya. String hex `<...>` (dipakai
  /// `package:pdf` untuk font TTF) didekode menjadi teks lewat [hexToChar].
  static List<Object> _tokenize(String s, Map<int, int> hexToChar) {
    final out = <Object>[];
    final buf = StringBuffer();
    var i = 0;

    void flush() {
      if (buf.isEmpty) return;
      final t = buf.toString();
      buf.clear();
      out.add(double.tryParse(t) ?? t);
    }

    while (i < s.length) {
      final c = s[i];
      // komentar
      if (c == '%') {
        while (i < s.length && s[i] != '\n') {
          i++;
        }
        continue;
      }
      if (c == '<') {
        flush();
        final sb = StringBuffer();
        i++;
        while (i < s.length && s[i] != '>') {
          sb.write(s[i]);
          i++;
        }
        if (i < s.length) i++; // lewati '>'
        out.add(PdfString(_decodeHex(sb.toString(), hexToChar)));
        continue;
      }
      if (c == '>') {
        i++;
        continue;
      }
      if (c == '(') {
        flush();
        final sb = StringBuffer();
        var depth = 1;
        i++;
        while (i < s.length && depth > 0) {
          final ch = s[i];
          if (ch == r'\' && i + 1 < s.length) {
            i++;
            final n = s[i];
            sb.write(switch (n) {
              'n' => '\n',
              'r' => '\r',
              't' => '\t',
              _ => n,
            });
          } else if (ch == '(') {
            depth++;
            sb.write(ch);
          } else if (ch == ')') {
            depth--;
            if (depth > 0) sb.write(ch);
          } else {
            sb.write(ch);
          }
          i++;
        }
        out.add(PdfString(sb.toString()));
        continue;
      }
      if (c == '[' || c == ']') {
        flush();
        i++;
        continue;
      }
      if (c == '/') {
        flush();
        i++;
        while (i < s.length && !_isDelimiter(s[i])) {
          i++;
        }
        out.add('__name__');
        continue;
      }
      if (_isWhitespace(c)) {
        flush();
        i++;
        continue;
      }
      buf.write(c);
      i++;
    }
    flush();
    return out;
  }

  static bool _isWhitespace(String c) =>
      c == ' ' || c == '\n' || c == '\r' || c == '\t' || c == '\f';

  /// Menerjemahkan string hex `<xxxx>...` (indeks karakter subset) menjadi
  /// teks unicode memakai peta bawaan CMap ToUnicode.
  static String _decodeHex(String hex, Map<int, int> hexToChar) {
    final h = hex.replaceAll(RegExp(r'\s'), '');
    final buf = StringBuffer();
    for (var i = 0; i + 3 < h.length; i += 4) {
      final v = int.tryParse(h.substring(i, i + 4), radix: 16);
      if (v == null) continue;
      final ch = hexToChar[v];
      if (ch != null && ch > 0) buf.writeCharCode(ch);
    }
    return buf.toString();
  }

  static bool _isDelimiter(String c) =>
      _isWhitespace(c) ||
      c == '(' ||
      c == ')' ||
      c == '<' ||
      c == '>' ||
      c == '[' ||
      c == ']' ||
      c == '{' ||
      c == '}' ||
      c == '/' ||
      c == '%';

  static List<String> _inflate(Uint8List bytes, String raw) {
    final out = <String>[];
    for (final m in RegExp(r'stream\r?\n').allMatches(raw)) {
      var start = m.end;
      while (start < bytes.length &&
          (bytes[start] == 13 || bytes[start] == 10)) {
        start++;
      }
      var end = raw.indexOf('endstream', start);
      if (end < 0) continue;
      while (end > start && (bytes[end - 1] == 13 || bytes[end - 1] == 10)) {
        end--;
      }
      // Lewati paling awal yang tidak mungkin benar: stream image mentah
      // (DCTDecode dsb.) akan gagal ZLib dan di-skip di bawah.
      if (end <= start) {
        continue;
      }
      try {
        final data = ZLibCodec().decode(bytes.sublist(start, end));
        final s = latin1.decode(data, allowInvalid: true);
        // Jangan saring di sini: [_parseToUnicode] butuh stream CMap ToUnicode
        // yang tidak berisi 'BT'. Nanti `fromBytes` yang memisahkan stream
        // teks (berisi 'BT') untuk dicari item-nya.
        out.add(s);
      } catch (_) {
        continue;
      }
    }
    return out;
  }
}
