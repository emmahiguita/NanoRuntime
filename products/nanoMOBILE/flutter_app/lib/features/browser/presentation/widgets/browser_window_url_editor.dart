import 'package:flutter/material.dart';
import 'browser_address_field.dart';

/// Las tarjetas usan el mismo editor que la barra principal, sin lógica duplicada.
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

  /// Título y dominio son informativos; tocar abre una edición real.
  @override
  Widget build(BuildContext context) => BrowserAddressField(
    url: url,
    title: title,
    showTitle: true,
    onSubmitted: onSubmitted,
    onEditingChanged: onToggleEdit,
  );
}
