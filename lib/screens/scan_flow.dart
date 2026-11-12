import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/receipt.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'editor_screen.dart';

/// Pilih gambar (galeri/kamera) lalu proses.
Future<void> pickAndScan(BuildContext context,
    {ReceiptType? type, ImageSource source = ImageSource.gallery}) async {
  final XFile? picked;
  try {
    picked = await ImagePicker().pickImage(source: source);
  } catch (e) {
    if (context.mounted) showSnack(context, 'Tidak bisa membuka ${source == ImageSource.camera ? 'kamera' : 'galeri'}');
    return;
  }
  if (picked == null || !context.mounted) return;
  await scanFromPath(context, picked.path, type: type);
}

/// OCR offline -> parse -> buka editor.
Future<void> scanFromPath(BuildContext context, String path, {ReceiptType? type}) async {
  final state = context.read<AppState>();
  final nav = Navigator.of(context);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          SizedBox(width: 18),
          Expanded(child: Text('Membaca struk...')),
        ]),
      ),
    ),
  );
  try {
    final res = await state.scanImage(path, type: type);
    nav.pop();
    if (!context.mounted) return;
    if (res.rows.isEmpty) {
      showSnack(context, 'Tidak ada teks yang terbaca. Coba gambar yang lebih jelas.');
      return;
    }
    nav.push(MaterialPageRoute(
      builder: (_) => EditorScreen(receipt: res.receipt, ocrRows: res.rows, imagePath: path, isNew: true),
    ));
  } catch (e) {
    nav.pop();
    if (context.mounted) showSnack(context, 'Gagal membaca gambar: $e');
  }
}

/// Lembar pilihan sumber: galeri, kamera, atau isi manual.
Future<void> showSourceSheet(BuildContext context, ReceiptType type) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          title: Text(type.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          leading: Icon(typeIcon(type), color: typeColor(type)),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Pilih screenshot dari galeri'),
          onTap: () {
            Navigator.pop(c);
            pickAndScan(context, type: type);
          },
        ),
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: const Text('Foto struk dengan kamera'),
          onTap: () {
            Navigator.pop(c);
            pickAndScan(context, type: type, source: ImageSource.camera);
          },
        ),
        ListTile(
          leading: const Icon(Icons.edit_note_rounded),
          title: const Text('Isi manual'),
          onTap: () {
            Navigator.pop(c);
            final r = context.read<AppState>().newManual(type);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => EditorScreen(receipt: r, isNew: true)));
          },
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
}
