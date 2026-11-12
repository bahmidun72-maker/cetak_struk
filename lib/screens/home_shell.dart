import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/share_intent_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'printer_screen.dart';
import 'scan_flow.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  final Set<int> _visited = {0};
  final _share = ShareIntentService();
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _share.images.listen(_openShared);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<AppState>().refreshPrinterStatus();
      final initial = await _share.initialImage();
      if (initial != null) _openShared(initial);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _select(int i) {
    setState(() {
      _tab = i;
      _visited.add(i);
    });
    if (i == 2) context.read<AppState>().refreshPrinterStatus();
  }

  void _openShared(String path) {
    if (!mounted) return;
    if (path.isEmpty) {
      showSnack(context, 'Gambar yang dibagikan tidak bisa dibaca');
      return;
    }
    Navigator.of(context).popUntil((r) => r.isFirst);
    setState(() => _tab = 0);
    scanFromPath(context, path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        // Tab baru dibangun saat pertama kali dibuka (izin Bluetooth baru
        // diminta ketika pengguna membuka tab Printer).
        children: [
          HomeScreen(
            onOpenPrinter: () => _select(2),
            onOpenHistory: () => _select(1),
          ),
          _visited.contains(1) ? const HistoryScreen() : const SizedBox.shrink(),
          _visited.contains(2) ? const PrinterScreen() : const SizedBox.shrink(),
          _visited.contains(3) ? const SettingsScreen() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: 'Riwayat'),
          NavigationDestination(icon: Icon(Icons.print_outlined), selectedIcon: Icon(Icons.print_rounded), label: 'Printer'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Setelan'),
        ],
      ),
    );
  }
}
