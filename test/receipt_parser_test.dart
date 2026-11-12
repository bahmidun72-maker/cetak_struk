import 'package:cetak_struk/models/receipt.dart';
import 'package:cetak_struk/services/ocr_layout.dart';
import 'package:cetak_struk/services/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> rows(String s) =>
    s.trim().split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

void main() {
  group('parseAmount', () {
    test('format rupiah umum', () {
      expect(ReceiptParser.parseAmount('Rp 150.000,00'), 150000);
      expect(ReceiptParser.parseAmount('Rp50.000'), 50000);
      expect(ReceiptParser.parseAmount('IDR 1,250,000.00'), 1250000);
      expect(ReceiptParser.parseAmount('Rp. 2.500'), 2500);
      expect(ReceiptParser.parseAmount('Total  -Rp 75.000'), 75000);
      expect(ReceiptParser.parseAmount('tanpa angka'), isNull);
    });
  });

  group('deteksi & parse', () {
    test('BCA m-Transfer', () {
      final r = ReceiptParser.parse(rows('''
        m-Transfer
        BERHASIL
        14/10/2026 10:23:45
        Ke  0123456789
        BUDI SANTOSO
        Rp 150.000,00
        Berita  Bayar kos
        No. Referensi  2610141023451234
      '''));
      expect(r.type, ReceiptType.trf);
      expect(r.recipientNumber, '0123456789');
      expect(r.recipientName, 'BUDI SANTOSO');
      expect(r.amount, 150000);
      expect(r.note, 'Bayar kos');
      expect(r.ref, '2610141023451234');
      expect(r.date, '14/10/2026');
      expect(r.time, '10:23:45');
    });

    test('BRImo antar bank', () {
      final r = ReceiptParser.parse(rows('''
        Transaksi Berhasil
        15 Oktober 2026, 14:20:11 WIB
        No. Ref  123456789012
        Sumber Dana
        JOKO WIDODO
        BANK BRI
        0123 0100 1234 567
        Jenis Transaksi  Transfer Bank BRI
        Tujuan
        ANDI PRATAMA
        BANK BCA
        1234567890
        Nominal  Rp100.000,00
        Biaya Admin  Rp0,00
        Total  Rp100.000,00
      '''));
      expect(r.type, ReceiptType.trf);
      expect(r.senderName, 'JOKO WIDODO');
      expect(r.senderBank, 'BRI');
      expect(r.senderNumber, '012301001234567');
      expect(r.recipientName, 'ANDI PRATAMA');
      expect(r.recipientBank, 'BCA');
      expect(r.recipientNumber, '1234567890');
      expect(r.amount, 100000);
      expect(r.ref, '123456789012');
      expect(r.date, '15/10/2026');
      expect(r.time, '14:20:11 WIB');
    });

    test('Livin Mandiri', () {
      final r = ReceiptParser.parse(rows('''
        Transfer Berhasil
        Rp 250.000
        15 Okt 2026 • 08:30:12 WIB
        Penerima
        RINA MARLINA
        Bank Mandiri - 1370012345678
        Sumber Rekening
        AHMAD FAUZI
        **** 4321
        Detail Transaksi
        No. Referensi  20261015083012345
        Catatan  -
      '''));
      expect(r.type, ReceiptType.trf);
      expect(r.recipientName, 'RINA MARLINA');
      expect(r.recipientBank, 'MANDIRI');
      expect(r.recipientNumber, '1370012345678');
      expect(r.senderName, 'AHMAD FAUZI');
      expect(r.senderNumber, '****4321');
      expect(r.amount, 250000);
      expect(r.note, '');
    });

    test('DANA kirim ke bank', () {
      final r = ReceiptParser.parse(rows('''
        Transfer Berhasil
        Rp50.000
        Penerima
        SITI AMINAH
        BCA • 1234567890
        Detail Transaksi
        Tanggal  15 Okt 2026, 09:12
        ID Transaksi  2026101511121280010016
        Biaya Transfer  Rp1.000
        Total Bayar  Rp51.000
      '''));
      expect(r.type, ReceiptType.trf);
      expect(r.recipientName, 'SITI AMINAH');
      expect(r.recipientBank, 'BCA');
      expect(r.recipientNumber, '1234567890');
      expect(r.amount, 50000);
      expect(r.ref, '2026101511121280010016');
      expect(r.date, '15/10/2026');
      expect(r.time, '09:12');
    });

    test('Token PLN', () {
      final r = ReceiptParser.parse(rows('''
        Pembelian Token Listrik Berhasil
        STRUK PEMBELIAN LISTRIK PRABAYAR
        No. Meter  14234567890
        IDPEL  512345678901
        Nama  SUPRIYADI
        Tarif/Daya  R1M/900 VA
        No. Ref  0ABC12345DEF67890
        Rp Bayar  Rp 102.500
        Meterai  Rp 0
        PPJ  Rp 7.500
        Rp Stroom/Token  Rp 95.000
        Jml KWH  63,5
        STROOM/TOKEN
        5512 3456 7890 1234 5678
        Tanggal  15/10/2026 13:05
      '''));
      expect(r.type, ReceiptType.pln);
      expect(r.token, '5512 3456 7890 1234 5678');
      expect(r.customerId, '512345678901');
      expect(r.customerName, 'SUPRIYADI');
      expect(r.tariff, 'R1M/900VA');
      expect(r.kwh, '63,5');
      expect(r.amount, 102500);
      expect(r.ref, '0ABC12345DEF67890');
      expect(r.date, '15/10/2026');
      expect(r.time, '13:05');
    });

    test('BPJS Kesehatan', () {
      final r = ReceiptParser.parse(rows('''
        Pembayaran Berhasil
        BPJS Kesehatan
        No. VA  8888801234567890
        Nama  DEWI LESTARI
        Jumlah Peserta  3 Orang
        Periode  OKT 2026
        Tagihan  Rp 105.000
        Biaya Admin  Rp 2.500
        Total Bayar  Rp 107.500
        No. Ref  BPJS2610150001
        15 Okt 2026 10:00
      '''));
      expect(r.type, ReceiptType.tagihan);
      expect(r.category, 'BPJS KESEHATAN');
      expect(r.customerId, '8888801234567890');
      expect(r.customerName, 'DEWI LESTARI');
      expect(r.period, 'OKT 2026');
      expect(r.amount, 105000);
      expect(r.details.map((d) => d.label), contains('JUMLAH PESERTA'));
      expect(r.ref, 'BPJS2610150001');
      expect(r.date, '15/10/2026');
      expect(r.time, '10:00');
    });

    test('Pulsa', () {
      final r = ReceiptParser.parse(rows('''
        Transaksi Berhasil
        Pulsa Telkomsel 50.000
        Nomor HP  081234567890
        SN  1234567890123456
        Harga  Rp 50.500
        14-10-2026 19:22
      '''));
      expect(r.type, ReceiptType.tagihan);
      expect(r.category, 'PULSA');
      expect(r.customerId, '081234567890');
      expect(r.amount, 50500);
      expect(r.details.any((d) => d.label == 'SN' && d.value == '1234567890123456'), isTrue);
      expect(r.date, '14/10/2026');
      expect(r.time, '19:22');
    });

    test('no. ref yang terpecah spasi oleh OCR digabung', () {
      final r = ReceiptParser.parse(rows('''
        Token Listrik
        No. Ref  OABC12345 DEF67890
        STROOM/TOKEN
        5512 3456 7890 1234 5678
        Rp Bayar  Rp 102.500
      '''));
      expect(r.ref, 'OABC12345DEF67890');
      final r2 = ReceiptParser.parse(rows('No. Referensi  1234 5678 9012  Salin\nRp 10.000'));
      expect(r2.ref, '123456789012');
    });

    test('blok "Penerima" dengan sub-label Nama/Bank/No. Rekening', () {
      final r = ReceiptParser.parse(rows('''
        m-Transfer
        Transfer Berhasil
        Rp 300.000,00
        Tanggal  13 Okt 2026 16:46:00
        No. Referensi  9527120261013164619
        Penerima
        Nama  ROSHA FIRMANSYAH
        Bank  BCA
        No. Rekening  2312750229
        Nominal  Rp 300.000,00
        Biaya Admin  Rp 0,00
      '''));
      expect(r.type, ReceiptType.trf);
      expect(r.recipientName, 'ROSHA FIRMANSYAH');
      expect(r.recipientBank, 'BCA');
      expect(r.recipientNumber, '2312750229');
      expect(r.amount, 300000);
      expect(r.ref, '9527120261013164619');
      expect(r.date, '13/10/2026');
      expect(r.time, '16:46:00');
    });

    test('paksa jenis tertentu', () {
      final r = ReceiptParser.parse(rows('Rp 20.000\nTerima kasih'), type: ReceiptType.pln);
      expect(r.type, ReceiptType.pln);
      expect(r.amount, 20000);
    });
  });

  test('groupIntoRows menggabungkan kolom kiri-kanan', () {
    final out = groupIntoRows(const [
      OcrPiece('Rp 50.000', 300, 102, 420, 122),
      OcrPiece('Nominal', 20, 100, 120, 120),
      OcrPiece('Penerima', 20, 140, 130, 160),
      OcrPiece('BUDI', 300, 141, 360, 161),
      OcrPiece('Judul', 20, 40, 200, 70),
    ]);
    expect(out, ['Judul', 'Nominal  Rp 50.000', 'Penerima  BUDI']);
  });
}
