import '../models/app_settings.dart';
import '../models/receipt.dart';
import '../utils/format.dart';

enum RSize { normal, tall, big }

class RSeg {
  final String text;
  final String? key;
  const RSeg(this.text, [this.key]);
}

class RLine {
  final List<RSeg> segs;
  final bool bold;
  final RSize size;
  RLine(String text, {this.bold = false, bool big = false})
      : segs = [RSeg(text)],
        size = big ? RSize.tall : RSize.normal;
  const RLine.segs(this.segs, {this.bold = false, this.size = RSize.normal});
  String get text => segs.map((s) => s.text).join();
}

class _F {
  final String label;
  final String value;
  final String key;
  final bool optional;
  const _F(this.label, this.value, this.key, {this.optional = false});
  bool get skip => optional && ReceiptLayout.clean(value).isEmpty;
}

class ReceiptLayout {
  ReceiptLayout._();
  static const templateNames = ['Standard', 'Minimalis', 'Modern', 'Bank Style', 'Compact'];

  static List<RLine> build(Receipt r, AppSettings s) {
    final b = _B(s.charsPerLine);
    switch (r.template.clamp(0, templateNames.length - 1)) {
      case 0:
        _standard(b, r, s);
      case 1:
        _minimalis(b, r, s);
      case 2:
        _modern(b, r, s);
      case 3:
        _bankStyle(b, r, s);
      case 4:
        _compact(b, r, s);
    }
    return b.lines;
  }

  static String _docTitle(Receipt r) => switch (r.type) {
        ReceiptType.trf => 'BUKTI TRANSFER',
        ReceiptType.ewallet => 'TOP UP E-WALLET',
        ReceiptType.tagihan => 'PEMBAYARAN TAGIHAN',
      };

  static String _sectionTitle(Receipt r) => switch (r.type) {
        ReceiptType.trf => 'DATA PENERIMA',
        ReceiptType.ewallet => 'DATA PENERIMA E-WALLET',
        ReceiptType.tagihan => 'DATA TAGIHAN',
      };

  static String _modernHeading(Receipt r) => switch (r.type) {
        ReceiptType.trf => 'KEPADA:',
        ReceiptType.ewallet => 'E-WALLET:',
        ReceiptType.tagihan => 'TAGIHAN:',
      };

  static String _transactionName(Receipt r) => switch (r.type) {
        ReceiptType.trf => 'TRANSFER BANK',
        ReceiptType.ewallet => r.ewalletProvider.isNotEmpty
            ? 'TOP UP ${r.ewalletProvider}'
            : 'TOP UP E-WALLET',
        ReceiptType.tagihan => r.category.trim().isEmpty ? 'PEMBAYARAN TAGIHAN' : r.category,
      };

  static String _amountLabel(Receipt r) => switch (r.type) {
        ReceiptType.trf => 'NOMINAL',
        ReceiptType.ewallet => 'NOMINAL',
        ReceiptType.tagihan => 'TAGIHAN',
      };

  static List<_F> _fields(Receipt r) => switch (r.type) {
        ReceiptType.trf => [
            _F('BANK TUJUAN', r.recipientBank, 'recipientBank'),
            _F('NO REKENING', r.recipientNumber, 'recipientNumber'),
            _F('PENERIMA', r.recipientName, 'recipientName'),
            _F('BERITA', r.note, 'note', optional: true),
          ],
        ReceiptType.ewallet => [
            _F('E-WALLET', r.ewalletProvider, 'ewalletProvider'),
            _F('NAMA PENERIMA', r.ewalletName, 'ewalletName'),
            _F('NO. HP', r.ewalletNumber, 'ewalletNumber'),
          ],
        ReceiptType.tagihan => [
            _F('LAYANAN', r.category, 'category'),
            _F('ID PEL', r.customerId, 'customerId'),
            _F('NAMA', r.customerName, 'customerName'),
            _F('PERIODE', r.period, 'period', optional: true),
            for (var i = 0; i < r.details.length; i++)
              _F(r.details[i].label, r.details[i].value, 'detail:$i', optional: true),
          ],
      };

  static bool _hasSender(Receipt r, AppSettings s) =>
      r.type == ReceiptType.trf && s.showSender && r.senderName.trim().isNotEmpty;

  static List<_F> _senderFields(Receipt r) => [
        _F('PENGIRIM', r.senderName, 'senderName'),
        _F('BANK ASAL', r.senderBank, 'senderBank', optional: true),
        _F('REK ASAL', r.senderNumber, 'senderNumber', optional: true),
      ];

  static void _header(_B b, AppSettings s) {
    b.center(s.storeName, key: 'store', bold: true);
    for (final line in s.address.split('\n')) {
      if (line.trim().isNotEmpty) b.center(line, key: 'address');
    }
  }

  static void _footer(_B b, AppSettings s) {
    b.sep('-');
    b.center('** TRANSAKSI BERHASIL **', bold: true);
    b.center('SALINAN BUKTI TRANSAKSI');
    _footerText(b, s, bold: true);
    if (s.terminalId.trim().isNotEmpty) b.center('TID: ${s.terminalId}');
  }

  static void _footerText(_B b, AppSettings s, {bool bold = false}) {
    for (final line in s.footer.split('\n')) {
      if (line.trim().isNotEmpty) b.center(line, key: 'footer', bold: bold);
    }
  }

  static void _token(_B b, Receipt r, {bool label = true}) {
    return;
  }

  static void _standard(_B b, Receipt r, AppSettings s) {
    _header(b, s);
    b.sep('=');
    b.lr('TANGGAL', r.date, key: 'date');
    b.lr('WAKTU', r.time, key: 'time');
    b.sep('-');
    b.center('KODE REFERENSI');
    b.center(r.ref, key: 'ref', bold: true);
    b.sep('-');
    if (_hasSender(r, s)) {
      b.center('DATA PENGIRIM', bold: true);
      for (final f in _senderFields(r)) {
        if (!f.skip) b.lr(f.label, f.value, key: f.key);
      }
      b.sep('-');
    }
    b.center(_sectionTitle(r), bold: true);
    for (final f in _fields(r)) {
      if (!f.skip) b.lr(f.label, f.value, key: f.key);
    }
    b.sep('-');
    b.lr(_amountLabel(r), rupiah(r.amount), key: 'amount');
    b.lr('ADMIN', rupiah(r.admin), key: 'admin');
    b.sep('=');
    b.lr('TOTAL', rupiah(r.total), bold: true);
    b.sep('=');
    b.blank();
    _footer(b, s);
  }

  static void _minimalis(_B b, Receipt r, AppSettings s) {
    _header(b, s);
    b.blank();
    b.centerSegs([RSeg(r.date, 'date'), const RSeg(' '), RSeg(r.time, 'time')]);
    b.blank();
    switch (r.type) {
      case ReceiptType.trf:
        b.left('PENERIMA:');
        b.left(r.recipientName, key: 'recipientName', bold: true);
        b.segsLine([RSeg(r.recipientBank, 'recipientBank'), const RSeg(' '),
          RSeg(r.recipientNumber, 'recipientNumber')]);
        if (r.note.trim().isNotEmpty) b.left(r.note, key: 'note');
      case ReceiptType.ewallet:
        b.left('E-WALLET:');
        b.left(r.ewalletProvider, key: 'ewalletProvider', bold: true);
        b.left(r.ewalletName, key: 'ewalletName', bold: true);
        b.segsLine([RSeg(r.ewalletNumber, 'ewalletNumber')]);
        b.blank();
      case ReceiptType.tagihan:
        b.left(r.category, key: 'category', bold: true);
        b.segsLine([RSeg(r.customerId, 'customerId'), const RSeg(' - '),
          RSeg(r.customerName, 'customerName')]);
        if (r.period.trim().isNotEmpty) {
          b.segsLine([const RSeg('PERIODE '), RSeg(r.period, 'period')]);
        }
    }
    b.blank();
    b.lr(_amountLabel(r), rupiah(r.amount), key: 'amount');
    b.lr('ADMIN', rupiah(r.admin), key: 'admin');
    b.sep('-');
    b.lr('TOTAL', rupiah(r.total), bold: true);
    b.blank();
    _footer(b, s);
  }

  static void _modern(_B b, Receipt r, AppSettings s) {
    _header(b, s);
    b.blank();
    b.sep('=');
    b.center(_docTitle(r), bold: true);
    b.sep('=');
    b.lr('TANGGAL', r.date, key: 'date');
    b.lr('WAKTU', r.time, key: 'time');
    b.lr('REF', r.ref, key: 'ref');
    b.blank();
    if (_hasSender(r, s)) {
      b.left('DARI:');
      for (final f in _senderFields(r)) {
        if (!f.skip) b.lr(f.label, f.value, key: f.key);
      }
      b.blank();
    }
    b.left(_modernHeading(r));
    final fields = r.type == ReceiptType.trf
        ? [
            _F('PENERIMA', r.recipientName, 'recipientName'),
            _F('BANK', r.recipientBank, 'recipientBank'),
            _F('NO REKENING', r.recipientNumber, 'recipientNumber'),
            _F('BERITA', r.note, 'note', optional: true),
          ]
        : _fields(r);
    for (final f in fields) {
      if (!f.skip) b.lr(f.label, f.value, key: f.key);
    }
    b.blank();
    b.center('TOTAL BAYAR', bold: true);
    b.center(rupiah(r.total), bold: true, size: RSize.big);
    b.blank();
    _footer(b, s);
  }

  static void _bankStyle(_B b, Receipt r, AppSettings s) {
    final lw = b.width >= 48 ? 14 : 12;
    _header(b, s);
    b.blank();
    b.center('BUKTI TRANSAKSI', bold: true);
    b.segsLine([RSeg(r.date, 'date'), const RSeg(' '), RSeg(r.time, 'time')]);
    if (s.terminalId.trim().isNotEmpty) b.kv('TID TERMINAL', s.terminalId, lw: lw);
    b.kv('NO REF', r.ref, key: 'ref', lw: lw);
    b.blank();
    b.kv('TRANSAKSI', _transactionName(r),
        key: r.type == ReceiptType.tagihan ? 'category' : null, lw: lw);
    if (_hasSender(r, s)) {
      for (final f in _senderFields(r)) {
        if (!f.skip) b.kv(f.label, f.value, key: f.key, lw: lw);
      }
    }
    for (final f in _fields(r)) {
      if (f.skip || (r.type == ReceiptType.tagihan && f.key == 'category')) continue;
      b.kv(f.label, f.value, key: f.key, lw: lw);
    }
    b.kv('JUMLAH', rupiah(r.amount), key: 'amount', lw: lw);
    b.kv('BIAYA ADMIN', rupiah(r.admin), key: 'admin', lw: lw);
    b.kv('TOTAL', rupiah(r.total), lw: lw, bold: true);
    b.kv('STATUS', 'SUKSES', lw: lw);
    b.blank();
    _footerText(b, s);
    b.blank();
    b.center('SALINAN BUKTI TRANSAKSI');
  }

  static void _compact(_B b, Receipt r, AppSettings s) {
    const lw = 8;
    _header(b, s);
    b.sep('-');
    b.lr('TGL', r.date, key: 'date');
    b.sep('-');
    switch (r.type) {
      case ReceiptType.trf:
        b.kvSegs('TUJUAN', [RSeg(r.recipientBank, 'recipientBank'), const RSeg(' - '),
          RSeg(r.recipientNumber, 'recipientNumber')], lw: lw);
        b.kv('PENERIMA', r.recipientName, key: 'recipientName', lw: lw);
      case ReceiptType.ewallet:
        b.kv('E-WALLET', r.ewalletProvider, key: 'ewalletProvider', lw: lw);
        b.kv('NAMA', r.ewalletName, key: 'ewalletName', lw: lw);
        b.kv('NO. HP', r.ewalletNumber, key: 'ewalletNumber', lw: lw);
      case ReceiptType.tagihan:
        b.kv('LAYANAN', r.category, key: 'category', lw: lw);
        b.kv('ID PEL', r.customerId, key: 'customerId', lw: lw);
        b.kv('NAMA', r.customerName, key: 'customerName', lw: lw);
    }
    b.lr(_amountLabel(r), rupiah(r.amount), key: 'amount');
    if (r.admin != 0) b.lr('ADMIN', rupiah(r.admin), key: 'admin');
    b.sep('-');
    b.lr('TOTAL', rupiah(r.total), bold: true);
    b.segsLine([const RSeg('REF: '), RSeg(r.ref, 'ref')]);
    b.sep('-');
    b.blank();
    _footer(b, s);
  }

  static String clean(String v) {
    const fold = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'é': 'e', 'è': 'e', 'ê': 'e',
      'ë': 'e', 'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o',
      'õ': 'o', 'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c', 'ñ': 'n', '•': '-', '–': '-',
      '—': '-', '’': "'", '‘': "'", '“': '"', '”': '"',
    };
    final buf = StringBuffer();
    for (final ch in v.toLowerCase().split('')) {
      buf.write(fold[ch] ?? ch);
    }
    return buf
        .toString()
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toUpperCase();
  }
}

class _B {
  final int width;
  final List<RLine> lines = [];
  _B(this.width);
  static String v(String s) {
    final c = ReceiptLayout.clean(s);
    return c.isEmpty ? '-' : c;
  }
  List<String> wrap(String text, int w) {
    final out = <String>[];
    var cur = '';
    for (var word in text.split(' ').where((e) => e.isNotEmpty)) {
      while (word.length > w) {
        if (cur.isNotEmpty) { out.add(cur); cur = ''; }
        out.add(word.substring(0, w));
        word = word.substring(w);
      }
      if (cur.isEmpty) { cur = word; }
      else if (cur.length + 1 + word.length <= w) { cur = '$cur $word'; }
      else { out.add(cur); cur = word; }
    }
    if (cur.isNotEmpty) out.add(cur);
    return out;
  }
  void blank() => lines.add(RLine(''));
  void sep(String ch) => lines.add(RLine(ch * width));
  void center(String text, {String? key, bool bold = false, RSize size = RSize.normal}) {
    final cw = size == RSize.big ? width ~/ 2 : width;
    final t = key == null ? ReceiptLayout.clean(text) : v(text);
    for (final l in wrap(t, cw)) {
      final pad = (cw - l.length) ~/ 2;
      lines.add(RLine.segs([RSeg(' ' * pad), RSeg(l, key)], bold: bold, size: size));
    }
  }
  void left(String text, {String? key, bool bold = false}) {
    final t = key == null ? ReceiptLayout.clean(text) : v(text);
    for (final l in wrap(t, width)) {
      lines.add(RLine.segs([RSeg(l, key)], bold: bold));
    }
  }
  List<RSeg> _cleanSegs(List<RSeg> segs) => [
        for (final s in segs) RSeg(s.key == null ? s.text.toUpperCase() : v(s.text), s.key),
      ];
  int _len(List<RSeg> segs) => segs.fold(0, (n, s) => n + s.text.length);
  void segsLine(List<RSeg> segs, {bool bold = false}) {
    final c = _cleanSegs(segs);
    if (_len(c) <= width) { lines.add(RLine.segs(c, bold: bold)); }
    else { for (final s in c) { if (s.key != null) left(s.text, key: s.key, bold: bold); } }
  }
  void centerSegs(List<RSeg> segs, {bool bold = false}) {
    final c = _cleanSegs(segs);
    final len = _len(c);
    if (len > width) { segsLine(segs, bold: bold); return; }
    lines.add(RLine.segs([RSeg(' ' * ((width - len) ~/ 2)), ...c], bold: bold));
  }
  void lr(String label, String value, {String? key, bool bold = false}) {
    final l = ReceiptLayout.clean(label);
    final val = v(value);
    if (l.length + val.length + 1 <= width) {
      lines.add(RLine.segs([RSeg(l + ' ' * (width - l.length - val.length)), RSeg(val, key)], bold: bold));
    } else {
      lines.add(RLine(l, bold: bold));
      for (final part in wrap(val, width)) {
        lines.add(RLine.segs([RSeg(' ' * (width - part.length)), RSeg(part, key)], bold: bold));
      }
    }
  }
  void kv(String label, String value, {String? key, int lw = 10, bool bold = false}) {
    final l = ReceiptLayout.clean(label);
    final k = l.length > lw ? l.substring(0, lw) : l.padRight(lw);
    final parts = wrap(v(value), width - lw - 2);
    for (var i = 0; i < parts.length; i++) {
      lines.add(RLine.segs([
        RSeg(i == 0 ? '$k: ' : ' ' * (lw + 2)),
        RSeg(parts[i], key),
      ], bold: bold));
    }
  }
  void kvSegs(String label, List<RSeg> segs, {int lw = 10}) {
    final c = _cleanSegs(segs);
    if (_len(c) <= width - lw - 2) {
      final l = ReceiptLayout.clean(label);
      final k = l.length > lw ? l.substring(0, lw) : l.padRight(lw);
      lines.add(RLine.segs([RSeg('$k: '), ...c]));
    } else {
      var first = true;
      for (final s in c) {
        if (s.key == null) continue;
        kv(first ? label : '', s.text, key: s.key, lw: lw);
        first = false;
      }
    }
  }
}