import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/app_providers.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';

/// Configuración para el entorno de Escritorio Linux móvil (Xvnc) y almacenamiento.
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
    _pwController = TextEditingController(
      text: ref.read(settingsProvider).vncPassword,
    );
  }

  @override
  void dispose() {
    _pwController.dispose();
    super.dispose();
  }

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
          ? 'Concedido — acceso a fotos, vídeos y audio'
          : 'No se pudo conceder (revisa ajustes)';
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
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _pwController,
                  obscureText: true,
                  maxLength: 8,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\x20-\x7E]')),
                  ],
                  onChanged: _applyPassword,
                  style: NanoType.body(colors.onSurface).copyWith(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Contraseña de VNC (máx. 8 caracteres)',
                    labelStyle: NanoType.caption(colors.onSurfaceVariant).copyWith(fontSize: 11.5),
                    helperText: vncProtected
                        ? 'Protección activa al iniciar Xvnc.'
                        : 'Sin contraseña, VNC inicia abierto.',
                    helperStyle: NanoType.caption(
                      vncProtected ? colors.primary : colors.onSurfaceVariant,
                    ).copyWith(fontSize: 10.5),
                    counterText: '',
                    filled: true,
                    fillColor: colors.surface.withValues(alpha: 0.45),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.35)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.35)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: colors.primary, width: 1.2),
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.25)),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Almacenamiento compartido',
                      style: NanoType.body(colors.onSurface).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'El gestor de archivos pcmanfm requiere acceso al almacenamiento.',
                      style: NanoType.caption(colors.onSurfaceVariant).copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _permBusy ? null : _requestStorage,
                      icon: const Icon(Icons.folder_rounded, size: 16),
                      label: Text(
                        _permBusy ? 'Solicitando…' : 'Permitir acceso a archivos',
                        style: NanoType.caption(colors.primary).copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        foregroundColor: colors.primary,
                        side: BorderSide(color: colors.primary.withValues(alpha: 0.35)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                    if (_permResult != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _permResult!,
                        style: NanoType.caption(
                          _permResult!.startsWith('Concedido')
                              ? colors.primary
                              : colors.error,
                        ).copyWith(fontSize: 10.5),
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
