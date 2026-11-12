import 'dart:async';

import 'package:flutter/services.dart';

/// Menerima gambar yang dibagikan dari aplikasi lain (menu "Bagikan" di
/// m-banking / galeri). Sisi native ada di MainActivity.kt.
class ShareIntentService {
  static const _channel = MethodChannel('cetak_struk/share');
  final _controller = StreamController<String>.broadcast();

  Stream<String> get images => _controller.stream;

  ShareIntentService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onImage' && call.arguments is String) {
        _controller.add(call.arguments as String);
      }
    });
  }

  /// Gambar yang membuka aplikasi (bila ada).
  Future<String?> initialImage() async {
    try {
      return await _channel.invokeMethod<String>('getInitialImage');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
