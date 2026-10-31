// automation_agent_avatars.dart â€” Avatares squircle iOS y badge para Tus Agentes.
// QUÃ‰ HACE: Renderiza los iconos oficiales en squircles pulidos (42dp) y el badge de estado.
// CÃ“MO FUNCIONA: Usa nano_personal_owl, nano_business_owl y nano_models_owl con esquinas suaves.
// POR QUÃ‰: Presenta los agentes en lista profesional sin deformaciÃ³n ni textos superpuestos.
library;

import 'package:flutter/material.dart';

class AgentPersonalAvatar extends StatelessWidget {
  const AgentPersonalAvatar({
    super.key,
    this.size = 42.0,
    this.isDark = true,
  });

  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final squircleRadius = BorderRadius.circular(size * 0.24);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: squircleRadius,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.black.withValues(alpha: 0.08),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: squircleRadius,
        child: Image.asset(
          'assets/nano/nano_personal_owl.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

class AgentBusinessAvatar extends StatelessWidget {
  const AgentBusinessAvatar({
    super.key,
    this.size = 42.0,
    this.isDark = true,
  });

  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final squircleRadius = BorderRadius.circular(size * 0.24);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: squircleRadius,
        border: Border.all(
          color: isDark
              ? const Color(0xFF25D366).withValues(alpha: 0.35)
              : const Color(0xFF208A68).withValues(alpha: 0.25),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: squircleRadius,
        child: Image.asset(
          'assets/nano/nano_business_owl.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

class AgentModelsAvatar extends StatelessWidget {
  const AgentModelsAvatar({
    super.key,
    this.size = 42.0,
    this.isDark = true,
  });

  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final squircleRadius = BorderRadius.circular(size * 0.24);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: squircleRadius,
        border: Border.all(
          color: isDark
              ? const Color(0xFF3868E0).withValues(alpha: 0.35)
              : const Color(0xFF3868E0).withValues(alpha: 0.25),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: squircleRadius,
        child: Image.asset(
          'assets/nano/nano_models_owl.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

class AgentStatusBadge extends StatelessWidget {
  const AgentStatusBadge({
    super.key,
    required this.isActive,
    required this.isDark,
  });

  final bool isActive;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF25D366).withValues(alpha: 0.20)
            : (isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isActive
              ? const Color(0xFF25D366).withValues(alpha: 0.40)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.16)
                  : Colors.black.withValues(alpha: 0.08)),
          width: 0.6,
        ),
      ),
      child: Text(
        isActive ? 'Activo' : 'Pausado',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: isActive
              ? const Color(0xFF25D366)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.70)
                  : const Color(0xFF595960)),
        ),
      ),
    );
  }
}
