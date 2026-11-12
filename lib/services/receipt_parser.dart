import '../models/receipt.dart';
import '../utils/format.dart';

/// Membaca teks hasil OCR (baris-baris) menjadi data struk.
class ReceiptParser {
  ReceiptParser._();

  // ---------------------------------------------------------------- deteksi

  static ReceiptType detectType(List<String> rows) {
    final t = rows.join('\n').toLowerCase();
    int score(Map<String, int> rules) {
      var s = 0;
      rules.forEach((pattern, w) {
        if (RegExp(pattern).hasMatch(t)) s += w;
      });
      return s;
    }

    final ewallet = score({
      r'\bdana\b': 5,
      r'\bovo\b': 5,
      r'go-?pay': 5,
      r'shopee ?pay': 4,
      r'link ?aja': 4,
      r'top ?up.*e-?wallet|e-?wallet': 4,
      r'detail penerima|penerima.*e-?wallet': 3,
      r'no\.?\s*hp.*penerima|nomor.*penerima': 2,
      r'top up': 2,
    });

    final bill = score({
      r'pascabayar|pasca bayar': 4,
      r'tagihan': 2,
      r'pdam|air minum': 4,
      r'bpjs': 4,
      r'periode|bln/thn|bulan/tahun': 2,
      r'id pelanggan': 1,
      r'pulsa|paket data|kuota': 3,
      r'indihome|telkom(?!sel)': 3,
      r'angsuran|cicilan|multifinance': 3,
      r'\bpbb\b': 3,
      r'denda': 1,
      r'stand meter': 2,
    });

    final trf = score({
      r'transfer': 3,
      r'penerima': 2,
      r'rekening': 2,
      r'pengirim': 2,
      r'bi-?fast|\bskn\b|\brtgs\b|antar bank|sesama': 3,
      r'tujuan': 1,
      r'berita|keterangan': 1,
    });

    if (ewallet >= 5 && ewallet >= bill && ewallet >= trf) return ReceiptType.ewallet;
    if (bill > trf && bill >= ewallet) return ReceiptType.tagihan;
    if (ewallet > trf && ewallet > bill) return ReceiptType.ewallet;
    return ReceiptType.trf;
  }

  // ---------------------------------------------------------------- parse

  static Receipt parse(List<String> rawRows, {ReceiptType? type}) {
    final rows = rawRows.map((r) => r.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        .where((r) => r.isNotEmpty)
        .toList();
    final cols = rawRows.map((r) => r.trim()).where((r) => r.isNotEmpty).toList();
    final doc = _Doc(cols);
    final t = type ?? detectType(rows);
    final r = Receipt.empty(t);

    final dt = splitDateTime(findDate(cols) ?? formatDateTime(DateTime.now()));
    r
      ..date = dt.date
      ..time = dt.time;
    r.ref = _findRef(doc) ?? '';

    switch (t) {
      case ReceiptType.trf:
        _parseTransfer(doc, r);
      case ReceiptType.ewallet:
        _parseEwallet(doc, r);
      case ReceiptType.tagihan:
        _parseBill(doc, r);
    }
    return r;
  }

  // ---------------------------------------------------------------- transfer

  static const _recipientNameLabels = [
    'nama penerima', 'nama tujuan', 'nama rekening tujuan', 'nama pemilik rekening',
    'beneficiary name', 'recipient name', 'penerima',
  ];
  static const _recipientAnchorLabels = [
    'penerima', 'tujuan', 'transfer ke', 'kepada', 'ke', 'to', 'beneficiary', 'recipient',
  ];
  static const _recipientAccountLabels = [
    'no. rekening tujuan', 'nomor rekening tujuan', 'no. rek tujuan', 'rekening tujuan',
    'rek. tujuan', 'nomor rekening penerima', 'rekening penerima', 'nomor tujuan',
    'no. tujuan', 'akun tujuan', 'nomor akun', 'account number', 'no. rekening',
    'nomor rekening', 'no. rek',
  ];
  static const _recipientBankLabels = ['bank tujuan', 'bank penerima', 'nama bank tujuan', 'nama bank', 'bank'];
  static const _senderLabels = [
    'nama pengirim', 'pengirim', 'rekening sumber', 'sumber rekening', 'rekening asal',
    'sumber dana', 'dari', 'from', 'sender',
  ];
  static const _stopLabels = [
    'pengirim', 'dari', 'sumber', 'nominal', 'jumlah', 'total', 'biaya', 'berita', 'keterangan',
    'catatan', 'tanggal', 'waktu', 'no. ref', 'referensi', 'id transaksi', 'status', 'metode',
  ];

  static void _parseTransfer(_Doc doc, Receipt r) {
    final senderHit = doc.find(_senderLabels, accept: (v) => v.isNotEmpty);
    final senderRows = <int>{};
    if (senderHit != null) {
      final w = doc.window(senderHit.labelRow, senderHit.inline, 3, _recipientAnchorLabels);
      senderRows.addAll(w.rows);
      r.senderName = _firstName(w.values) ?? '';
      r.senderNumber = _firstAccount(w.values) ?? '';
      r.senderBank = _firstBank(w.values) ?? '';
    }
    final nameHit = doc.find(_recipientNameLabels, accept: _looksLikeName, skipRows: senderRows);
    if (nameHit != null) r.recipientName = _firstName([nameHit.value]) ?? '';
    final accHit = doc.find(_recipientAccountLabels,
        accept: (v) => findAccount(v) != null, skipRows: senderRows);
    if (accHit != null) r.recipientNumber = findAccount(accHit.value)!;
    final bankHit = doc.find(_recipientBankLabels,
        accept: (v) => findBank(v) != null, skipRows: senderRows);
    if (bankHit != null) r.recipientBank = findBank(bankHit.value)!;
    if (r.recipientName.isEmpty || r.recipientNumber.isEmpty || r.recipientBank.isEmpty) {
      final anchor = doc.find(_recipientAnchorLabels, accept: (_) => true, skipRows: senderRows);
      if (anchor != null) {
        final w = doc.window(anchor.labelRow, anchor.inline, 4, _stopLabels);
        if (r.recipientName.isEmpty) r.recipientName = _firstName(w.values) ?? '';
        if (r.recipientNumber.isEmpty) r.recipientNumber = _firstAccount(w.values) ?? '';
        if (r.recipientBank.isEmpty) r.recipientBank = _firstBank(w.values) ?? '';
      }
    }
    final otherRows = [
      for (var i = 0; i < doc.rows.length; i++)
        if (!senderRows.contains(i)) doc.rows[i],
    ];
    if (r.recipientBank.isEmpty) r.recipientBank = _firstBank(otherRows) ?? '';
    if (r.recipientNumber.isEmpty) {
      for (final row in otherRows) {
        if (_isMetaRow(row)) continue;
        final a = findAccount(row);
        if (a != null && a.replaceAll(RegExp(r'\D'), '') != r.ref.replaceAll(RegExp(r'\D'), '')) {
          r.recipientNumber = a;
          break;
        }
      }
    }
    r.amount = _findAmount(doc, const [
      'nominal transfer', 'jumlah transfer', 'total transfer', 'nominal', 'jumlah', 'amount',
    ], secondary: const ['total']);
    final note = doc.find(const [
      'berita transfer', 'berita', 'keterangan', 'catatan', 'pesan', 'remark', 'note', 'deskripsi',
    ], accept: (v) => v.replaceAll(RegExp(r'[-\s]'), '').isNotEmpty);
    if (note != null) r.note = note.value.trim();
  }

  // ---------------------------------------------------------------- E-WALLET

  static void _parseEwallet(_Doc doc, Receipt r) {
    final allText = doc.rows.join('\n');
    final low = allText.toLowerCase();
    if (RegExp(r'\bdana\b').hasMatch(low)) {
      r.ewalletProvider = 'DANA';
    } else if (RegExp(r'\bovo\b').hasMatch(low)) {
      r.ewalletProvider = 'OVO';
    } else if (RegExp(r'go-?pay').hasMatch(low)) {
      r.ewalletProvider = 'GOPAY';
    } else if (RegExp(r'shopee ?pay').hasMatch(low)) {
      r.ewalletProvider = 'SHOPEEPAY';
    } else if (RegExp(r'link ?aja').hasMatch(low)) {
      r.ewalletProvider = 'LINKAJA';
    } else {
      final pHit = doc.find(const ['e-wallet', 'ewallet', 'dompet digital', 'provider', 'layanan'],
          accept: (v) => v.isNotEmpty);
      if (pHit != null) r.ewalletProvider = pHit.value.trim().toUpperCase();
    }

    final name = doc.find(const [
      'nama penerima', 'nama tujuan', 'nama akun', 'detail penerima', 'penerima',
      'nama', 'kepada', 'untuk',
    ], accept: _looksLikeName);
    if (name != null) r.ewalletName = _firstName([name.value]) ?? '';

    final numHit = doc.find(const [
      'no. hp penerima', 'nomor hp penerima', 'no hp penerima', 'nomor hp', 'no. hp',
      'nomor ponsel', 'no. ponsel', 'nomor tujuan', 'no. tujuan', 'nomor akun',
      'no. akun', 'nomor', 'no.',
    ], accept: (v) => RegExp(r'\d{9,}').hasMatch(v.replaceAll(RegExp(r'[\s-]'), '')));
    if (numHit != null) {
      final digits = numHit.value.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 9) r.ewalletNumber = digits;
    }
    if (r.ewalletNumber.isEmpty) {
      for (final row in doc.rows) {
        final m = RegExp(r'(?<!\d)(08\d{8,11})(?!\d)').firstMatch(row.replaceAll(RegExp(r'[\s-]'), ''));
        if (m != null) {
          r.ewalletNumber = m.group(1)!;
          break;
        }
      }
    }

    r.amount = _findAmount(doc, const [
      'nominal top up', 'jumlah top up', 'nominal', 'jumlah', 'total bayar',
      'total pembayaran', 'total', 'harga',
    ], secondary: const ['total']);

    r.customerId = r.ewalletNumber;
    r.customerName = r.ewalletName;
    r.category = r.ewalletProvider.isNotEmpty ? 'TOP UP ${r.ewalletProvider}' : 'TOP UP E-WALLET';
  }

  // ---------------------------------------------------------------- tagihan

  static const _detailLabels = [
    'stand meter', 'jumlah peserta', 'jml peserta', 'jumlah bulan', 'jml bulan', 'jml bln',
    'lembar', 'tarif/daya', 'tarif', 'daya', 'golongan', 'denda', 'jatuh tempo', 'produk',
    'nama produk', 'paket', 'no. polisi', 'kode bayar', 'serial number', 'sn', 'no. seri',
  ];

  static void _parseBill(_Doc doc, Receipt r) {
    r.category = guessCategory(doc.rows.join('\n'));
    final idHit = doc.find(const [
      'id pelanggan', 'idpel', 'id pel', 'no. pelanggan', 'nomor pelanggan', 'no pelanggan',
      'nomor va', 'no. va', 'no va', 'no. peserta', 'nomor peserta', 'no. kontrak',
      'nomor kontrak', 'nomor hp', 'no. hp', 'nomor ponsel', 'no. telepon', 'nomor telepon',
      'nomor tujuan', 'no. tujuan', 'customer id', 'nomor', 'no.',
    ], accept: (v) => RegExp(r'\d{5,}').hasMatch(v.replaceAll(RegExp(r'[\s-]'), '')));
    if (idHit != null) {
      r.customerId = RegExp(r'\d{5,}')
          .firstMatch(idHit.value.replaceAll(RegExp(r'[\s-]'), ''))!
          .group(0)!;
    }
    final name = doc.find(const ['nama pelanggan', 'nama peserta', 'nama'], accept: _looksLikeName);
    if (name != null) r.customerName = _firstName([name.value]) ?? '';
    final period = doc.find(const [
      'periode', 'bulan/tahun', 'bln/thn', 'bl/th', 'bulan', 'period',
    ], accept: (v) => v.trim().isNotEmpty);
    if (period != null) r.period = period.value.trim();
    final used = <String>{};
    for (final label in _detailLabels) {
      final h = doc.find([label], accept: (v) => v.trim().isNotEmpty);
      if (h == null) continue;
      final key = label.toUpperCase();
      if (used.contains(key) || used.contains(h.value)) continue;
      used
        ..add(key)
        ..add(h.value);
      r.details.add(DetailRow(label: key, value: h.value.trim()));
      if (r.details.length >= 6) break;
    }
    r.amount = _findAmount(doc, const [
      'total tagihan', 'jumlah tagihan', 'tagihan', 'nominal', 'harga',
    ], secondary: const ['total bayar', 'total pembayaran', 'total', 'jumlah']);
  }

  static String guessCategory(String text) {
    final t = text.toLowerCase();
    const map = <String, String>{
      r'bpjs\s*ketenagakerjaan|bpjstk': 'BPJS KETENAGAKERJAAN',
      r'bpjs': 'BPJS KESEHATAN',
      r'pdam|air minum|perumda': 'PDAM',
      r'pascabayar|pasca bayar|tagihan listrik': 'PLN PASCABAYAR',
      r'paket data|kuota internet': 'PAKET DATA',
      r'pulsa': 'PULSA',
      r'indihome|telkom(?!sel)': 'TELKOM/INDIHOME',
      r'\bpbb\b': 'PBB',
      r'angsuran|cicilan|multifinance|leasing|finance': 'ANGSURAN',
      r'\bpgn\b|gas negara': 'GAS PGN',
      r'e-?money|top ?up|gopay|ovo|dana|shopeepay': 'TOP UP E-WALLET',
      r'tv kabel|indovision|transvision|k-?vision': 'TV BERLANGGANAN',
    };
    for (final e in map.entries) {
      if (RegExp(e.key).hasMatch(t)) return e.value;
    }
    return 'TAGIHAN';
  }

  // ---------------------------------------------------------------- helper umum

  static String? _findRef(_Doc doc) {
    final hit = doc.find(const [
      'no. referensi', 'nomor referensi', 'no referensi', 'no. ref', 'ref no', 'ref. no',
      'reference number', 'reference no', 'referensi', 'reference', 'id transaksi',
      'no. transaksi', 'nomor transaksi', 'kode transaksi', 'transaction id', 'id transfer',
      'trx id', 'order id', 'no. resi', 'ref',
    ], accept: (v) => _refToken(v) != null);
    return hit == null ? null : _refToken(hit.value);
  }

  static String? _refToken(String v) {
    final chunks = <String>[];
    for (final c in v.trim().split(RegExp(r'\s{2,}')).first.split(' ')) {
      if (!RegExp(r'^[A-Z0-9\-/]+$').hasMatch(c)) break;
      chunks.add(c);
    }
    final joined = chunks.join();
    if (joined.length >= 6 && RegExp(r'\d').hasMatch(joined) && !_looksLikeDateTime(chunks)) {
      return joined;
    }
    final tokens = RegExp(r'[A-Za-z0-9][A-Za-z0-9\-/]{5,}')
        .allMatches(v)
        .map((m) => m.group(0)!)
        .where((s) => RegExp(r'\d').hasMatch(s))
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return tokens.isEmpty ? null : tokens.first;
  }

  static bool _looksLikeDateTime(List<String> chunks) =>
      chunks.any((c) => RegExp(r'^\d{1,2}[:./-]\d{1,2}').hasMatch(c));

  static const _amountExclude = [
    'biaya', 'admin', 'fee', 'saldo', 'diskon', 'cashback', 'poin', 'point', 'limit',
  ];

  static int _findAmount(_Doc doc, List<String> labels,
      {List<String> secondary = const [],
      List<String> extraExclude = const [],
      bool preferLargest = false}) {
    final exclude = [..._amountExclude, ...extraExclude];
    final hit = doc.find(labels, accept: (v) => parseAmount(v) != null, exclude: exclude);
    if (hit != null) return parseAmount(hit.value)!;
    final fallback = _anyAmount(doc, exclude, preferLargest);
    if (fallback > 0) return fallback;
    final hit2 = doc.find(secondary, accept: (v) => parseAmount(v) != null, exclude: exclude);
    return hit2 == null ? 0 : parseAmount(hit2.value)!;
  }

  static int _anyAmount(_Doc doc, List<String> exclude, bool preferLargest) {
    final candidates = <int>[];
    for (final row in doc.rows) {
      final low = row.toLowerCase();
      if (exclude.any(low.contains)) continue;
      final a = parseAmount(row, requireCurrency: true);
      if (a != null && a > 0) candidates.add(a);
    }
    if (candidates.isEmpty) {
      for (final row in doc.rows) {
        final low = row.toLowerCase();
        if (exclude.any(low.contains)) continue;
        final a = parseAmount(row);
        if (a != null && a > 0) candidates.add(a);
      }
    }
    if (candidates.isEmpty) return 0;
    if (preferLargest) return candidates.reduce((a, b) => a > b ? a : b);
    return candidates.first;
  }

  static int? parseAmount(String s, {bool requireCurrency = false}) {
    final cur = RegExp(r'(?:rp|idr)\s*\.?\s*-?\s*(\d[\d.,]*\d|\d)', caseSensitive: false)
        .firstMatch(s);
    String? raw = cur?.group(1);
    if (raw == null && !requireCurrency) {
      raw = RegExp(r'(?<![\d.,])(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?)(?![\d.,])')
          .firstMatch(s)
          ?.group(1);
    }
    if (raw == null) return null;
    var n = raw;
    final dec = RegExp(r'[.,](\d{1,2})$').firstMatch(n);
    if (dec != null) n = n.substring(0, dec.start);
    final d = n.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.isEmpty || d.length > 13) return null;
    return int.parse(d);
  }

  static const _months = {
    'jan': 1, 'feb': 2, 'peb': 2, 'mar': 3, 'apr': 4, 'mei': 5, 'may': 5, 'jun': 6, 'jul': 7,
    'agu': 8, 'agt': 8, 'ags': 8, 'aug': 8, 'sep': 9, 'okt': 10, 'oct': 10, 'nov': 11,
    'nop': 11, 'des': 12, 'dec': 12,
  };

  static String? findDate(List<String> rows) {
    final monthAlt = _months.keys.join('|');
    final reText = RegExp(
        r'(?<!\d)(\d{1,2})\s*[-/ ]?\s*(' + monthAlt + r')[a-z]*\.?\s*[-/ ,]?\s*(\d{4}|\d{2})(?!\d)',
        caseSensitive: false);
    final reNum = RegExp(r'(?<![\d.,])(\d{1,2})([/.-])(\d{1,2})\2(\d{4}|\d{2})(?![\d.,])');
    final reIso = RegExp(r'(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)');
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      int? d, m, y;
      final a = reText.firstMatch(row);
      if (a != null) {
        d = int.parse(a.group(1)!);
        m = _months[a.group(2)!.toLowerCase().substring(0, 3)];
        y = int.parse(a.group(3)!);
      } else {
        final b = reIso.firstMatch(row);
        if (b != null) {
          y = int.parse(b.group(1)!);
          m = int.parse(b.group(2)!);
          d = int.parse(b.group(3)!);
        } else {
          final c = reNum.firstMatch(row);
          if (c != null && !(c.group(2) == '.' && c.group(4)!.length != 4)) {
            d = int.parse(c.group(1)!);
            m = int.parse(c.group(3)!);
            y = int.parse(c.group(4)!);
          }
        }
      }
      if (d == null || m == null || y == null) continue;
      if (y < 100) y += 2000;
      if (d < 1 || d > 31 || m < 1 || m > 12 || y < 2000 || y > 2100) continue;
      final time = findTime(row) ?? (i + 1 < rows.length ? findTime(rows[i + 1]) : null) ??
          (i > 0 ? findTime(rows[i - 1]) : null);
      final date = '${d.toString().padLeft(2, '0')}/${m.toString().padLeft(2, '0')}/$y';
      return time == null ? date : '$date $time';
    }
    return null;
  }

  static String? findTime(String row) {
    final colon = RegExp(r'(?<!\d)([01]?\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?(?!\d)').firstMatch(row);
    final dotted = RegExp(r'(?<![\d.,])([01]?\d|2[0-3])\.([0-5]\d)(?:\.([0-5]\d))?\s*(wib|wita|wit)\b',
            caseSensitive: false)
        .firstMatch(row);
    final m = colon ?? dotted;
    if (m == null) return null;
    final base = '${m.group(1)!.padLeft(2, '0')}:${m.group(2)}${m.group(3) == null ? '' : ':${m.group(3)}'}';
    final zone = RegExp(r'\b(WIB|WITA|WIT)\b', caseSensitive: false).firstMatch(row);
    return zone == null ? base : '$base ${zone.group(1)!.toUpperCase()}';
  }

  static String? findToken(List<String> rows) {
    final re = RegExp(r'(?<!\d)(\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4})(?!\d)');
    for (final row in rows) {
      final m = re.firstMatch(row);
      if (m != null) return formatToken(m.group(1)!);
    }
    return null;
  }

  static const _banks = <String, String>{
    r'(\b|my|klik)bca\b': 'BCA',
    r'\bbri(mo)?\b': 'BRI',
    r'\bbni\b|wondr': 'BNI',
    r'mandiri|livin': 'MANDIRI',
    r'\bbsi\b|syariah indonesia': 'BSI',
    r'\bbtn\b': 'BTN',
    r'cimb': 'CIMB NIAGA',
    r'permata': 'PERMATA',
    r'danamon': 'DANAMON',
    r'ocbc': 'OCBC',
    r'\bpanin': 'PANIN',
    r'maybank': 'MAYBANK',
    r'bank mega|\bmega\b': 'BANK MEGA',
    r'sinarmas': 'SINARMAS',
    r'\bjago\b': 'BANK JAGO',
    r'sea ?bank': 'SEABANK',
    r'\bblu\b': 'BLU BCA DIGITAL',
    r'jenius': 'JENIUS',
    r'neo ?commerce|bank neo': 'BANK NEO',
    r'allo ?bank': 'ALLO BANK',
    r'line ?bank': 'LINE BANK',
    r'muamalat': 'MUAMALAT',
    r'\bbjb\b': 'BJB',
    r'bank jatim': 'BANK JATIM',
    r'bank jateng': 'BANK JATENG',
    r'bank dki': 'BANK DKI',
    r'bank kalbar': 'BANK KALBAR',
    r'bank nagari': 'BANK NAGARI',
    r'bank sumut': 'BANK SUMUT',
    r'\bbpd\b': 'BPD',
    r'\bdana\b': 'DANA',
    r'\bovo\b': 'OVO',
    r'go-?pay': 'GOPAY',
    r'shopee ?pay': 'SHOPEEPAY',
    r'link ?aja': 'LINKAJA',
  };

  static String? findBank(String s) {
    final t = s.toLowerCase().replaceAll(RegExp(r'sumber dana|jumlah dana|dana masuk|dana keluar'), ' ');
    for (final e in _banks.entries) {
      if (RegExp(e.key).hasMatch(t)) return e.value;
    }
    return null;
  }

  static String? findAccount(String s) {
    final masked = RegExp(r'[*xXâ€¢Â·]{2,}[\s-]*\d{2,6}').firstMatch(s);
    final plain = RegExp(r'(?<![\d.,:/])(\d[\d -]{4,22}\d)(?![\d.,:/])').allMatches(s);
    for (final m in plain) {
      final digits = m.group(1)!.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 6 && digits.length <= 18) return digits;
    }
    if (masked != null) return masked.group(0)!.replaceAll(' ', '');
    return null;
  }

  static String? _firstName(List<String> values) {
    for (final v in values) {
      for (final part in v.split(RegExp(r'\s{2,}| - |\|'))) {
        final p = _stripSubLabel(part);
        if (_looksLikeName(p)) return _cleanName(p);
      }
    }
    return null;
  }

  static String? _firstAccount(List<String> values) {
    for (final v in values) {
      final a = findAccount(v);
      if (a != null) return a;
    }
    return null;
  }

  static String? _firstBank(List<String> values) {
    for (final v in values) {
      final b = findBank(v);
      if (b != null) return b;
    }
    return null;
  }

  static final _subLabel = RegExp(
      r'^\s*(nama( penerima| pengirim| tujuan)?|bank( tujuan| penerima)?|no\.?\s*(rek(ening)?|akun)|nomor( rekening| akun)?|rekening|akun)\s*[:ï¼š]?\s*',
      caseSensitive: false);

  static String _stripSubLabel(String s) => s.replaceFirst(_subLabel, '').trim();

  static const _nonNameWords = [
    'berhasil', 'sukses', 'transfer', 'rekening', 'detail', 'transaksi', 'nominal', 'total',
    'tanggal', 'waktu', 'status', 'bank', 'biaya', 'jumlah', 'referensi', 'penerima', 'pengirim',
    'tujuan', 'sumber', 'bukti', 'keterangan', 'berita', 'catatan', 'saldo', 'metode', 'virtual',
    'pembayaran', 'tagihan', 'token', 'kwh', 'daya', 'tarif', 'periode', 'dibagikan', 'share',
  ];

  static bool _looksLikeName(String v) {
    final s = v.trim();
    if (s.length < 3 || s.length > 45) return false;
    final letters = RegExp(r'[A-Za-z]').allMatches(s).length;
    final digits = RegExp(r'\d').allMatches(s).length;
    if (letters < 3 || digits > 2) return false;
    final low = s.toLowerCase();
    if (low.contains('rp') && RegExp(r'rp\s*\d').hasMatch(low)) return false;
    if (_nonNameWords.any((w) => RegExp(r'\b$w\b').hasMatch(low))) return false;
    if (findBank(s) != null && s.split(RegExp(r'\s+')).length <= 2) return false;
    return true;
  }

  static String _cleanName(String s) {
    var v = s.split(RegExp(r'\s{2,}')).first;
    v = v.replaceAll(RegExp(r'^[\s:ï¼š\-.,]+|[\s:ï¼š\-.,]+$'), '');
    return v.trim().toUpperCase();
  }

  static bool _isMetaRow(String row) {
    final l = row.toLowerCase();
    return RegExp(r'ref|transaksi|tanggal|waktu|jam|rp|idr|biaya|admin|saldo|kode').hasMatch(l);
  }
}

class _Hit {
  final String value;
  final int row;
  final int labelRow;
  final String inline;
  _Hit(this.value, this.row, this.labelRow, this.inline);
}

class _Window {
  final List<String> values;
  final Set<int> rows;
  _Window(this.values, this.rows);
}

class _Doc {
  final List<String> rows;
  _Doc(this.rows);
  static final Map<String, RegExp> _cache = {};
  static RegExp _labelRe(String label) => _cache.putIfAbsent(label, () {
        var p = RegExp.escape(label);
        p = p.replaceAll(r'\.', r'\.?').replaceAll(' ', r'\s*').replaceAll('/', r'\s*/\s*');
        return RegExp(r'^\s*' + p + r'(?![a-z0-9])\s*[:ï¼š=]?\s*(.*)$', caseSensitive: false);
      });
  _Hit? find(List<String> labels,
      {required bool Function(String) accept,
      Set<int> skipRows = const {},
      List<String> exclude = const []}) {
    for (final label in labels) {
      final re = _labelRe(label);
      for (var i = 0; i < rows.length; i++) {
        if (skipRows.contains(i)) continue;
        final m = re.firstMatch(rows[i]);
        if (m == null) continue;
        final low = rows[i].toLowerCase();
        if (exclude.any((e) => low.contains(e))) continue;
        final inline = m.group(1)!.replaceFirst(RegExp(r'^[:ï¼š\-=]+\s*'), '').trim();
        if (inline.isNotEmpty && accept(inline)) return _Hit(inline, i, i, inline);
        if (inline.isEmpty && i + 1 < rows.length && !skipRows.contains(i + 1)) {
          final next = rows[i + 1].trim();
          final nextLow = next.toLowerCase();
          if (!exclude.any((e) => nextLow.contains(e)) && accept(next)) return _Hit(next, i + 1, i, '');
        }
      }
    }
    return null;
  }
  _Window window(int row, String inline, int count, List<String> stopLabels) {
    final values = <String>[];
    final used = <int>{row};
    if (inline.isNotEmpty) values.add(inline);
    for (var i = row + 1; i < rows.length && i <= row + count; i++) {
      if (stopLabels.any((l) => _labelRe(l).hasMatch(rows[i]))) break;
      values.add(rows[i]);
      used.add(i);
    }
    return _Window(values, used);
  }
}