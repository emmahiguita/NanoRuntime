import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../chat/nano_everywhere/nano_floating_system.dart';

/// Control del Asistente Flotante fuera de Nano AI estilo iOS.
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
    try {
      final permitted = await _system.permitted;
      final active = permitted && await _system.active;
      if (mounted) {
        setState(() {
          _hasPermission = permitted;
          _isActive = active;
        });
      }
    } catch (_) {
      if (mounted) _showError();
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
    } catch (_) {
      if (mounted) _showError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('No se pudo actualizar el asistente flotante.')),
  );

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Semantics(
      container: true,
      label: 'Asistente flotante fuera de Nano AI',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isActive
                ? colors.primary.withValues(alpha: 0.5)
                : colors.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    colors.primary.withValues(alpha: 0.25),
                    const Color(0xFF10B981).withValues(alpha: 0.25),
                  ],
                ),
                border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
              ),
              child: Icon(Icons.auto_awesome_rounded, color: colors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Asistente flotante',
                    style: NanoType.body(colors.onSurface).copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _isActive
                        ? 'Activo: Toca el orbe en pantalla para consultar desde cualquier app.'
                        : 'Accede a Nano AI fuera de la app con el orbe interactivo.',
                    style: NanoType.caption(colors.onSurfaceVariant).copyWith(
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Transform.scale(
              scale: 0.85,
              child: Switch(
                value: _isActive,
                onChanged: _busy ? null : _toggleAssistant,
                activeThumbColor: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
