import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ocr_layout.dart';

/// OCR di perangkat (offline) memakai ML Kit Text Recognition (model Latin bawaan APK).
class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Membaca gambar dan mengembalikan baris-baris teks yang sudah disusun.
  Future<List<String>> readRows(String imagePath) async {
    final result = await _recognizer.processImage(InputImage.fromFilePath(imagePath));
    final pieces = <OcrPiece>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final b = line.boundingBox;
        pieces.add(OcrPiece(line.text, b.left, b.top, b.right, b.bottom));
      }
    }
    return groupIntoRows(pieces);
  }

  Future<void> dispose() => _recognizer.close();
}
