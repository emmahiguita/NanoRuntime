// nano_3d_crystal_icon.dart — Avatar oficial y profesional de Nano AI.
// QUÉ HACE: Renderiza el emblema oficial del búho (assets/nano/nano_owl.png) sobre un disco Liquid Glass.
// CÓMO FUNCIONA: Usa un contenedor circular con desenfoque óptico, borde de cristal y sombreado sutil.
// POR QUÉ: Sustituye figuras geométricas artificiales por la identidad visual profesional y soberana de Nano.
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

/// Avatar oficial de la marca Nano AI sobre cristal líquido profesional.
class NanoBrandAvatar extends StatelessWidget {
  const NanoBrandAvatar({
    super.key,
    this.size = 28,
    this.isError = false,
    this.primaryColor,
  });

  final double size;
  final bool isError;
  final Color? primaryColor;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = primaryColor ?? const Color(0xFF007AFF);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isError
            ? const Color(0xFFEF4444).withValues(alpha: 0.16)
            : const Color(0xFF0F1E36).withValues(alpha: 0.45),
        border: Border.all(
          color: isError
              ? const Color(0xFFEF4444).withValues(alpha: 0.50)
              : effectiveColor.withValues(alpha: 0.35),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: (isError ? const Color(0xFFEF4444) : effectiveColor)
                .withValues(alpha: isError ? 0.25 : 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: isError
            ? Icon(
                CupertinoIcons.exclamationmark_circle_fill,
                size: size * 0.62,
                color: const Color(0xFFEF4444),
              )
            : ClipOval(
                child: Image.asset(
                  'assets/nano/nano_owl.png',
                  width: size * 0.74,
                  height: size * 0.74,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => Icon(
                    CupertinoIcons.sparkles,
                    size: size * 0.55,
                    color: effectiveColor,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Adaptador compatible que delega en [NanoBrandAvatar].
class Nano3dCrystalIcon extends StatelessWidget {
  const Nano3dCrystalIcon({
    super.key,
    this.size = 28,
    this.isGlowing = true,
    this.primaryColor = const Color(0xFF007AFF),
    this.secondaryColor = const Color(0xFF1E88E5),
  });

  final double size;
  final bool isGlowing;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    return NanoBrandAvatar(
      size: size,
      isError: primaryColor.toARGB32() == const Color(0xFFEF4444).toARGB32(),
      primaryColor: primaryColor,
    );
  }
}
