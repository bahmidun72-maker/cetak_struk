import 'dart:convert';

enum ReceiptType { trf, ewallet, tagihan }

class DetailRow {
  String label;
  String value;
  DetailRow({required this.label, required this.value});

  Map<String, dynamic> toJson() => {'label': label, 'value': value};
  factory DetailRow.fromJson(Map<String, dynamic> j) =>
      DetailRow(label: j['label'] ?? '', value: j['value'] ?? '');
}

class Receipt {
  ReceiptType type;
  String date;
  String time;
  String ref;
  int amount;
  int admin;
  int template;

  // Transfer
  String senderName;
  String senderNumber;
  String senderBank;
  String recipientName;
  String recipientNumber;
  String recipientBank;
  String note;

  // E-Wallet (BARU - Pengganti PLN)
  String ewalletProvider;
  String ewalletName;
  String ewalletNumber;

  // Tagihan / Lama (biar file lama tidak error)
  String customerId;
  String customerName;
  String category;
  String period;
  String token;
  String tariff;
  String kwh;
  List<DetailRow> details;

  Receipt({
    required this.type,
    this.date = '',
    this.time = '',
    this.ref = '',
    this.amount = 0,
    this.admin = 0,
    this.template = 0,
    this.senderName = '',
    this.senderNumber = '',
    this.senderBank = '',
    this.recipientName = '',
    this.recipientNumber = '',
    this.recipientBank = '',
    this.note = '',
    this.ewalletProvider = '',
    this.ewalletName = '',
    this.ewalletNumber = '',
    this.customerId = '',
    this.customerName = '',
    this.category = '',
    this.period = '',
    this.token = '',
    this.tariff = '',
    this.kwh = '',
    List<DetailRow>? details,
  }) : details = details ?? [];

  factory Receipt.empty(ReceiptType t) => Receipt(type: t);

  int get total => amount + admin;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'date': date,
        'time': time,
        'ref': ref,
        'amount': amount,
        'admin': admin,
        'template': template,
        'senderName': senderName,
        'senderNumber': senderNumber,
        'senderBank': senderBank,
        'recipientName': recipientName,
        'recipientNumber': recipientNumber,
        'recipientBank': recipientBank,
        'note': note,
        'ewalletProvider': ewalletProvider,
        'ewalletName': ewalletName,
        'ewalletNumber': ewalletNumber,
        'customerId': customerId,
        'customerName': customerName,
        'category': category,
        'period': period,
        'token': token,
        'tariff': tariff,
        'kwh': kwh,
        'details': details.map((e) => e.toJson()).toList(),
      };

  factory Receipt.fromJson(Map<String, dynamic> j) => Receipt(
        type: ReceiptType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => ReceiptType.trf,
        ),
        date: j['date'] ?? '',
        time: j['time'] ?? '',
        ref: j['ref'] ?? '',
        amount: (j['amount'] ?? 0) as int,
        admin: (j['admin'] ?? 0) as int,
        template: (j['template'] ?? 0) as int,
        senderName: j['senderName'] ?? '',
        senderNumber: j['senderNumber'] ?? '',
        senderBank: j['senderBank'] ?? '',
        recipientName: j['recipientName'] ?? '',
        recipientNumber: j['recipientNumber'] ?? '',
        recipientBank: j['recipientBank'] ?? '',
        note: j['note'] ?? '',
        ewalletProvider: j['ewalletProvider'] ?? '',
        ewalletName: j['ewalletName'] ?? '',
        ewalletNumber: j['ewalletNumber'] ?? '',
        customerId: j['customerId'] ?? '',
        customerName: j['customerName'] ?? '',
        category: j['category'] ?? '',
        period: j['period'] ?? '',
        token: j['token'] ?? '',
        tariff: j['tariff'] ?? '',
        kwh: j['kwh'] ?? '',
        details: (j['details'] as List? ?? [])
            .map((e) => DetailRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String toJsonString() => jsonEncode(toJson());
  factory Receipt.fromJsonString(String s) =>
      Receipt.fromJson(jsonDecode(s) as Map<String, dynamic>);
}