import 'package:cetak_struk/models/app_settings.dart';
import 'package:cetak_struk/models/receipt.dart';
import 'package:cetak_struk/services/receipt_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Receipt sample(ReceiptType t, int template) => Receipt.empty(t)
    ..template = template
    ..date = '13/10/2026'
    ..time = '16:46:00'
    ..ref = '9527120261013164619'
    ..amount = 1500000
    ..admin = 5000
    ..note = 'Pembayaran cicilan motor bulan oktober yang sangat panjang sekali'
    ..recipientName = 'ROSHA FIRMANSYAH'
    ..recipientBank = 'BCA'
    ..recipientNumber = '2312750229'
    ..senderName = 'JOKO WIDODO'
    ..senderBank = 'BRI'
    ..senderNumber = '0123456789'
    ..customerId = '512345678901'
    ..customerName = 'SUPRIYADI'
    ..tariff = 'R1/900VA'
    ..kwh = '63,5'
    ..token = '55123456789012345678'
    ..category = 'BPJS KESEHATAN'
    ..period = 'OKT 2026'
    ..details = [DetailRow(label: 'Jumlah Peserta', value: '3 orang')];

  AppSettings settings(int width) => AppSettings(
        paperWidth: width,
        storeName: 'Toko Sumber Rejeki Makmur Jaya Abadi Sentosa',
        address: 'Jl. Merdeka No. 10\nWA 0812-3456-7890',
        footer: 'Terima kasih\nSimpan struk ini',
        showSender: true,
        terminalId: 'C5DBBC',
      );

  for (final width in [58, 80]) {
    for (var tpl = 0; tpl < ReceiptLayout.templateNames.length; tpl++) {
      for (final t in ReceiptType.values) {
        test('${ReceiptLayout.templateNames[tpl]} / ${t.name} / $width mm muat di kertas', () {
          final s = settings(width);
          final lines = ReceiptLayout.build(sample(t, tpl), s);
          expect(lines, isNotEmpty);
          for (final l in lines) {
            final max = l.size == RSize.big ? s.charsPerLine ~/ 2 : s.charsPerLine;
            expect(l.text.length, lessThanOrEqualTo(max), reason: '"${l.text}"');
            expect(RegExp(r'^[\x20-\x7E]*$').hasMatch(l.text), isTrue);
          }
          final text = lines.map((l) => l.text).join('\n');
          expect(text, contains('RP 1.505.000'));
          expect(text, contains('13/10/2026'));
          if (t == ReceiptType.pln) expect(text, contains('5512 3456 7890 1234 5678'));
          // Field yang bisa diedit punya key.
          final keys = {for (final l in lines) for (final sg in l.segs) ?sg.key};
          expect(keys, containsAll(['store', 'date']));
          if (t == ReceiptType.trf) expect(keys, containsAll(['recipientName', 'recipientBank']));
          if (t == ReceiptType.pln) expect(keys, containsAll(['token', 'customerId']));
          if (t == ReceiptType.tagihan) expect(keys, contains('customerId'));
        });
      }
    }
  }

  test('Standard transfer sesuai contoh', () {
    final s = settings(58)
      ..storeName = 'TRFBT CELL'
      ..address = ''
      ..footer = 'TERIMA KASIH'
      ..showSender = false;
    final r = sample(ReceiptType.trf, 0)
      ..amount = 300000
      ..admin = 0
      ..note = '';
    final text = ReceiptLayout.build(r, s).map((l) => l.text).join('\n');
    String row(String l, String v) => l + ' ' * (32 - l.length - v.length) + v;
    expect(text, contains(row('TANGGAL', '13/10/2026')));
    expect(text, contains(row('WAKTU', '16:46:00')));
    expect(text, contains(row('BANK TUJUAN', 'BCA')));
    expect(text, contains(row('NO REKENING', '2312750229')));
    expect(text, contains(row('PENERIMA', 'ROSHA FIRMANSYAH')));
    expect(text, contains(row('TOTAL', 'RP 300.000')));
    expect(text, contains('TID: C5DBBC'));
  });

  test('ciri khas tiap template', () {
    String build(int tpl) => ReceiptLayout.build(sample(ReceiptType.trf, tpl), settings(58))
        .map((l) => l.text)
        .join('\n');
    expect(build(0), contains('KODE REFERENSI'));
    expect(build(1), contains('PENERIMA:'));
    final modern = ReceiptLayout.build(sample(ReceiptType.trf, 2), settings(58));
    expect(modern.any((l) => l.size == RSize.big && l.text.contains('RP 1.505.000')), isTrue);
    expect(build(3), contains('STATUS      : SUKSES'));
    expect(build(3), contains('TID TERMINAL: C5DBBC'));
    expect(build(4), contains('TUJUAN  : BCA - 2312750229'));
    expect(build(4), contains('REF: 9527120261013164619'));
  });

  test('nilai kosong tampil "-" agar bisa diketuk', () {
    final r = Receipt.empty(ReceiptType.trf);
    final lines = ReceiptLayout.build(r, settings(58));
    final seg = lines.expand((l) => l.segs).firstWhere((s) => s.key == 'recipientName');
    expect(seg.text, '-');
  });

  test('biaya admin berjenjang', () {
    final s = AppSettings(adminTiered: true, adminRules: [
      AdminRule(min: 0, max: 100000, fee: 2500),
      AdminRule(min: 100001, max: 1000000, fee: 5000),
      AdminRule(min: 1000001, fee: 10000),
    ]);
    expect(s.calcAdmin(50000), 2500);
    expect(s.calcAdmin(500000), 5000);
    expect(s.calcAdmin(5000000), 10000);
  });

  test('TID dibuat sekali, kosong tetap kosong', () {
    expect(AppSettings().terminalId, hasLength(6));
    expect(AppSettings.fromJson({'terminalId': ''}).terminalId, '');
    expect(AppSettings.fromJson({}).terminalId, hasLength(6));
  });

  test('riwayat lama (tanggal+jam satu teks) dipecah', () {
    final r = Receipt.fromJson({'id': '1', 'type': 'trf', 'date': '15/10/2026 14:20 WIB'});
    expect(r.date, '15/10/2026');
    expect(r.time, '14:20 WIB');
  });
}
