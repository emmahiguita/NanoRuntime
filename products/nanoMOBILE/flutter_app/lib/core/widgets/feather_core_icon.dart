import 'package:flutter/material.dart';

import 'navigation/nano_glyph.dart';
import 'feather_core_tile.dart';
part 'feather_core_symbol.dart';
part 'feather_core_assets.part.dart';
part 'feather_core_mapping.part.dart';

/// Compatibilidad para componentes antiguos: el dibujo real vive en NanoGlyph.
/// Así cada significado tiene un único icono y no se duplican familias visuales.
enum FeatherCoreType {
  whatsappBusiness,
  notifications,
  settings,
  devTools,
  chat,
  terminal,
  linux,
  automation,
  files,
  models,
  system,
  vision,
  network,
  security,
  battery,
  assistant,
  documents,
  mic,
  voice,
  audioSplit,
  calendar,
  home,
  search,
  code,
  analytics,
  cloud,
  camera,
  businessCatalog,
  payments,
  delivery,
  hours,
  location,
  rules,
  personalAgent,
}

class FeatherCoreIcon extends StatelessWidget {
  const FeatherCoreIcon({
    super.key,
    required this.type,
    this.size = 42,
    this.accentColor,
    this.glow = false,
    this.framed = true,
  }) : icon = null,
       customChild = null;

  const FeatherCoreIcon.custom({
    super.key,
    required this.icon,
    this.size = 42,
    this.accentColor,
    this.glow = false,
    this.framed = true,
  }) : type = null,
       customChild = null;

  const FeatherCoreIcon.builder({
    super.key,
    required this.customChild,
    this.size = 42,
    this.accentColor,
    this.glow = false,
    this.framed = true,
  }) : type = null,
       icon = null;

  final FeatherCoreType? type;
  final IconData? icon;
  final Widget? customChild;
  final double size;
  final Color? accentColor;
  final bool glow;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? const Color(0xFF1769C2);
    if (customChild != null) {
      return _tile(context, customChild!, accent);
    }
    if (icon != null) {
      return _tile(
        context,
        Icon(icon, color: accent, size: size * .52),
        accent,
      );
    }
    // Recurso propio FeatherCore con alfa real; no añade otro fondo a la tarjeta.
    final asset = _featherCoreAssets[type];
    if (asset != null) {
      return _tile(
        context,
        Image.asset(
          asset,
          width: size * (framed ? .75 : 1),
          height: size * (framed ? .75 : 1),
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
          filterQuality: FilterQuality.medium,
        ),
        accent,
      );
    }
    if (type == FeatherCoreType.whatsappBusiness ||
        type == FeatherCoreType.personalAgent) {
      final asset = type == FeatherCoreType.whatsappBusiness
          ? 'assets/automation/whatsapp_business_icon.png'
          : 'assets/automation/whatsapp_personal_icon.png';
      return _tile(
        context,
        ClipRRect(
          borderRadius: BorderRadius.circular(size * .2),
          child: Image.asset(
            asset,
            width: size * .62,
            height: size * .62,
            fit: BoxFit.cover,
          ),
        ),
        accent,
      );
    }
    if (FeatherCoreSymbol.supports(type!)) {
      return _tile(
        context,
        FeatherCoreSymbol(
          type: type!,
          size: framed ? size * .58 : size * .88,
          color: accent,
        ),
        accent,
      );
    }
    return _tile(
      context,
      NanoGlyph(
        type: _glyphFor(type!),
        size: size * (framed ? .58 : .82),
        color: accent,
        strokeWidth: size < 32 ? 1.55 : 1.8,
      ),
      accent,
    );
  }

  Widget _tile(BuildContext context, Widget child, Color accent) => framed
      ? FeatherCoreTile(size: size, accent: accent, glow: glow, child: child)
      : SizedBox.square(
          dimension: size,
          child: Center(child: child),
        );
}
