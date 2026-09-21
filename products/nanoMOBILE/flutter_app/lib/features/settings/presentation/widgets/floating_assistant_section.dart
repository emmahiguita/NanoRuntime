// floating_assistant_section.dart — Control del Asistente Flotante fuera de Nano AI (estilo Gemini).
// QUÉ HACE: Permite al usuario activar o desactivar el búho flotante del sistema sobre otras apps.
// CÓMO FUNCIONA: Consulta y solicita SYSTEM_ALERT_WINDOW vía NanoFloatingSystem y gestiona el ciclo del servicio.
// POR QUÉ: Otorga al usuario control directo y transparente para usar la IA en WhatsApp, navegador o cualquier app.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../chat/nano_everywhere/nano_floating_system.dart';

class FloatingAssistantSection extends StatefulWidget {
  const FloatingAssistantSection({super.key});

  @override
  State<FloatingAssistantSection> createState() => _FloatingAssistantSectionState();
}

class _FloatingAssistantSectionState extends State<FloatingAssistantSection>
    with WidgetsBindingObserver {
  final _system = const NanoFloatingSystem();
  bool _isActive = false;
  bool _hasPermission = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    final permitted = await _system.permitted;
    if (mounted) {
      setState(() {
        _hasPermission = permitted;
        if (!permitted) _isActive = false;
      });
    }
  }

  Future<void> _toggleAssistant(bool enable) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.selectionClick();

    try {
      if (enable) {
        if (!_hasPermission) {
          await _system.requestPermission();
          return;
        }
        final ok = await _system.show();
        if (mounted) setState(() => _isActive = ok);
      } else {
        await _system.hide();
        if (mounted) setState(() => _isActive = false);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Semantics(
      container: true,
      label: 'Asistente flotante fuera de Nano AI',
      child: Container(
        padding: const EdgeInsets.all(NanoSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isActive
                ? const Color(0xFF10B981).withValues(alpha: 0.5)
                : colors.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF38BDF8).withValues(alpha: 0.25),
                    const Color(0xFF10B981).withValues(alpha: 0.25),
                  ],
                ),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF38BDF8), size: 22),
            ),
            const SizedBox(width: NanoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Búho Flotante (Tipo Gemini)',
                    style: NanoType.body(colors.onSurface).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _isActive
                        ? 'Activo: Toca el búho en pantalla para consultar desde cualquier app.'
                        : 'Accede a Nano AI fuera de la app con el asistente en pantalla.',
                    style: NanoType.caption(colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: NanoSpacing.sm),
            Switch(
              value: _isActive,
              onChanged: _busy ? null : _toggleAssistant,
              activeThumbColor: const Color(0xFF10B981),
            ),
          ],
        ),
      ),
    );
  }
}
