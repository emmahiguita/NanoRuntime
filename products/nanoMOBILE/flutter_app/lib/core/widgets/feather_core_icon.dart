import 'package:flutter/material.dart';

/// Tipos de iconos canónicos del sistema FeatherCore.
/// Basados en la especificación visual "Nano AI — Concepto FeatherCore".
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

/// Widget de icono profesional FeatherCore con contenedor de cristal líquido,
/// curvatura squircle orgánica, borde con reflejo y fondo completamente transparente.
class FeatherCoreIcon extends StatelessWidget {
  const FeatherCoreIcon({
    super.key,
    required this.type,
    this.size = 42,
    this.accentColor,
    this.glow = false,
  })  : icon = null,
        customChild = null;

  const FeatherCoreIcon.custom({
    super.key,
    required this.icon,
    this.size = 42,
    this.accentColor,
    this.glow = false,
  })  : type = null,
        customChild = null;

  const FeatherCoreIcon.builder({
    super.key,
    required this.customChild,
    this.size = 42,
    this.accentColor,
    this.glow = false,
  })  : type = null,
        icon = null;

  final FeatherCoreType? type;
  final IconData? icon;
  final Widget? customChild;
  final double size;
  final Color? accentColor;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryAccent = accentColor ??
        (isDark ? const Color(0xFFFF8C2A) : const Color(0xFFFF6D00));
    final borderRadius = BorderRadius.circular(size * 0.28);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0x401E293B),
                  const Color(0x280F172A),
                ]
              : [
                  const Color(0xFFFFFFFF),
                  const Color(0xFFF1F5F9),
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.18)
              : const Color(0xFFE2E8F0),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0x0C0F172A),
            blurRadius: size * 0.20,
            offset: Offset(0, size * 0.05),
          ),
          if (glow)
            BoxShadow(
              color: primaryAccent.withValues(alpha: isDark ? 0.30 : 0.20),
              blurRadius: size * 0.35,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Reflejo óptico superior de cristal
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size * 0.45,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.70),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Glifo central
            _buildGlyph(context, isDark, primaryAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildGlyph(BuildContext context, bool isDark, Color accent) {
    if (customChild != null) return customChild!;

    if (icon != null) {
      return Icon(icon, color: accent, size: size * 0.52);
    }

    final glyphSize = size * 0.56;

    switch (type!) {
      case FeatherCoreType.whatsappBusiness:
        return _WhatsAppBusinessGlyph(size: glyphSize, accent: accent, isDark: isDark);
      case FeatherCoreType.notifications:
        return Icon(Icons.notifications_active_outlined, color: accent, size: glyphSize);
      case FeatherCoreType.settings:
        return Icon(Icons.settings_outlined, color: accent, size: glyphSize);
      case FeatherCoreType.devTools:
        return Icon(Icons.developer_mode_rounded, color: accent, size: glyphSize);
      case FeatherCoreType.chat:
        return Icon(Icons.chat_bubble_outline_rounded, color: accent, size: glyphSize);
      case FeatherCoreType.terminal:
        return Icon(Icons.terminal_rounded, color: accent, size: glyphSize);
      case FeatherCoreType.linux:
        return Icon(Icons.laptop_chromebook_rounded, color: accent, size: glyphSize);
      case FeatherCoreType.automation:
        return Icon(Icons.account_tree_outlined, color: accent, size: glyphSize);
      case FeatherCoreType.files:
        return Icon(Icons.folder_outlined, color: accent, size: glyphSize);
      case FeatherCoreType.models:
        return Icon(Icons.hub_outlined, color: accent, size: glyphSize);
      case FeatherCoreType.system:
        return Icon(Icons.memory_rounded, color: accent, size: glyphSize);
      case FeatherCoreType.vision:
        return Icon(Icons.remove_red_eye_outlined, color: accent, size: glyphSize);
      case FeatherCoreType.network:
        return Icon(Icons.language_rounded, color: accent, size: glyphSize);
      case FeatherCoreType.security:
        return Icon(Icons.verified_user_outlined, color: accent, size: glyphSize);
      case FeatherCoreType.battery:
        return Icon(Icons.battery_charging_full_rounded, color: accent, size: glyphSize);
      case FeatherCoreType.assistant:
        return Icon(Icons.auto_awesome_rounded, color: accent, size: glyphSize);
      case FeatherCoreType.documents:
        return Icon(Icons.description_outlined, color: accent, size: glyphSize);
      case FeatherCoreType.mic:
        return Icon(Icons.mic_none_rounded, color: accent, size: glyphSize);
      case FeatherCoreType.calendar:
        return Icon(Icons.calendar_month_outlined, color: accent, size: glyphSize);
      case FeatherCoreType.home:
        return Icon(Icons.home_outlined, color: accent, size: glyphSize);
      case FeatherCoreType.search:
        return Icon(Icons.search_rounded, color: accent, size: glyphSize);
      case FeatherCoreType.code:
        return Icon(Icons.code_rounded, color: accent, size: glyphSize);
      case FeatherCoreType.analytics:
        return Icon(Icons.insights_rounded, color: accent, size: glyphSize);
      case FeatherCoreType.cloud:
        return Icon(Icons.cloud_outlined, color: accent, size: glyphSize);
      case FeatherCoreType.camera:
        return Icon(Icons.photo_camera_outlined, color: accent, size: glyphSize);
      case FeatherCoreType.businessCatalog:
        return Icon(Icons.storefront_outlined, color: accent, size: glyphSize);
      case FeatherCoreType.payments:
        return Icon(Icons.payment_rounded, color: accent, size: glyphSize);
      case FeatherCoreType.delivery:
        return Icon(Icons.local_shipping_outlined, color: accent, size: glyphSize);
      case FeatherCoreType.hours:
        return Icon(Icons.schedule_rounded, color: accent, size: glyphSize);
      case FeatherCoreType.location:
        return Icon(Icons.location_on_outlined, color: accent, size: glyphSize);
      case FeatherCoreType.rules:
        return Icon(Icons.rule_rounded, color: accent, size: glyphSize);
      case FeatherCoreType.personalAgent:
        return Icon(Icons.smart_toy_outlined, color: accent, size: glyphSize);
    }
  }
}

/// Glifo vector FeatherCore de WhatsApp Business con transparencia total.
/// Dibuja la burbuja con cola y el emblema central sin fondos oscuros o bordes opacos.
class _WhatsAppBusinessGlyph extends StatelessWidget {
  const _WhatsAppBusinessGlyph({
    required this.size,
    required this.accent,
    required this.isDark,
  });

  final double size;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF25D366);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.chat_bubble_rounded,
            size: size,
            color: isDark ? green.withValues(alpha: 0.90) : green,
          ),
          Positioned(
            child: Text(
              'B',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.48,
                height: 1.0,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
