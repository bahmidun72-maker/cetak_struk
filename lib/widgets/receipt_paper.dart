import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/receipt_layout.dart';

/// Preview struk seperti kertas thermal. Teks memakai font monospace dengan
/// jumlah karakter per baris yang sama persis dengan printer.
///
/// Bila [onEdit] diisi, teks yang bisa diubah diberi garis bawah titik-titik
/// dan memanggil [onEdit] dengan nama field-nya saat diketuk.
class ReceiptPaper extends StatefulWidget {
  final List<RLine> lines;
  final AppSettings settings;
  final ValueChanged<String>? onEdit;

  const ReceiptPaper({super.key, required this.lines, required this.settings, this.onEdit});

  @override
  State<ReceiptPaper> createState() => _ReceiptPaperState();
}

class _ReceiptPaperState extends State<ReceiptPaper> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  static const _base = TextStyle(
    fontFamily: 'monospace',
    fontSize: 14,
    height: 1.3,
    color: Color(0xFF1F2937),
    letterSpacing: 0,
  );

  Widget _line(RLine l, int chars) {
    final big = l.size == RSize.big;
    var style = l.bold ? _base.copyWith(fontWeight: FontWeight.w800) : _base;
    // Huruf lebar ganda: setengah jumlah karakter dengan ukuran font dua kali.
    if (big) style = style.copyWith(fontSize: 28);
    final width = big ? chars ~/ 2 : chars;
    final pad = width - l.text.length;

    final spans = <InlineSpan>[];
    for (final seg in l.segs) {
      if (seg.key != null && widget.onEdit != null && seg.text.trim().isNotEmpty) {
        final key = seg.key!;
        final rec = TapGestureRecognizer()..onTap = () => widget.onEdit!(key);
        _recognizers.add(rec);
        spans.add(TextSpan(
          text: seg.text,
          recognizer: rec,
          style: const TextStyle(
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dotted,
            decorationColor: Color(0xFF6366F1),
            decorationThickness: 2,
          ),
        ));
      } else {
        spans.add(TextSpan(text: seg.text));
      }
    }
    if (pad > 0) spans.add(TextSpan(text: ' ' * pad));

    final text = Text.rich(TextSpan(style: style, children: spans), softWrap: false);
    if (l.size != RSize.tall) return text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Transform.scale(scaleX: 1, scaleY: 2, child: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final settings = widget.settings;
    final chars = settings.charsPerLine;
    final logo = settings.logoPath;
    final hasLogo = logo != null && File(logo).existsSync();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 22),
      child: LayoutBuilder(builder: (context, c) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasLogo)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(
                  child: Image.file(
                    File(logo),
                    width: c.maxWidth * settings.logoWidthPct / 100,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            FittedBox(
              fit: BoxFit.fitWidth,
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [for (final l in widget.lines) _line(l, chars)],
              ),
            ),
          ],
        );
      }),
    );
  }
}
