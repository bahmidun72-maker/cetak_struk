import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/printer_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

class PrinterScreen extends StatefulWidget {
  /// true bila dibuka sebagai halaman terpisah (bukan tab).
  final bool standalone;

  const PrinterScreen({super.key, this.standalone = false});

  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  List<PrinterDevice> _devices = [];
  bool _loading = false;
  bool _btOff = false;
  String? _connecting;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final state = context.read<AppState>();
    setState(() => _loading = true);
    try {
      final granted = await state.printer.ensurePermissions();
      if (!granted) {
        if (mounted) showSnack(context, 'Izin Bluetooth diperlukan untuk mencari printer');
        return;
      }
      _btOff = !await state.printer.bluetoothEnabled;
      _devices = _btOff ? [] : await state.printer.pairedDevices();
      await state.refreshPrinterStatus();
    } catch (e) {
      if (mounted) showSnack(context, 'Gagal membaca Bluetooth: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect(PrinterDevice d) async {
    setState(() => _connecting = d.mac);
    final ok = await context.read<AppState>().connectPrinter(d);
    if (!mounted) return;
    setState(() => _connecting = null);
    showSnack(context, ok ? 'Terhubung ke ${d.name}' : 'Gagal terhubung ke ${d.name}');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;
    final cs = Theme.of(context).colorScheme;

    final body = RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            color: state.printerConnected ? const Color(0xFFECFDF5) : cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(
                  state.printerConnected ? Icons.print_rounded : Icons.print_disabled_outlined,
                  size: 36,
                  color: state.printerConnected ? const Color(0xFF059669) : cs.outline,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(state.printerConnected ? 'Terhubung' : 'Tidak terhubung',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(s.printerName ?? 'Belum ada printer dipilih',
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
                if (state.printerConnected)
                  TextButton(onPressed: state.disconnectPrinter, child: const Text('Putuskan')),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () async {
                final res = await state.testPrint();
                if (context.mounted) showSnack(context, res.ok ? 'Tes cetak terkirim' : res.message);
              },
              icon: const Icon(Icons.receipt_rounded),
              label: const Text('Tes Cetak'),
            ),
          ),
          SectionCard(
            title: 'Ukuran Kertas',
            icon: Icons.straighten_rounded,
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 58, label: Text('58 mm (32 kar)')),
                  ButtonSegment(value: 80, label: Text('80 mm (48 kar)')),
                ],
                selected: {s.paperWidth},
                onSelectionChanged: (v) => state.updateSettings((x) => x.paperWidth = v.first),
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Expanded(child: Text('Spasi kosong di akhir struk')),
                IconButton(
                  onPressed: s.feedLines > 1
                      ? () => state.updateSettings((x) => x.feedLines--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('${s.feedLines} baris'),
                IconButton(
                  onPressed: s.feedLines < 8
                      ? () => state.updateSettings((x) => x.feedLines++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ]),
            ],
          ),
          SectionCard(
            title: 'Printer Bluetooth Tersanding',
            icon: Icons.bluetooth_rounded,
            trailing: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
            children: [
              if (_btOff)
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.bluetooth_disabled_rounded, color: Colors.red),
                  title: Text('Bluetooth mati'),
                  subtitle: Text('Nyalakan Bluetooth di HP lalu tekan refresh.'),
                )
              else if (_devices.isEmpty && !_loading)
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('Belum ada perangkat'),
                  subtitle: Text(
                      'Sandingkan (pair) printer dulu di Pengaturan > Bluetooth HP. PIN umumnya 0000 atau 1234.'),
                ),
              for (final d in _devices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.print_outlined,
                      color: d.mac == s.printerMac ? cs.primary : null),
                  title: Text(d.name.isEmpty ? '(tanpa nama)' : d.name),
                  subtitle: Text(d.mac),
                  trailing: _connecting == d.mac
                      ? const SizedBox(
                          width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : (d.mac == s.printerMac && state.printerConnected)
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF059669))
                          : FilledButton.tonal(
                              onPressed: _connecting == null ? () => _connect(d) : null,
                              child: const Text('Hubungkan'),
                            ),
                ),
            ],
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Printer'), automaticallyImplyLeading: widget.standalone),
      body: body,
    );
  }
}
