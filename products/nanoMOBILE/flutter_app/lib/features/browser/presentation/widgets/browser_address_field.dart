// QUÉ: Adaptador de compatibilidad para BrowserAddressField.
// CÓMO: Delega directamente a NanoAddressBar para mantener una única fuente de verdad.
// POR QUÉ: Elimina implementaciones duplicadas y centraliza los estilos Safari (< 45 líneas).
library;

import 'package:flutter/material.dart';
import 'nano_address_bar.dart';

class BrowserAddressField extends StatelessWidget {
  final String url, title;
  final bool showTitle;
  final Widget? trailing;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<bool>? onEditingChanged;

  const BrowserAddressField({
    super.key,
    required this.url,
    this.title = '',
    this.showTitle = false,
    this.trailing,
    required this.onSubmitted,
    this.onEditingChanged,
  });

  @override
  Widget build(BuildContext context) => NanoAddressBar(
    url: url,
    title: title,
    trailing: trailing,
    onSubmitted: onSubmitted,
    onEditingChanged: onEditingChanged,
  );
}
