# Cetak Struk

Aplikasi Android (Flutter) untuk mengubah screenshot bukti transaksi menjadi struk
printer thermal Bluetooth. **100% offline**: tanpa login, kuota, langganan, atau server.

## Alur

```
Screenshot/foto bukti (galeri, kamera, atau menu "Bagikan" dari m-banking)
  → OCR di HP (Google ML Kit, model Latin dibundel)      lib/services/ocr_service.dart
  → susun baris kiri-kanan                                lib/services/ocr_layout.dart
  → deteksi jenis & ambil data (regex + kata kunci)       lib/services/receipt_parser.dart
  → editor + preview + biaya admin otomatis               lib/screens/editor_screen.dart
  → tata letak 32/48 karakter                             lib/services/receipt_layout.dart
  → ESC/POS ke printer Bluetooth / bagikan sebagai PNG    lib/services/printer_service.dart
  → riwayat lokal (SharedPreferences)                     lib/services/storage_service.dart
```

Jenis struk: **Bukti Transfer**, **Token Listrik (PLN prabayar)**, **Tagihan & PPOB**
(PDAM, BPJS, PLN pascabayar, pulsa, dll).

## Build

```bash
flutter test
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64
```

Catatan:
- `permission_handler` dikunci di `^12` karena versi 13 butuh Android Gradle Plugin 9.
- Bila Gradle gagal dengan `Unable to establish loopback connection` (Java 21 di Windows),
  set `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=<folder pendek tanpa spasi>`.
- Izin `INTERNET` sengaja dibuang di `AndroidManifest.xml`.
