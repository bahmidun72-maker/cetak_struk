import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/receipt.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'history_screen.dart';
import 'scan_flow.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onOpenPrinter;
  final VoidCallback onOpenHistory;

  const HomeScreen({super.key, required this.onOpenPrinter, required this.onOpenHistory});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final recent = state.history.take(5).toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.settings.storeName.isEmpty ? 'Cetak Struk' : state.settings.storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                const Text('Scan bukti transaksi → cetak struk thermal. Tanpa internet.',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 14),
                InkWell(
                  onTap: onOpenPrinter,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle,
                          size: 10,
                          color: state.printerConnected ? const Color(0xFF34D399) : Colors.white54),
                      const SizedBox(width: 8),
                      Text(
                        state.printerConnected
                            ? 'Printer: ${state.settings.printerName ?? 'terhubung'}'
                            : (state.settings.printerName == null
                                ? 'Pilih printer'
                                : 'Printer: ${state.settings.printerName} (belum tersambung)'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => pickAndScan(context),
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text('Scan Otomatis dari Galeri',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Foto dengan kamera',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(60, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => pickAndScan(context, source: ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Pilih jenis struk',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                for (final t in ReceiptType.values) ...[
                  if (t != ReceiptType.trf) const SizedBox(width: 10),
                  Expanded(child: _TypeCard(type: t)),
                ],
              ]),
            ),
            const SizedBox(height: 14),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(children: [
                Icon(Icons.lightbulb_outline_rounded, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tips: dari m-banking atau galeri, tekan "Bagikan" lalu pilih Cetak Struk.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Text('Terakhir',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (state.history.isNotEmpty)
                  TextButton(onPressed: onOpenHistory, child: const Text('Lihat semua')),
              ]),
            ),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('Belum ada struk. Mulai dengan scan bukti transaksi.',
                      textAlign: TextAlign.center, style: TextStyle(color: cs.outline)),
                ),
              )
            else
              for (final r in recent) ReceiptTile(receipt: r),
          ],
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final ReceiptType type;
  const _TypeCard({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = typeColor(type);
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showSourceSheet(context, type),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color,
              child: Icon(typeIcon(type), color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              switch (type) {
                ReceiptType.trf => 'Transfer',
                ReceiptType.ewallet => 'E-WALLET',
                ReceiptType.tagihan => 'Tagihan',
              },
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (type == ReceiptType.ewallet)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  'DANA • OVO • GOPAY',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}