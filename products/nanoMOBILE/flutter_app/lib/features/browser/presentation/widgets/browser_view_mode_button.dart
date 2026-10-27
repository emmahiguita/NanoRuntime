import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'browser_display_mode.dart';

/// Selector compacto de modos de visualización (Página, Ventanas, Carrusel 3D).
///
/// - QUÉ HACE: Despliega el conmutador de pestañas/vistas con badge numérico sin ocupar espacio excesivo.
/// - CÓMO FUNCIONA: Usa un botón cuadrado de 34x34 con insignia de pestañas abiertas.
/// - POR QUÉ: Permite maximizar el ancho útil de la barra de dirección (<200 líneas).
class BrowserViewModeButton extends StatelessWidget {
  final BrowserDisplayMode mode;
  final int tabCount;
  final ValueChanged<BrowserDisplayMode> onSelected;

  const BrowserViewModeButton({
    super.key,
    required this.mode,
    required this.tabCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 34,
      height: 34,
      child: PopupMenuButton<BrowserDisplayMode>(
        tooltip: 'Vistas · $tabCount pestañas',
        useRootNavigator: true,
        initialValue: mode,
        padding: EdgeInsets.zero,
        onSelected: onSelected,
        icon: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$tabCount',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
            ),
          ),
        ),
        constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
        itemBuilder: (_) => [
          _item(BrowserDisplayMode.focused, 'Página activa', CupertinoIcons.device_phone_portrait),
          _item(BrowserDisplayMode.verticalStack, 'Ventanas y paneles', CupertinoIcons.square_stack_3d_down_right),
          _item(BrowserDisplayMode.carousel3D, 'Carrusel de pestañas', CupertinoIcons.square_stack_3d_up_fill),
        ],
      ),
    );
  }

  PopupMenuItem<BrowserDisplayMode> _item(
    BrowserDisplayMode value,
    String label,
    IconData icon,
  ) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5))),
        if (mode == value) const Icon(CupertinoIcons.checkmark_alt, size: 16),
      ],
    ),
  );
}
