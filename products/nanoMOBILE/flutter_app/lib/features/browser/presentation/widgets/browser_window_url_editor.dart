// QUÉ: Adaptador de edición de URL para tarjetas del navegador Nano AI.
// CÓMO: Reutiliza BrowserAddressField delegando eventos de edición al callback padre.
// POR QUÉ: Evita lógica duplicada y mantiene consistencia visual (< 40 líneas).

import 'package:flutter/material.dart';
import 'browser_address_field.dart';

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
  Widget build(BuildContext context) => BrowserAddressField(
    url: url,
    title: title,
    showTitle: true,
    onSubmitted: onSubmitted,
    onEditingChanged: onToggleEdit == null ? null : (_) => onToggleEdit!(),
  );
}
