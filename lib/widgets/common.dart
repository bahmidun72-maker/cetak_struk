import 'package:flutter/material.dart';

import '../models/receipt.dart';

/// Kartu bagian dengan judul (dipakai di editor & setelan).
class SectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;
  final Widget? trailing;

  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: cs.primary),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              ?trailing,
            ]),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

IconData typeIcon(ReceiptType t) => switch (t) {
      ReceiptType.trf => Icons.swap_horiz_rounded,
      ReceiptType.ewallet => Icons.account_balance_wallet_rounded,
      ReceiptType.tagihan => Icons.receipt_long_rounded,
    };

Color typeColor(ReceiptType t) => switch (t) {
      ReceiptType.trf => const Color(0xFF4F46E5),
      ReceiptType.ewallet => const Color(0xFFEC4899),
      ReceiptType.tagihan => const Color(0xFF10B981),
    };

void showSnack(BuildContext context, String msg, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), action: action));
}

Future<bool> confirmDialog(BuildContext context, String title, String message,
    {String ok = 'Ya', bool danger = false}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Colors.red) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return res ?? false;
}