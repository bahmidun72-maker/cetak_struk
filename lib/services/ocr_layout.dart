/// Potongan teks hasil OCR beserta posisinya di gambar.
class OcrPiece {
  final String text;
  final double left, top, right, bottom;

  const OcrPiece(this.text, this.left, this.top, this.right, this.bottom);

  double get height => bottom - top;
  double get centerY => (top + bottom) / 2;
}

/// Menyusun potongan teks menjadi baris-baris visual (kiri ke kanan, atas ke bawah).
///
/// Struk bank/e-wallet biasanya dua kolom ("Nominal" di kiri, "Rp 50.000" di
/// kanan) dan OCR mengembalikannya sebagai blok terpisah. Dengan menggabungkan
/// potongan yang sejajar secara vertikal, label dan nilainya kembali satu baris,
/// dipisah dua spasi.
List<String> groupIntoRows(List<OcrPiece> pieces) {
  final items = pieces.where((p) => p.text.trim().isNotEmpty).toList()
    ..sort((a, b) => a.centerY.compareTo(b.centerY));

  final rows = <List<OcrPiece>>[];
  for (final p in items) {
    List<OcrPiece>? target;
    for (final row in rows.reversed.take(3)) {
      final top = row.map((e) => e.top).reduce((a, b) => a < b ? a : b);
      final bottom = row.map((e) => e.bottom).reduce((a, b) => a > b ? a : b);
      final rowH = bottom - top;
      final overlap = (p.bottom < bottom ? p.bottom : bottom) - (p.top > top ? p.top : top);
      final minH = p.height < rowH ? p.height : rowH;
      final sameLine = overlap > minH * 0.5;
      final noHorizontalClash = row.every((e) => p.right <= e.left + 4 || p.left >= e.right - 4);
      if (sameLine && noHorizontalClash) {
        target = row;
        break;
      }
    }
    if (target != null) {
      target.add(p);
    } else {
      rows.add([p]);
    }
  }

  rows.sort((a, b) {
    final ay = a.map((e) => e.top).reduce((x, y) => x < y ? x : y);
    final by = b.map((e) => e.top).reduce((x, y) => x < y ? x : y);
    return ay.compareTo(by);
  });

  return rows.map((row) {
    row.sort((a, b) => a.left.compareTo(b.left));
    return row.map((e) => e.text.trim()).join('  ');
  }).toList();
}
