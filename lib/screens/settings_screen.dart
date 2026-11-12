import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../services/image_tools.dart';
import '../services/receipt_layout.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _footer;
  late final TextEditingController _adminFixed;
  late final TextEditingController _tid;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().settings;
    _name = TextEditingController(text: s.storeName);
    _address = TextEditingController(text: s.address);
    _footer = TextEditingController(text: s.footer);
    _adminFixed = TextEditingController(text: s.adminFixed == 0 ? '' : thousands(s.adminFixed));
    _tid = TextEditingController(text: s.terminalId);
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _footer.dispose();
    _adminFixed.dispose();
    _tid.dispose();
    super.dispose();
  }

  Future<void> _pickLogo(AppState state) async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final path = await prepareLogo(x.path);
    if (path == null) {
      if (mounted) showSnack(context, 'Gambar tidak bisa dibaca');
      return;
    }
    final old = state.settings.logoPath;
    await state.updateSettings((s) => s.logoPath = path);
    if (old != null) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
  }

  Future<void> _removeLogo(AppState state) async {
    final old = state.settings.logoPath;
    await state.updateSettings((s) => s.logoPath = null);
    if (old != null) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
  }

  Future<void> _addRule(AppState state) async {
    final min = TextEditingController();
    final max = TextEditingController();
    final fee = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Aturan biaya admin'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _moneyInput(min, 'Nominal dari'),
          const SizedBox(height: 10),
          _moneyInput(max, 'Sampai (kosongkan = tak terbatas)'),
          const SizedBox(height: 10),
          _moneyInput(fee, 'Biaya admin'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Tambah')),
        ],
      ),
    );
    if (ok == true) {
      final rule = AdminRule(
        min: digitsToInt(min.text),
        max: max.text.trim().isEmpty ? null : digitsToInt(max.text),
        fee: digitsToInt(fee.text),
      );
      await state.updateSettings((s) => s.adminRules
        ..add(rule)
        ..sort((a, b) => a.min.compareTo(b.min)));
    }
  }

  Future<void> _addSender(AppState state) async {
    final name = TextEditingController();
    final bank = TextEditingController();
    final number = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rekening pengirim'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Nama pemilik')),
          const SizedBox(height: 10),
          TextField(
              controller: bank,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Bank / e-wallet')),
          const SizedBox(height: 10),
          TextField(
              controller: number,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'No. rekening')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Tambah')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await state.updateSettings((s) => s.senders.add(SenderAccount(
            name: name.text.trim().toUpperCase(),
            bank: bank.text.trim().toUpperCase(),
            number: number.text.trim(),
          )));
    }
  }

  Widget _moneyInput(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [ThousandsInputFormatter()],
        decoration: InputDecoration(labelText: label, prefixText: 'Rp '),
      );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;
    final logo = s.logoPath;

    return Scaffold(
      appBar: AppBar(title: const Text('Setelan'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        children: [
          SectionCard(title: 'Identitas Toko', icon: Icons.storefront_outlined, children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Nama toko'),
              onChanged: (v) => state.updateSettings((x) => x.storeName = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _address,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(labelText: 'Alamat / no. HP (opsional)'),
              onChanged: (v) => state.updateSettings((x) => x.address = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _footer,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(labelText: 'Teks penutup struk'),
              onChanged: (v) => state.updateSettings((x) => x.footer = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tid,
              textCapitalization: TextCapitalization.characters,
              maxLength: 12,
              decoration: const InputDecoration(
                labelText: 'ID terminal (TID)',
                helperText: 'Dicetak sebagai "TID". Kosongkan untuk menyembunyikan.',
                counterText: '',
              ),
              onChanged: (v) => state.updateSettings((x) => x.terminalId = v.trim().toUpperCase()),
            ),
          ]),
          SectionCard(title: 'Logo Struk', icon: Icons.image_outlined, children: [
            if (logo != null && File(logo).existsSync()) ...[
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                height: 110,
                child: Image.file(File(logo), fit: BoxFit.contain),
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Lebar'),
                Expanded(
                  child: Slider(
                    min: 20,
                    max: 100,
                    divisions: 16,
                    value: s.logoWidthPct.toDouble().clamp(20, 100),
                    label: '${s.logoWidthPct}%',
                    onChanged: (v) => state.updateSettings((x) => x.logoWidthPct = v.round()),
                  ),
                ),
                Text('${s.logoWidthPct}%'),
              ]),
            ],
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickLogo(state),
                  icon: const Icon(Icons.upload_outlined),
                  label: Text(logo == null ? 'Pilih logo' : 'Ganti logo'),
                ),
              ),
              if (logo != null) ...[
                const SizedBox(width: 10),
                TextButton(onPressed: () => _removeLogo(state), child: const Text('Hapus')),
              ],
            ]),
            const SizedBox(height: 6),
            Text('Logo dicetak hitam-putih. Gunakan gambar kontras dengan latar putih.',
                style: Theme.of(context).textTheme.bodySmall),
          ]),
          SectionCard(title: 'Biaya Admin Otomatis', icon: Icons.price_change_outlined, children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Tetap')),
                ButtonSegment(value: true, label: Text('Berjenjang')),
              ],
              selected: {s.adminTiered},
              onSelectionChanged: (v) => state.updateSettings((x) => x.adminTiered = v.first),
            ),
            const SizedBox(height: 12),
            if (!s.adminTiered)
              TextField(
                controller: _adminFixed,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsInputFormatter()],
                decoration: const InputDecoration(labelText: 'Biaya admin per transaksi', prefixText: 'Rp '),
                onChanged: (v) => state.updateSettings((x) => x.adminFixed = digitsToInt(v)),
              )
            else ...[
              if (s.adminRules.isEmpty)
                Text('Belum ada aturan. Contoh: Rp 0 - 100.000 admin Rp 3.000.',
                    style: Theme.of(context).textTheme.bodySmall),
              for (var i = 0; i < s.adminRules.length; i++)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.stairs_outlined),
                  title: Text(
                      '${rupiah(s.adminRules[i].min)} - ${s.adminRules[i].max == null ? 'seterusnya' : rupiah(s.adminRules[i].max!)}'),
                  subtitle: Text('Admin ${rupiah(s.adminRules[i].fee)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => state.updateSettings((x) => x.adminRules.removeAt(i)),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _addRule(state),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah aturan'),
                ),
              ),
            ],
          ]),
          SectionCard(
            title: 'Rekening Pengirim',
            icon: Icons.account_balance_outlined,
            trailing: Switch(
              value: s.showSender,
              onChanged: (v) => state.updateSettings((x) => x.showSender = v),
            ),
            children: [
              Text('Bila aktif, data pengirim dicetak di struk transfer.',
                  style: Theme.of(context).textTheme.bodySmall),
              for (var i = 0; i < s.senders.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    i == s.defaultSender ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: i == s.defaultSender ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: Text(s.senders[i].name),
                  subtitle: Text('${s.senders[i].bank} • ${s.senders[i].number}'),
                  onTap: () => state.updateSettings((x) => x.defaultSender = i),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => state.updateSettings((x) {
                      x.senders.removeAt(i);
                      if (x.defaultSender >= x.senders.length) x.defaultSender = 0;
                    }),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _addSender(state),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah rekening'),
                ),
              ),
            ],
          ),
          SectionCard(title: 'Template Default', icon: Icons.view_agenda_outlined, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < ReceiptLayout.templateNames.length; i++)
                ChoiceChip(
                  label: Text('${i + 1}. ${ReceiptLayout.templateNames[i]}'),
                  selected: s.defaultTemplate == i,
                  showCheckmark: false,
                  onSelected: (_) => state.updateSettings((x) => x.defaultTemplate = i),
                ),
            ]),
            const SizedBox(height: 6),
            Text('Template bisa diganti per struk di layar preview.',
                style: Theme.of(context).textTheme.bodySmall),
          ]),
          SectionCard(title: 'Data', icon: Icons.storage_outlined, children: [
            Text('${state.history.length} struk tersimpan di HP ini.'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: state.history.isEmpty
                  ? null
                  : () async {
                      if (await confirmDialog(context, 'Hapus semua riwayat?',
                          'Semua struk tersimpan akan dihapus.', ok: 'Hapus', danger: true)) {
                        await state.clearHistory();
                      }
                    },
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Hapus riwayat'),
            ),
          ]),
          Center(
            child: Text('Cetak Struk v1.0 • 100% offline',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
