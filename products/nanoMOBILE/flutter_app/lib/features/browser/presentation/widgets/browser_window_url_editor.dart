// QUÉ: Adaptador de edición de URL para tarjetas del navegador Nano AI.
// CÓMO: Reutiliza NanoAddressBar delegando eventos de edición al callback padre.
// POR QUÉ: Evita lógica duplicada y mantiene consistencia visual (< 35 líneas).

import 'package:flutter/material.dart';
import 'nano_address_bar.dart';

class BrowserWindowUrlEditor extends StatelessWidget {
  final String title, url;
  final Color siteColor;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onToggleEdit;

  const BrowserWindowUrlEditor({
    super.key,
    required this.title,
    required this.url,
    required this.siteColor,
    required this.onSubmitted,
    this.onToggleEdit,
  });

  @override
  Widget build(BuildContext context) => NanoAddressBar(
    url: url,
    title: title,
    onSubmitted: onSubmitted,
    onEditingChanged: onToggleEdit == null ? null : (_) => onToggleEdit!(),
  );
}
