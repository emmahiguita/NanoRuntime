import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../automation/presentation/automation_visual_theme.dart';
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
    const SnackBar(
      content: Text(
        'No se pudo actualizar el asistente flotante.',
        style: TextStyle(fontFamily: 'Inter', decoration: TextDecoration.none),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AutomationSectionLabel('Asistente superpuesto'),
        AutomationSurfaceCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surfaceVariant.withValues(alpha: 0.50),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.30),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: colors.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asistente flotante',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _isActive
                            ? 'Activo: Orbe en pantalla para consultar desde cualquier app.'
                            : 'Accede a Nano AI fuera de la app con el orbe interactivo.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
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
        ),
      ],
    );
  }
}
