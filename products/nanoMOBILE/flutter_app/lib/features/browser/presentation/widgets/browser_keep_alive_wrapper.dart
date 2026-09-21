import 'package:flutter/material.dart';

/// Envoltorio ligero para retener el estado vivo de widgets en memoria.
/// 
/// - ¿Qué hace?: Implementa `AutomaticKeepAliveClientMixin` con `wantKeepAlive: true`.
/// - ¿Cómo funciona?: Notifica al ancestro scrollable / IndexedStack para no destruir el subárbol.
/// - ¿Por qué?: Previene recargas involuntarias de `InAppWebView` al hacer scroll o cambiar pestañas.
class BrowserKeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const BrowserKeepAliveWrapper({super.key, required this.child});

  @override
  State<BrowserKeepAliveWrapper> createState() => _BrowserKeepAliveWrapperState();
}

class _BrowserKeepAliveWrapperState extends State<BrowserKeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
