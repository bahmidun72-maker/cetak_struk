import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/receipt.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'editor_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _query = '';
  ReceiptType? _filter;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final q = _query.toLowerCase();
    final items = state.history.where((r) {
      if (_filter != null && r.type != _filter) return false;
      if (q.isEmpty) return true;
      final hay = [
        r.headline, r.recipientNumber, r.customerId, r.ref, r.token, r.date, r.time,
        r.amount.toString(),
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat'),
        automaticallyImplyLeading: false,
        actions: [
          if (state.history.isNotEmpty)
            IconButton(
              tooltip: 'Hapus semua',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                if (await confirmDialog(context, 'Hapus semua riwayat?',
                    'Semua struk tersimpan akan dihapus dari HP ini.',
                    ok: 'Hapus', danger: true)) {
                  await state.clearHistory();
                }
              },
            ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Cari nama, nomor, token, ref...',
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              ChoiceChip(
                label: const Text('Semua'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              for (final t in ReceiptType.values) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: Icon(typeIcon(t), size: 16),
                  label: Text(t.label),
                  selected: _filter == t,
                  onSelected: (_) => setState(() => _filter = t),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.inbox_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 8),
                    Text(state.history.isEmpty ? 'Belum ada struk tersimpan' : 'Tidak ditemukan'),
                  ]),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                  itemBuilder: (context, i) => ReceiptTile(receipt: items[i], showDelete: true),
                ),
        ),
      ]),
    );
  }
}

/// Satu baris riwayat struk (dipakai juga di beranda).
class ReceiptTile extends StatelessWidget {
  final Receipt receipt;
  final bool showDelete;

  const ReceiptTile({super.key, required this.receipt, this.showDelete = false});

  @override
  Widget build(BuildContext context) {
    final r = receipt;
    final state = context.read<AppState>();
    final tile = ListTile(
      leading: CircleAvatar(
        backgroundColor: typeColor(r.type).withValues(alpha: 0.12),
        child: Icon(typeIcon(r.type), color: typeColor(r.type)),
      ),
      title: Text(r.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          '${r.date.isEmpty ? formatDateTime(r.createdAt) : '${r.date} ${r.time}'.trim()} • ${rupiah(r.total)}',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        tooltip: 'Cetak ulang',
        icon: const Icon(Icons.print_outlined),
        onPressed: () async {
          final res = await state.printReceipt(r);
          if (context.mounted) showSnack(context, res.message);
        },
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EditorScreen(receipt: r)),
      ),
    );
    if (!showDelete) return tile;
    return Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => confirmDialog(context, 'Hapus struk?', r.headline, ok: 'Hapus', danger: true),
      onDismissed: (_) => state.deleteReceipt(r.id),
      child: tile,
    );
  }
}
