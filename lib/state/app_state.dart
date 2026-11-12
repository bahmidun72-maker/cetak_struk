import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/receipt.dart';
import '../services/ocr_service.dart';
import '../services/printer_service.dart';
import '../services/receipt_layout.dart';
import '../services/receipt_parser.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  final StorageService _storage;
  final PrinterService printer = PrinterService();
  final OcrService ocr = OcrService();

  AppSettings settings = AppSettings();
  List<Receipt> history = [];
  bool printerConnected = false;

  AppState(this._storage);

  Future<void> load() async {
    settings = _storage.loadSettings();
    history = _storage.loadHistory();
    // Simpan agar TID acak yang baru dibuat (instalasi pertama) tetap sama.
    await _storage.saveSettings(settings);
    notifyListeners();
  }

  // ------------------------------------------------------------ pengaturan

  Future<void> updateSettings(void Function(AppSettings s) change) async {
    change(settings);
    notifyListeners();
    await _storage.saveSettings(settings);
  }

  // ------------------------------------------------------------ struk

  /// Struk baru dari hasil OCR (atau kosong untuk isi manual), lengkap
  /// dengan biaya admin, pengirim default, dan template default.
  Receipt prepare(Receipt r) {
    r.admin = settings.calcAdmin(r.amount);
    r.template = settings.defaultTemplate;
    if (r.type == ReceiptType.trf && settings.showSender && r.senderName.isEmpty) {
      final s = settings.defaultSenderAccount;
      if (s != null) {
        r.senderName = s.name;
        r.senderBank = s.bank;
        r.senderNumber = s.number;
      }
    }
    return r;
  }

  Receipt newManual(ReceiptType type) => prepare(Receipt.empty(type));

  Future<({Receipt receipt, List<String> rows})> scanImage(String path, {ReceiptType? type}) async {
    final rows = await ocr.readRows(path);
    final r = prepare(ReceiptParser.parse(rows, type: type));
    return (receipt: r, rows: rows);
  }

  Future<void> saveReceipt(Receipt r) async {
    history.removeWhere((e) => e.id == r.id);
    history.insert(0, r.copy());
    notifyListeners();
    await _storage.saveHistory(history);
  }

  Future<void> deleteReceipt(String id) async {
    history.removeWhere((e) => e.id == id);
    notifyListeners();
    await _storage.saveHistory(history);
  }

  Future<void> clearHistory() async {
    history.clear();
    notifyListeners();
    await _storage.saveHistory(history);
  }

  // ------------------------------------------------------------ printer

  Future<void> refreshPrinterStatus() async {
    try {
      printerConnected = await printer.isConnected;
    } catch (_) {
      printerConnected = false;
    }
    notifyListeners();
  }

  Future<bool> connectPrinter(PrinterDevice d) async {
    final ok = await printer.connect(d.mac);
    if (ok) {
      await updateSettings((s) {
        s.printerMac = d.mac;
        s.printerName = d.name;
      });
    }
    printerConnected = ok;
    notifyListeners();
    return ok;
  }

  Future<void> disconnectPrinter() async {
    await printer.disconnect();
    printerConnected = false;
    notifyListeners();
  }

  Future<PrintResult> printReceipt(Receipt r, {int copies = 1}) async {
    final res = await printer.printLines(ReceiptLayout.build(r, settings), settings, copies: copies);
    await refreshPrinterStatus();
    if (res.ok) await saveReceipt(r);
    return res;
  }

  Future<PrintResult> testPrint() async {
    final res = await printer.testPrint(settings);
    await refreshPrinterStatus();
    return res;
  }

  @override
  void dispose() {
    ocr.dispose();
    super.dispose();
  }
}
