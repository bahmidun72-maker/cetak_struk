import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/receipt.dart';
import '../services/receipt_layout.dart';
import '../services/receipt_parser.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/receipt_paper.dart';
import 'printer_screen.dart';

class EditorScreen extends StatefulWidget {
  final Receipt receipt;
  final List<String>? ocrRows;
  final String? imagePath;
  final bool isNew;

  const EditorScreen({
    super.key,
    required this.receipt,
    this.ocrRows,
    this.imagePath,
    this.isNew = false,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Receipt r;
  final _paperKey = GlobalKey();
  final Map<String, TextEditingController> _ctrls = {};
  bool _dirty = false;
  bool _adminManual = false;
  bool _busy = false;
  bool _capturing = false; // sembunyikan garis edit saat membuat gambar

  @override
  void initState() {
    super.initState();
    r = widget.receipt.copy();
    _dirty = widget.isNew;
    _adminManual = !widget.isNew;
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String key, String value) =>
      _ctrls.putIfAbsent(key, () => TextEditingController(text: value));

  void _resetControllers() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _ctrls.clear();
  }

  void _changed(VoidCallback fn) => setState(() {
        fn();
        _dirty = true;
      });

  // ------------------------------------------------------------ aksi

  void _changeType(ReceiptType t) {
    if (t == r.type) return;
    final state = context.read<AppState>();
    setState(() {
      final keep = (id: r.id, createdAt: r.createdAt, template: r.template);
      if (widget.ocrRows != null) {
        r = state.prepare(ReceiptParser.parse(widget.ocrRows!, type: t));
      } else {
        r.type = t;
      }
      r
        ..id = keep.id
        ..createdAt = keep.createdAt
        ..template = keep.template;
      _adminManual = false;
      _dirty = true;
      _resetControllers();
    });
  }

  Future<void> _save({bool quiet = false}) async {
    await context.read<AppState>().saveReceipt(r);
    _dirty = false;
    if (!quiet && mounted) showSnack(context, 'Struk disimpan ke riwayat');
  }

  Future<void> _print() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final res = await context.read<AppState>().printReceipt(r);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res.ok) _dirty = false;
    });
    showSnack(
      context,
      res.message,
      action: res.ok
          ? null
          : SnackBarAction(
              label: 'PRINTER',
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const PrinterScreen(standalone: true))),
            ),
    );
  }

  Future<void> _share() async {
    FocusScope.of(context).unfocus();
    final boundary = _paperKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    setState(() {
      _busy = true;
      _capturing = true;
    });
    try {
      await WidgetsBinding.instance.endOfFrame;
      final image = await boundary.toImage(pixelRatio: 3);
      if (mounted) setState(() => _capturing = false);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/struk_${r.id}.png');
      await file.writeAsBytes(data!.buffer.asUint8List());
      await _save(quiet: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (mounted) showSnack(context, 'Gagal membagikan: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _capturing = false;
        });
      }
    }
  }

  // ------------------------------------------------------------ edit dari preview

  static const _moneyKeys = {'amount', 'admin'};
  static const _settingKeys = {'store', 'address', 'footer'};

  String _labelFor(String key) {
    if (key.startsWith('detail:')) {
      final label = r.details[int.parse(key.substring(7))].label;
      return label.isEmpty ? 'Detail' : label;
    }
    return switch (key) {
      'store' => 'Nama toko',
      'address' => 'Alamat toko',
      'footer' => 'Teks penutup',
      'date' => 'Tanggal',
      'time' => 'Jam',
      'ref' => 'No. referensi',
      'recipientName' => 'Nama penerima',
      'recipientBank' => 'Bank tujuan',
      'recipientNumber' => 'No. rekening tujuan',
      'senderName' => 'Nama pengirim',
      'senderBank' => 'Bank pengirim',
      'senderNumber' => 'No. rekening pengirim',
      'note' => 'Berita',
      'customerId' => 'ID pelanggan',
      'customerName' => 'Nama pelanggan',
      'tariff' => 'Tarif/Daya',
      'kwh' => 'Jumlah kWh',
      'token' => 'Token',
      'category' => 'Layanan',
      'period' => 'Periode',
      'amount' => switch (r.type) {
          ReceiptType.trf => 'Nominal transfer',
          ReceiptType.pln => 'Harga token',
          ReceiptType.tagihan => 'Jumlah tagihan',
        },
      'admin' => 'Biaya admin',
      _ => key,
    };
  }

  String _getField(String key, AppState st) {
    if (key.startsWith('detail:')) return r.details[int.parse(key.substring(7))].value;
    return switch (key) {
      'store' => st.settings.storeName,
      'address' => st.settings.address,
      'footer' => st.settings.footer,
      'date' => r.date,
      'time' => r.time,
      'ref' => r.ref,
      'recipientName' => r.recipientName,
      'recipientBank' => r.recipientBank,
      'recipientNumber' => r.recipientNumber,
      'senderName' => r.senderName,
      'senderBank' => r.senderBank,
      'senderNumber' => r.senderNumber,
      'note' => r.note,
      'customerId' => r.customerId,
      'customerName' => r.customerName,
      'tariff' => r.tariff,
      'kwh' => r.kwh,
      'token' => r.token,
      'category' => r.category,
      'period' => r.period,
      'amount' => r.amount == 0 ? '' : thousands(r.amount),
      'admin' => r.admin == 0 ? '' : thousands(r.admin),
      _ => '',
    };
  }

  /// Tulis nilai ke struk (atau setelan toko) dan samakan isi form di bawah.
  void _setField(String key, String v, AppState st) {
    if (key.startsWith('detail:')) {
      final d = r.details[int.parse(key.substring(7))];
      d.value = v;
      _ctrls['dv_${d.hashCode}']?.text = v;
      return;
    }
    switch (key) {
      case 'store':
        st.updateSettings((s) => s.storeName = v);
        return;
      case 'address':
        st.updateSettings((s) => s.address = v);
        return;
      case 'footer':
        st.updateSettings((s) => s.footer = v);
        return;
      case 'amount':
        r.amount = digitsToInt(v);
        if (!_adminManual) {
          r.admin = st.settings.calcAdmin(r.amount);
          _ctrls['admin']?.text = r.admin == 0 ? '' : thousands(r.admin);
        }
        _ctrls['amount']?.text = r.amount == 0 ? '' : thousands(r.amount);
        return;
      case 'admin':
        r.admin = digitsToInt(v);
        _adminManual = true;
        _ctrls['admin']?.text = r.admin == 0 ? '' : thousands(r.admin);
        return;
      case 'date':
        r.date = v;
      case 'time':
        r.time = v;
      case 'ref':
        r.ref = v;
      case 'recipientName':
        r.recipientName = v;
      case 'recipientBank':
        r.recipientBank = v;
      case 'recipientNumber':
        r.recipientNumber = v;
      case 'senderName':
        r.senderName = v;
      case 'senderBank':
        r.senderBank = v;
      case 'senderNumber':
        r.senderNumber = v;
      case 'note':
        r.note = v;
      case 'customerId':
        r.customerId = v;
      case 'customerName':
        r.customerName = v;
      case 'tariff':
        r.tariff = v;
      case 'kwh':
        r.kwh = v;
      case 'token':
        r.token = v;
      case 'category':
        r.category = v;
      case 'period':
        r.period = v;
      default:
        return;
    }
    _ctrls[key]?.text = v;
  }

  Future<void> _editFromPreview(String key) async {
    final st = context.read<AppState>();
    final money = _moneyKeys.contains(key);
    final multi = key == 'address' || key == 'footer';
    final ctrl = TextEditingController(text: _getField(key, st));
    ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
    final res = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(_labelFor(key)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: multi ? 4 : 1,
          minLines: 1,
          textCapitalization: TextCapitalization.characters,
          keyboardType: money || key == 'token' ? TextInputType.number : TextInputType.text,
          inputFormatters: money ? [ThousandsInputFormatter()] : null,
          decoration: InputDecoration(prefixText: money ? 'Rp ' : null),
          onSubmitted: multi ? null : (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Simpan')),
        ],
      ),
    );
    ctrl.dispose();
    if (res == null || !mounted) return;
    setState(() {
      _setField(key, res.trim(), st);
      if (!_settingKeys.contains(key)) _dirty = true;
    });
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final res = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Simpan struk?'),
        content: const Text('Struk ini belum disimpan ke riwayat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 'discard'), child: const Text('Buang')),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('Simpan')),
        ],
      ),
    );
    if (res == 'save') await _save(quiet: true);
    return res == 'save' || res == 'discard';
  }

  void _showOcrText() {
    final text = widget.ocrRows!.join('\n');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (c, sc) => ListView(controller: sc, padding: const EdgeInsets.all(16), children: [
          Row(children: [
            const Expanded(
                child: Text('Teks hasil scan', style: TextStyle(fontWeight: FontWeight.w700))),
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Salin'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                Navigator.pop(c);
                showSnack(context, 'Teks disalin');
              },
            ),
          ]),
          const SizedBox(height: 8),
          SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        ]),
      ),
    );
  }

  void _showImage() {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(child: Image.file(File(widget.imagePath!))),
      ),
    );
  }

  // ------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lines = ReceiptLayout.build(r, state.settings);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmLeave()) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(r.type.label),
          actions: [
            if (widget.imagePath != null)
              IconButton(
                  tooltip: 'Lihat gambar asli',
                  icon: const Icon(Icons.image_outlined),
                  onPressed: _showImage),
            if (widget.ocrRows != null)
              IconButton(
                  tooltip: 'Teks hasil scan',
                  icon: const Icon(Icons.notes_rounded),
                  onPressed: _showOcrText),
            IconButton(
                tooltip: 'Simpan',
                icon: const Icon(Icons.save_outlined),
                onPressed: () => _save()),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<ReceiptType>(
                showSelectedIcon: false,
                segments: [
                  for (final t in ReceiptType.values)
                    ButtonSegment(
                      value: t,
                      icon: Icon(typeIcon(t), size: 18),
                      label: Text(switch (t) {
                        ReceiptType.trf => 'Transfer',
                        ReceiptType.pln => 'PLN',
                        ReceiptType.tagihan => 'Tagihan',
                      }),
                    ),
                ],
                selected: {r.type},
                onSelectionChanged: (s) => _changeType(s.first),
              ),
            ),
            const SizedBox(height: 14),
            _previewCard(lines, state),
            ..._formSections(state),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: _busy ? null : _share,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Bagikan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: _busy ? null : _print,
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.print_rounded),
                  label: const Text('CETAK STRUK'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _previewCard(List<RLine> lines, AppState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ReceiptLayout.templateNames.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text('${i + 1}. ${ReceiptLayout.templateNames[i]}'),
              selected: r.template == i,
              showCheckmark: false,
              onSelected: (_) => _changed(() => r.template = i),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.touch_app_outlined, size: 16, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Ketuk teks bergaris titik untuk mengubah • ${state.settings.paperWidth}mm',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ]),
        const SizedBox(height: 8),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: RepaintBoundary(
                key: _paperKey,
                child: ReceiptPaper(
                  lines: lines,
                  settings: state.settings,
                  onEdit: _capturing ? null : _editFromPreview,
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _field(String key, String label, String value, ValueChanged<String> onChanged,
      {TextInputType? keyboard, String? hint, int maxLines = 1, Widget? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _ctrl(key, value),
        keyboardType: keyboard,
        maxLines: maxLines,
        minLines: 1,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(labelText: label, hintText: hint, suffixIcon: suffix),
        onChanged: (v) => _changed(() => onChanged(v)),
      ),
    );
  }

  Widget _moneyField(String key, String label, int value, ValueChanged<int> onChanged,
      {Widget? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _ctrl(key, value == 0 ? '' : thousands(value)),
        keyboardType: TextInputType.number,
        inputFormatters: [ThousandsInputFormatter()],
        decoration: InputDecoration(labelText: label, prefixText: 'Rp ', suffixIcon: suffix),
        onChanged: (v) => _changed(() => onChanged(digitsToInt(v))),
      ),
    );
  }

  List<Widget> _formSections(AppState state) {
    final common = SectionCard(
      title: 'Info Transaksi',
      icon: Icons.event_note_rounded,
      children: [
        Row(children: [
          Expanded(child: _field('date', 'Tanggal', r.date, (v) => r.date = v)),
          const SizedBox(width: 10),
          Expanded(
            child: _field('time', 'Jam', r.time, (v) => r.time = v,
                suffix: IconButton(
                  tooltip: 'Isi waktu sekarang',
                  icon: const Icon(Icons.schedule_rounded),
                  onPressed: () => setState(() {
                    final now = DateTime.now();
                    r
                      ..date = formatDate(now)
                      ..time = formatTime(now);
                    _ctrls['date']?.text = r.date;
                    _ctrls['time']?.text = r.time;
                    _dirty = true;
                  }),
                )),
          ),
        ]),
        _field('ref', 'No. referensi', r.ref, (v) => r.ref = v),
      ],
    );

    final body = switch (r.type) {
      ReceiptType.trf => _transferSections(state),
      ReceiptType.pln => [
          SectionCard(title: 'Data Token Listrik', icon: Icons.bolt_rounded, children: [
            _field('token', 'Token (20 digit)', r.token, (v) => r.token = v,
                keyboard: TextInputType.number),
            _field('customerId', 'ID pelanggan / No. meter', r.customerId, (v) => r.customerId = v,
                keyboard: TextInputType.number),
            _field('customerName', 'Nama pelanggan', r.customerName, (v) => r.customerName = v),
            Row(children: [
              Expanded(child: _field('tariff', 'Tarif/Daya', r.tariff, (v) => r.tariff = v, hint: 'R1/900VA')),
              const SizedBox(width: 10),
              Expanded(child: _field('kwh', 'Jumlah kWh', r.kwh, (v) => r.kwh = v,
                  keyboard: const TextInputType.numberWithOptions(decimal: true))),
            ]),
          ]),
        ],
      ReceiptType.tagihan => [_billSection()],
    };

    final amountLabel = switch (r.type) {
      ReceiptType.trf => 'Nominal transfer',
      ReceiptType.pln => 'Harga token',
      ReceiptType.tagihan => 'Jumlah tagihan',
    };

    final payment = SectionCard(
      title: 'Pembayaran',
      icon: Icons.payments_outlined,
      children: [
        _moneyField('amount', amountLabel, r.amount, (v) {
          r.amount = v;
          if (!_adminManual) {
            r.admin = state.settings.calcAdmin(v);
            final c = _ctrls['admin'];
            if (c != null) c.text = r.admin == 0 ? '' : thousands(r.admin);
          }
        }),
        _moneyField('admin', 'Biaya admin', r.admin, (v) {
          r.admin = v;
          _adminManual = true;
        },
            suffix: IconButton(
              tooltip: 'Hitung otomatis dari setelan',
              icon: const Icon(Icons.auto_fix_high_rounded),
              onPressed: () => setState(() {
                _adminManual = false;
                r.admin = state.settings.calcAdmin(r.amount);
                _ctrls['admin']?.text = r.admin == 0 ? '' : thousands(r.admin);
                _dirty = true;
              }),
            )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(rupiah(r.total),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ]),
        ),
      ],
    );

    return [common, ...body, payment];
  }

  List<Widget> _transferSections(AppState state) {
    final s = state.settings;
    return [
      SectionCard(title: 'Penerima', icon: Icons.person_outline_rounded, children: [
        _field('recipientName', 'Nama penerima', r.recipientName, (v) => r.recipientName = v),
        Row(children: [
          Expanded(child: _field('recipientBank', 'Bank / e-wallet', r.recipientBank, (v) => r.recipientBank = v)),
          const SizedBox(width: 10),
          Expanded(
              child: _field('recipientNumber', 'No. rekening', r.recipientNumber, (v) => r.recipientNumber = v,
                  keyboard: TextInputType.number)),
        ]),
        _field('note', 'Berita / keterangan', r.note, (v) => r.note = v),
      ]),
      SectionCard(
        title: 'Pengirim',
        icon: Icons.account_balance_wallet_outlined,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Tampilkan', style: Theme.of(context).textTheme.bodySmall),
          Switch(
            value: s.showSender,
            onChanged: (v) => state.updateSettings((x) => x.showSender = v),
          ),
        ]),
        children: [
          if (s.senders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(spacing: 8, runSpacing: 6, children: [
                for (final acc in s.senders)
                  ActionChip(
                    avatar: const Icon(Icons.account_balance_outlined, size: 16),
                    label: Text('${acc.bank} ${acc.name}'.trim()),
                    onPressed: () => setState(() {
                      r
                        ..senderName = acc.name
                        ..senderBank = acc.bank
                        ..senderNumber = acc.number;
                      _ctrls['senderName']?.text = acc.name;
                      _ctrls['senderBank']?.text = acc.bank;
                      _ctrls['senderNumber']?.text = acc.number;
                      _dirty = true;
                    }),
                  ),
              ]),
            ),
          _field('senderName', 'Nama pengirim', r.senderName, (v) => r.senderName = v),
          Row(children: [
            Expanded(child: _field('senderBank', 'Bank', r.senderBank, (v) => r.senderBank = v)),
            const SizedBox(width: 10),
            Expanded(
                child: _field('senderNumber', 'No. rekening', r.senderNumber, (v) => r.senderNumber = v,
                    keyboard: TextInputType.number)),
          ]),
          if (!s.showSender)
            Text('Data pengirim tidak dicetak. Aktifkan "Tampilkan" untuk mencetaknya.',
                style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ];
  }

  Widget _billSection() {
    return SectionCard(title: 'Data Tagihan', icon: Icons.receipt_long_rounded, children: [
      _field('category', 'Layanan', r.category, (v) => r.category = v,
          hint: 'PDAM, BPJS, PLN PASCABAYAR, PULSA...'),
      _field('customerId', 'ID pelanggan / nomor', r.customerId, (v) => r.customerId = v),
      _field('customerName', 'Nama pelanggan', r.customerName, (v) => r.customerName = v),
      _field('period', 'Periode', r.period, (v) => r.period = v),
      if (r.details.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text('Detail tambahan', style: Theme.of(context).textTheme.labelLarge),
        ),
      for (var i = 0; i < r.details.length; i++)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              flex: 2,
              child: _field('dl_${r.details[i].hashCode}', 'Label', r.details[i].label,
                  (v) => r.details[i].label = v)),
          const SizedBox(width: 8),
          Expanded(
              flex: 3,
              child: _field('dv_${r.details[i].hashCode}', 'Isi', r.details[i].value,
                  (v) => r.details[i].value = v)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => _changed(() => r.details.removeAt(i)),
          ),
        ]),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Tambah baris detail'),
          onPressed: () => _changed(() => r.details.add(DetailRow())),
        ),
      ),
    ]);
  }
}
