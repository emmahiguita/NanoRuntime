import 'package:flutter/material.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';

import 'package:nanoai/core/widgets/nano_section.dart';

/// Centro honesto de permisos: Android siempre conserva la decisión final.
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
    'media': ('Fotos, vídeo y audio compartidos', Icons.perm_media_rounded),
    'accessibility': (
      'Control asistido de la interfaz',
      Icons.touch_app_rounded,
    ),
    'notificationAccess': (
      'Lectura y respuesta de notificaciones',
      Icons.notifications_active_rounded,
    ),
    'allFiles': ('Escaneo local de modelos GGUF', Icons.folder_open_rounded),
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
    setState(() {
      _busy = true;
      _grantFlow = true;
      _attemptedSpecial.clear();
      _message = 'Android solicitará únicamente los accesos que faltan.';
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
          _message = 'Activa “${_labels[key]!.$1}” y vuelve a NanoAI.';
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
          ? 'Todos los permisos necesarios están concedidos.'
          : 'Configuración recorrida. Los permisos denegados siguen desactivados.';
    });
  }

  Future<void> _openSingle(String key) async {
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
        SectionHeader(
          'Permisos del dispositivo',
          Icons.admin_panel_settings_rounded,
          colors: colors,
        ),
        SettingsCard(
          shadow: NanoShadows.card(colors),
          colors: colors,
          child: Padding(
            padding: const EdgeInsets.all(NanoSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$granted/${_labels.length} accesos habilitados',
                  style: NanoType.body(colors.onSurface),
                ),
                const SizedBox(height: NanoSpacing.sm),
                for (final entry in _labels.entries)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(entry.value.$2),
                    title: Text(entry.value.$1),
                    trailing: Icon(
                      _status[entry.key] == true
                          ? Icons.check_circle_rounded
                          : Icons.chevron_right_rounded,
                      color: _status[entry.key] == true
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    onTap: _busy ? null : () => _openSingle(entry.key),
                  ),
                const SizedBox(height: NanoSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _grantAll,
                    icon: const Icon(Icons.verified_user_rounded),
                    label: Text(_busy ? 'Verificando…' : 'Conceder pendientes'),
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: NanoSpacing.sm),
                  Text(
                    _message!,
                    style: NanoType.caption(colors.onSurfaceVariant),
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
