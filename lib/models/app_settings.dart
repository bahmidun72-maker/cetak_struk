import 'dart:math';

/// Aturan biaya admin berjenjang: nominal di antara [min] dan [max] dikenai [fee].
class AdminRule {
  int min;
  int? max; // null = tanpa batas atas
  int fee;

  AdminRule({required this.min, this.max, required this.fee});

  bool matches(int amount) => amount >= min && (max == null || amount <= max!);

  Map<String, dynamic> toJson() => {'min': min, 'max': max, 'fee': fee};

  factory AdminRule.fromJson(Map<String, dynamic> j) => AdminRule(
        min: (j['min'] as num?)?.toInt() ?? 0,
        max: (j['max'] as num?)?.toInt(),
        fee: (j['fee'] as num?)?.toInt() ?? 0,
      );
}

/// Rekening pengirim yang sering dipakai (ditampilkan di struk transfer).
class SenderAccount {
  String name;
  String bank;
  String number;

  SenderAccount({this.name = '', this.bank = '', this.number = ''});

  Map<String, dynamic> toJson() => {'name': name, 'bank': bank, 'number': number};

  factory SenderAccount.fromJson(Map<String, dynamic> j) => SenderAccount(
        name: j['name'] ?? '',
        bank: j['bank'] ?? '',
        number: j['number'] ?? '',
      );
}

class AppSettings {
  String storeName;
  String address;
  String footer;

  String? logoPath;
  int logoWidthPct;

  bool adminTiered;
  int adminFixed;
  List<AdminRule> adminRules;

  bool showSender;
  List<SenderAccount> senders;
  int defaultSender;

  int paperWidth; // 58 atau 80 (mm)
  int defaultTemplate;
  int feedLines;

  String? printerMac;
  String? printerName;
  String terminalId; // TID yang tercetak di struk

  AppSettings({
    this.storeName = 'TOKO SAYA',
    this.address = '',
    this.footer = 'TERIMA KASIH',
    this.logoPath,
    this.logoWidthPct = 60,
    this.adminTiered = false,
    this.adminFixed = 0,
    List<AdminRule>? adminRules,
    this.showSender = false,
    List<SenderAccount>? senders,
    this.defaultSender = 0,
    this.paperWidth = 58,
    this.defaultTemplate = 0,
    this.feedLines = 3,
    this.printerMac,
    this.printerName,
    String? terminalId,
  })  : terminalId = terminalId ?? _randomTid(),
        adminRules = adminRules ?? [],
        senders = senders ?? [];

  /// TID acak 6 karakter, dibuat sekali per instalasi.
  static String _randomTid() {
    final rnd = Random();
    return List.generate(6, (_) => '0123456789ABCDEF'[rnd.nextInt(16)]).join();
  }

  /// Jumlah karakter per baris untuk font standar printer thermal.
  int get charsPerLine => paperWidth == 80 ? 48 : 32;

  /// Lebar kertas dalam dot (203 dpi).
  int get paperDots => paperWidth == 80 ? 576 : 384;

  SenderAccount? get defaultSenderAccount =>
      senders.isEmpty ? null : senders[defaultSender.clamp(0, senders.length - 1)];

  int calcAdmin(int amount) {
    if (!adminTiered) return adminFixed;
    var fee = 0;
    for (final r in adminRules) {
      if (r.matches(amount)) fee = r.fee;
    }
    return fee;
  }

  Map<String, dynamic> toJson() => {
        'storeName': storeName,
        'address': address,
        'footer': footer,
        'logoPath': logoPath,
        'logoWidthPct': logoWidthPct,
        'adminTiered': adminTiered,
        'adminFixed': adminFixed,
        'adminRules': adminRules.map((r) => r.toJson()).toList(),
        'showSender': showSender,
        'senders': senders.map((s) => s.toJson()).toList(),
        'defaultSender': defaultSender,
        'paperWidth': paperWidth,
        'defaultTemplate': defaultTemplate,
        'feedLines': feedLines,
        'printerMac': printerMac,
        'printerName': printerName,
        'terminalId': terminalId,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        storeName: j['storeName'] ?? 'TOKO SAYA',
        address: j['address'] ?? '',
        footer: j['footer'] ?? 'TERIMA KASIH',
        logoPath: j['logoPath'],
        logoWidthPct: (j['logoWidthPct'] as num?)?.toInt() ?? 60,
        adminTiered: j['adminTiered'] ?? false,
        adminFixed: (j['adminFixed'] as num?)?.toInt() ?? 0,
        adminRules: ((j['adminRules'] as List?) ?? [])
            .map((e) => AdminRule.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        showSender: j['showSender'] ?? false,
        senders: ((j['senders'] as List?) ?? [])
            .map((e) => SenderAccount.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        defaultSender: (j['defaultSender'] as num?)?.toInt() ?? 0,
        paperWidth: (j['paperWidth'] as num?)?.toInt() ?? 58,
        defaultTemplate: (j['defaultTemplate'] as num?)?.toInt() ?? 0,
        feedLines: (j['feedLines'] as num?)?.toInt() ?? 3,
        printerMac: j['printerMac'],
        printerName: j['printerName'],
        terminalId: j['terminalId'], // null = belum ada -> dibuat acak
      );
}
