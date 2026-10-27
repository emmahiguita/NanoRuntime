// QUÉ: separa la identidad visual del estado y las acciones de una sesión web.
// CÓMO: Qwen usa su símbolo oficial solo en dominios reconocidos; otros usan inicial.
// POR QUÉ: el nombre editable de un proveedor personalizado no acredita su identidad.
import 'package:flutter/material.dart';
import '../../../../core/widgets/qwen_brand_icon.dart';

class AiWebProviderIcon extends StatelessWidget {
  const AiWebProviderIcon({super.key, required this.name, required this.url});
  final String name;
  final String url;

  static bool isQwenUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri?.scheme == 'https' &&
        (uri?.host == 'qwen.ai' || uri?.host == 'chat.qwen.ai');
  }

  @override
  Widget build(BuildContext context) {
    if (isQwenUrl(url)) return const QwenBrandIcon(size: 38);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}
