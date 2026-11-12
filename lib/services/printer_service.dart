import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../models/app_settings.dart';
import 'receipt_layout.dart';

class PrinterDevice {
  final String name;
  final String mac;
  const PrinterDevice(this.name, this.mac);
}

/// Hasil cetak beserta pesan untuk pengguna.
class PrintResult {
  final bool ok;
  final String message;
  const PrintResult(this.ok, this.message);
}

/// Printer thermal Bluetooth (Classic/SPP) dengan perintah ESC/POS.
class PrinterService {
  Future<bool> ensurePermissions() async {
    if (!Platform.isAndroid) return true;
    final statuses = await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
    // Di Android 11 ke bawah izin ini otomatis "granted".
    return statuses.values.every((s) => s.isGranted || s.isLimited);
  }

  Future<bool> get bluetoothEnabled => PrintBluetoothThermal.bluetoothEnabled;

  Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  Future<List<PrinterDevice>> pairedDevices() async {
    final list = await PrintBluetoothThermal.pairedBluetooths;
    return list.map((d) => PrinterDevice(d.name, d.macAdress)).toList();
  }

  Future<bool> connect(String mac) async {
    try {
      if (await PrintBluetoothThermal.connectionStatus) {
        await PrintBluetoothThermal.disconnect;
      }
      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
      if (ok) await Future.delayed(const Duration(milliseconds: 500));
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
  }

  /// Pastikan tersambung ke printer tersimpan; sambung ulang bila perlu.
  Future<PrintResult> _ready(AppSettings s) async {
    if (!await ensurePermissions()) {
      return const PrintResult(false, 'Izin Bluetooth ditolak');
    }
    if (!await bluetoothEnabled) {
      return const PrintResult(false, 'Bluetooth belum aktif');
    }
    if (await isConnected) return const PrintResult(true, '');
    if (s.printerMac == null) {
      return const PrintResult(false, 'Printer belum dipilih. Buka menu Printer.');
    }
    final ok = await connect(s.printerMac!);
    return ok
        ? const PrintResult(true, '')
        : PrintResult(false, 'Gagal tersambung ke ${s.printerName ?? 'printer'}');
  }

  Future<PrintResult> printLines(List<RLine> lines, AppSettings s, {int copies = 1}) async {
    final ready = await _ready(s);
    if (!ready.ok) return ready;

    final bytes = await buildBytes(lines, s);
    for (var i = 0; i < copies; i++) {
      final ok = await PrintBluetoothThermal.writeBytes(bytes);
      if (!ok) return const PrintResult(false, 'Gagal mengirim data ke printer');
    }
    return const PrintResult(true, 'Struk dicetak');
  }

  Future<PrintResult> testPrint(AppSettings s) {
    final w = s.charsPerLine;
    return printLines([
      RLine('=' * w),
      RLine(_center('TES PRINTER', w), bold: true),
      RLine(_center(ReceiptLayout.clean(s.storeName), w)),
      RLine(_center('KERTAS ${s.paperWidth}MM - $w KARAKTER', w)),
      RLine('1234567890' * (w ~/ 10) + '1234567890'.substring(0, w % 10)),
      RLine(_center('BERHASIL TERHUBUNG', w), bold: true, big: true),
      RLine('=' * w),
    ], s);
  }

  static String _center(String t, int w) => '${' ' * ((w - t.length) ~/ 2).clamp(0, w)}$t';

  Future<List<int>> buildBytes(List<RLine> lines, AppSettings s) async {
    final profile = await CapabilityProfile.load();
    final gen = Generator(s.paperWidth == 80 ? PaperSize.mm80 : PaperSize.mm58, profile);
    var bytes = <int>[];
    bytes += gen.reset();

    final logo = await _loadLogo(s);
    if (logo != null) {
      bytes += gen.imageRaster(logo, align: PosAlign.center);
      bytes += gen.feed(1);
    }

    for (final l in lines) {
      bytes += gen.text(
        l.text.trimRight(),
        styles: PosStyles(
          bold: l.bold,
          height: l.size == RSize.normal ? PosTextSize.size1 : PosTextSize.size2,
          width: l.size == RSize.big ? PosTextSize.size2 : PosTextSize.size1,
        ),
      );
    }
    bytes += gen.feed(s.feedLines.clamp(1, 8));
    return bytes;
  }

  Future<img.Image?> _loadLogo(AppSettings s) async {
    final path = s.logoPath;
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final decoded = img.decodeImage(await file.readAsBytes());
    if (decoded == null) return null;
    final target = (s.paperDots * s.logoWidthPct / 100).round().clamp(32, s.paperDots);
    // Lebar raster harus kelipatan 8.
    final width = target - target % 8;
    final resized = img.copyResize(decoded, width: width, interpolation: img.Interpolation.average);
    return img.grayscale(resized);
  }
}
