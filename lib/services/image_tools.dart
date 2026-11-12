import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Menyiapkan logo agar cocok untuk printer thermal: latar putih (tanpa
/// transparansi), lebar maks 576 px, hitam-putih. Disimpan di folder aplikasi.
Future<String?> prepareLogo(String sourcePath) async {
  final bytes = await File(sourcePath).readAsBytes();
  final png = await compute(_processLogo, bytes);
  if (png == null) return null;
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/logo_${DateTime.now().millisecondsSinceEpoch}.png');
  await file.writeAsBytes(png);
  return file.path;
}

Uint8List? _processLogo(Uint8List bytes) {
  final src = img.decodeImage(bytes);
  if (src == null) return null;
  final resized = src.width > 576 ? img.copyResize(src, width: 576) : src;
  final canvas = img.Image(width: resized.width, height: resized.height);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(canvas, resized);
  final gray = img.grayscale(canvas);
  // Ambang hitam-putih agar hasil cetak tajam.
  for (final p in gray) {
    final v = p.r > 150 ? 255 : 0;
    p
      ..r = v
      ..g = v
      ..b = v;
  }
  return Uint8List.fromList(img.encodePng(gray));
}
