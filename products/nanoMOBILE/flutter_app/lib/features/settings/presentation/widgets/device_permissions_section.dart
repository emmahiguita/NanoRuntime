import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';

/// Centro de gestión de permisos del dispositivo estilo iOS.
class DevicePermissionsSection extends StatefulWidget {
  const DevicePermissionsSection({super.key});

  @override
  State<DevicePermissionsSection> createState() =>
      _DevicePermissionsSectionState();
}

class _DevicePermissionsSectionState extends State<DevicePermissionsSection>
    with WidgetsBindingObserver {
  final _runtime = NanoRuntimeApi.instance;
  final Set<String> _attemptedSpecial = {};
  Map<String, bool> _status = const {};
  bool _busy = false;
  bool _grantFlow = false;
  bool _specialPanelOpen = false;
  String? _message;

  static const _labels = <String, (String, IconData)>{
    'microphone': ('Micrófono para dictado', Icons.mic_rounded),
    'media': ('Fotos, vídeo y audio', Icons.perm_media_rounded),
    'accessibility': ('Control asistido de UI', Icons.touch_app_rounded),
    'notificationAccess': (
      'Lectura de notificaciones',
      Icons.notifications_active_rounded,
    ),
    'allFiles': ('Acceso a modelos GGUF', Icons.folder_open_rounded),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(_refresh);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _specialPanelOpen = false;
      _refresh().then((_) {
        if (_grantFlow && mounted) _openNextSpecialPermission();
      });
    }
  }

  Future<void> _refresh() async {
    final raw = await _runtime.devicePermissionStatus();
    if (!mounted) return;
    setState(() {
      _status = {for (final key in _labels.keys) key: raw[key] == true};
      _busy = false;
    });
  }

  Future<void> _grantAll() async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() {
      _busy = true;
      _grantFlow = true;
      _attemptedSpecial.clear();
      _message = 'Android solicitará los accesos pendientes.';
    });

    if (_status['microphone'] != true || _status['media'] != true) {
      await _runtime.requestRuntimePermissions();
      await _refresh();
    }
    await _openNextSpecialPermission();
  }

  Future<void> _openNextSpecialPermission() async {
    if (!_grantFlow || !mounted || _specialPanelOpen) return;
    final pending = <(String, Future<bool> Function())>[
      ('accessibility', _runtime.openAccessibilitySettings),
      ('notificationAccess', _runtime.openNotificationAccessSettings),
      ('allFiles', _runtime.openAllFilesAccessSettings),
    ];
    for (final (key, open) in pending) {
      if (_status[key] != true && !_attemptedSpecial.contains(key)) {
        _attemptedSpecial.add(key);
        _specialPanelOpen = true;
        setState(() {
          _busy = false;
          _message = 'Activa “${_labels[key]!.$1}” y vuelve.';
        });
        final opened = await open();
        if (!opened && mounted) {
          _specialPanelOpen = false;
          setState(() => _message = 'Android no pudo abrir ese panel.');
          continue;
        }
        return;
      }
    }
    _grantFlow = false;
    final allGranted = _status.values.every((granted) => granted);
    setState(() {
      _busy = false;
      _message = allGranted
          ? 'Todos los permisos están activos.'
          : 'Configuración finalizada.';
    });
  }

  Future<void> _openSingle(String key) async {
    HapticFeedback.selectionClick();
    final opened = switch (key) {
      'microphone' || 'media' => await _runtime.requestRuntimePermissions(),
      'accessibility' => await _runtime.openAccessibilitySettings(),
      'notificationAccess' => await _runtime.openNotificationAccessSettings(),
      'allFiles' => await _runtime.openAllFilesAccessSettings(),
      _ => await _runtime.openAppPermissionSettings(),
    };
    if (!opened && mounted) {
      setState(() => _message = 'Android no pudo abrir la solicitud.');
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final granted = _status.values.where((value) => value).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AutomationSectionLabel('Permisos del dispositivo'),
        AutomationSurfaceCard(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Accesos del sistema',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: colors.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.3),
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        '$granted/${_labels.length} activos',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: granted == _labels.length
                              ? colors.primary
                              : colors.onSurfaceVariant,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final entry in _labels.entries) ...[
                  InkWell(
                    onTap: _busy ? null : () => _openSingle(entry.key),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 7,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            entry.value.$2,
                            size: 16,
                            color: _status[entry.key] == true
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.value.$1,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: colors.onSurface,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceVariant.withValues(
                                alpha: 0.40,
                              ),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: colors.outlineVariant.withValues(
                                  alpha: 0.25,
                                ),
                                width: 0.6,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_status[entry.key] == true) ...[
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  _status[entry.key] == true
                                      ? 'Activo'
                                      : 'Pendiente',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _status[entry.key] == true
                                        ? colors.primary
                                        : colors.onSurfaceVariant,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (granted < _labels.length) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _grantAll,
                      icon: const Icon(Icons.verified_user_rounded, size: 15),
                      label: Text(
                        _busy ? 'Verificando…' : 'Conceder permisos pendientes',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: colors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Todos los accesos concedidos',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurfaceVariant,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _message!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: colors.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
