import 'package:flutter/services.dart';

String _pad2(int n) => n.toString().padLeft(2, '0');

/// 1500000 -> "1.500.000"
String thousands(int value) {
  final neg = value < 0;
  final s = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${neg ? '-' : ''}$buf';
}

/// 1500000 -> "Rp 1.500.000"
String rupiah(int value) => 'Rp ${thousands(value)}';

/// Ambil angka saja dari teks ("Rp 1.500" -> 1500).
int digitsToInt(String s) {
  final d = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.isEmpty) return 0;
  return int.tryParse(d.length > 15 ? d.substring(0, 15) : d) ?? 0;
}

String formatDate(DateTime d) => '${_pad2(d.day)}/${_pad2(d.month)}/${d.year}';

String formatTime(DateTime d) => '${_pad2(d.hour)}:${_pad2(d.minute)}';

/// "15/10/2026 14:20 WIB" -> (date: "15/10/2026", time: "14:20 WIB").
({String date, String time}) splitDateTime(String s) {
  final m = RegExp(r'^\s*(.*?)[\s,]+(\d{1,2}[:.]\d{2}.*)$').firstMatch(s);
  if (m == null) return (date: s.trim(), time: '');
  return (date: m.group(1)!.trim(), time: m.group(2)!.trim());
}

String formatDateTime(DateTime d) =>
    '${_pad2(d.day)}/${_pad2(d.month)}/${d.year} ${_pad2(d.hour)}:${_pad2(d.minute)}';

/// Token PLN 20 digit -> "1234 5678 9012 3456 7890".
String formatToken(String token) {
  final d = token.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.isEmpty) return token.trim();
  final buf = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i > 0 && i % 4 == 0) buf.write(' ');
    buf.write(d[i]);
  }
  return buf.toString();
}

/// Input formatter angka dengan pemisah ribuan titik.
class ThousandsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final text = thousands(int.parse(digits.length > 15 ? digits.substring(0, 15) : digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
