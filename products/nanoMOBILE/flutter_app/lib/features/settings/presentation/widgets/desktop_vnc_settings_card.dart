import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/app_providers.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';

/// QUÉ HACE:
/// Tarjeta de configuración para el entorno de Escritorio Linux móvil (Xvnc)
/// y gestión de permisos de almacenamiento compartido para el gestor de archivos.
///
/// CÓMO FUNCIONA:
/// Permite establecer y persistir la contraseña VNC (máximo 8 bytes UTF-8)
/// y solicitar en tiempo de ejecución el acceso al almacenamiento local de Android.
///
/// POR QUÉ:
/// Garantiza el control de acceso al escritorio remoto y el ciclo de vida
/// limpio del controlador de texto evitando procesos zombis o fugas de memoria.
class DesktopVncSettingsCard extends ConsumerStatefulWidget {
  const DesktopVncSettingsCard({super.key});

  @override
  ConsumerState<DesktopVncSettingsCard> createState() =>
      _DesktopVncSettingsCardState();
}

class _DesktopVncSettingsCardState
    extends ConsumerState<DesktopVncSettingsCard> {
  late final TextEditingController _pwController;
  bool _permBusy = false;
  String? _permResult;

  @override
  void initState() {
    super.initState();
    // Inicialización del controlador con el valor persistido actual
    _pwController = TextEditingController(
      text: ref.read(settingsProvider).vncPassword,
    );
  }

  @override
  void dispose() {
    // CICLO DE VIDA: Liberación obligatoria para evitar memory leaks
    _pwController.dispose();
    super.dispose();
  }

  /// Recorta al límite estricto de 8 bytes requerido por el protocolo RFB/VNC.
  void _applyPassword(String v) {
    var trimmed = v;
    while (utf8.encode(trimmed).length > 8 && trimmed.isNotEmpty) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed != v) {
      _pwController.value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    }
    ref.read(settingsProvider.notifier).setVncPassword(trimmed);
  }

  /// Android decide el permiso; un error del canal no deja el botón bloqueado.
  Future<void> _requestStorage() async {
    setState(() {
      _permBusy = true;
      _permResult = null;
    });

    bool ok;
    try {
      ok = await NanoRuntimeApi.instance.requestStoragePermission();
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;

    setState(() {
      _permBusy = false;
      _permResult = ok
          ? 'Concedido — pcmanfm verá tus fotos, vídeos y audio'
          : 'No se pudo conceder (revisa ajustes del sistema Android)';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final vncProtected = ref.watch(settingsProvider).vncPassword.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AutomationSectionLabel('Escritorio Linux'),
        AutomationSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(NanoSpacing.md),
                child: TextField(
                  controller: _pwController,
                  obscureText: true,
                  maxLength: 8,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\x20-\x7E]')),
                  ],
                  onChanged: _applyPassword,
                  style: NanoType.body(colors.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Contraseña de VNC (máx. 8 caracteres)',
                    labelStyle: NanoType.caption(colors.onSurfaceVariant),
                    helperText: vncProtected
                        ? 'Protección activa al iniciar Xvnc.'
                        : 'Sin contraseña, VNC inicia abierto.',
                    helperStyle: NanoType.caption(
                      vncProtected ? colors.primary : colors.onSurfaceVariant,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: colors.surface.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.3)),
              Padding(
                padding: const EdgeInsets.all(NanoSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Almacenamiento compartido',
                      style: NanoType.body(colors.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'El gestor de archivos (pcmanfm) de Linux necesita este permiso.',
                      style: NanoType.caption(colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: NanoSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _permBusy ? null : _requestStorage,
                      icon: const Icon(Icons.folder_rounded, size: 18),
                      label: Text(
                        _permBusy ? 'Solicitando…' : 'Permitir acceso a archivos',
                        style: NanoType.caption(colors.primary),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.primary,
                        side: BorderSide(color: colors.primary.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    if (_permResult != null) ...[
                      const SizedBox(height: NanoSpacing.xs),
                      Text(
                        _permResult!,
                        style: NanoType.caption(
                          _permResult!.startsWith('Concedido')
                              ? colors.primary
                              : colors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
