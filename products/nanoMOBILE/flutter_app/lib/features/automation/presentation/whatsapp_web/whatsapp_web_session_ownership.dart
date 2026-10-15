/// Un solo WebView retenido, compartido entre Mensajería y su vista visible.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

abstract final class WhatsAppWebSessionOwnership {
  static final keepAlive = InAppWebViewKeepAlive();
  static final foreground = ValueNotifier<bool>(false);
  static bool created = false;
}
