import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/kali_provider.dart';
import '../../../../core/services/package_service.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_components.dart';

class DesktopAuditScreen extends ConsumerStatefulWidget {
  const DesktopAuditScreen({super.key});

  @override
  ConsumerState<DesktopAuditScreen> createState() => _DesktopAuditScreenState();
}

class _DesktopAuditScreenState extends ConsumerState<DesktopAuditScreen> {
  final PackageService _pkg = const PackageService();
  bool _busy = false;
  String? _message;

  // Apps esenciales del escritorio — trim 2026-08-14: fuera chromium (no
  // estaba en DESKTOP_PACKAGES — botón instalaba algo que el repos no
  // tenía), firefox, thunar y xfce4-terminal (redundantes: pcmanfm y
  // lxterminal ya cubren archivos y terminal, y ya no se instalan por
  // defecto). El appId coincide con la allowlist real del manager.
  static const List<_DesktopAppSpec> _desktopApps = [
    _DesktopAppSpec(
      packageName: 'lxterminal',
      appId: 'lxterminal',
      label: 'LXTerminal',
      role: 'Terminal grafica',
      icon: Icons.terminal_rounded,
    ),
    _DesktopAppSpec(
      packageName: 'pcmanfm',
      appId: 'pcmanfm',
      label: 'PCManFM',
      role: 'Archivos y escritorio',
      icon: Icons.folder_rounded,
    ),
    _DesktopAppSpec(
      packageName: 'mousepad',
      appId: 'mousepad',
      label: 'Mousepad',
      role: 'Editor de texto',
      icon: Icons.edit_note_rounded,
    ),
    _DesktopAppSpec(
      packageName: 'xpdf',
      appId: 'xpdf',
      label: 'Xpdf',
      role: 'Visor PDF',
      icon: Icons.description_rounded,
    ),
    _DesktopAppSpec(
      packageName: 'file-roller',
      appId: 'file-roller',
      label: 'File Roller',
      role: 'Compresor grafico',
      icon: Icons.unarchive_rounded,
    ),
    _DesktopAppSpec(
      packageName: 'feh',
      appId: 'feh',
      label: 'feh',
      role: 'Imagenes y fondo',
      icon: Icons.image_rounded,
    ),
  ];

  Future<void> _run(String label, Future<bool> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = '$label...';
    });

    final ok = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = ok ? '$label: completado.' : '$label: fallo. Revisa red, espacio o repositorios Termux.';
    });
  }

  Future<void> _installGraphical() {
    return _run('Instalacion grafica NanoAI', _pkg.installGraphical);
  }

  Future<void> _installPackage(String packageName) {
    return _run('Instalando $packageName', () => _pkg.installPackages([packageName]));
  }

  Future<void> _launchApp(String appId) {
    return _run('Abriendo $appId', () => _pkg.launchApp(appId));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DesktopStatus>(
      future: _pkg.getDesktopStatus(),
      builder: (context, snapshot) {
        final colors = NanoThemeExtension.of(context).colors;
        final status = snapshot.data;
        final kali = ref.watch(kaliProvider);
        final missing = kali?.missingTools() ?? const <String>[];
        final desktopReady = status?.reachable == true;
        final graphicalReady = status?.graphicalExtras == true;

        return Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    onBack: () => context.go('/dashboard'),
                    onDesktop: () => context.go('/desktop'),
                  ),
                  const SizedBox(height: 12),
                  _StatusCard(
                    status: status,
                    busy: _busy,
                    onInstallGraphical: _installGraphical,
                  ),
                  const SizedBox(height: 12),
                  _KaliCard(
                    installed: kali?.isInstalled == true,
                    summary: kali == null ? 'Kali no disponible.' : kali.coverageSummary(),
                    missingCount: missing.length,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _AppsPanel(
                      apps: _desktopApps,
                      installedApps: status?.apps ?? const {},
                      busy: _busy,
                      desktopReady: desktopReady,
                      graphicalReady: graphicalReady,
                      onInstall: _installPackage,
                      onLaunch: _launchApp,
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(_message!, style: TextStyle(color: colors.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DesktopAppSpec {
  const _DesktopAppSpec({
    required this.packageName,
    required this.appId,
    required this.label,
    required this.role,
    required this.icon,
  });

  final String packageName;
  final String appId;
  final String label;
  final String role;
  final IconData icon;
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onDesktop});

  final VoidCallback onBack;
  final VoidCallback onDesktop;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Row(
      children: [
        IconButton(
          tooltip: 'Inicio',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          color: colors.onSurface,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'NanoAI - Escritorio Linux',
            style: NanoType.display(colors.onSurface),
          ),
        ),
        IconButton(
          tooltip: 'Abrir escritorio',
          onPressed: onDesktop,
          icon: const Icon(Icons.desktop_windows_rounded),
          color: colors.onSurface,
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
    required this.busy,
    required this.onInstallGraphical,
  });

  final DesktopStatus? status;
  final bool busy;
  final VoidCallback onInstallGraphical;

  @override
  Widget build(BuildContext context) {
    final text = status == null
        ? 'Leyendo estado real del runtime.'
        : status!.installed
            ? status!.graphicalExtras
                ? 'Rootfs y escritorio grafico instalados. Stage: ${status!.stage}.'
                : 'Rootfs instalado, faltan extras graficos. Stage: ${status!.stage}.'
            : 'Rootfs grafico pendiente. Stage: ${status!.stage}.';

    return _InfoCard(
      title: 'Estado NanoAI',
      body: text,
      trailing: TextButton.icon(
        onPressed: busy ? null : onInstallGraphical,
        icon: const Icon(Icons.build_rounded),
        label: Text(busy ? 'Procesando' : 'Reparar'),
      ),
    );
  }
}

class _KaliCard extends StatelessWidget {
  const _KaliCard({
    required this.installed,
    required this.summary,
    required this.missingCount,
  });

  final bool installed;
  final String summary;
  final int missingCount;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return _InfoCard(
      title: 'Kali / rootfs',
      body: missingCount == 0 ? summary : '$summary. Faltan $missingCount herramientas auditadas.',
      trailing: Text(
        installed ? 'INSTALADO' : 'NO INSTALADO',
        style: TextStyle(
          color: installed ? colors.success : colors.warning,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AppsPanel extends StatelessWidget {
  const _AppsPanel({
    required this.apps,
    required this.installedApps,
    required this.busy,
    required this.desktopReady,
    required this.graphicalReady,
    required this.onInstall,
    required this.onLaunch,
  });

  final List<_DesktopAppSpec> apps;

  /// appId → binario presente en disco (verdad real del backend).
  final Map<String, bool> installedApps;
  final bool busy;
  final bool desktopReady;
  final bool graphicalReady;
  final ValueChanged<String> onInstall;
  final ValueChanged<String> onLaunch;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Apps reales del escritorio',
      bodyWidget: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720 ? 2 : 1;
          return GridView.builder(
            itemCount: apps.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: 88,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final app = apps[index];
              return _AppTile(
                app: app,
                installed: installedApps[app.appId] == true,
                busy: busy,
                desktopReady: desktopReady,
                graphicalReady: graphicalReady,
                onInstall: onInstall,
                onLaunch: onLaunch,
              );
            },
          );
        },
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.app,
    required this.installed,
    required this.busy,
    required this.desktopReady,
    required this.graphicalReady,
    required this.onInstall,
    required this.onLaunch,
  });

  final _DesktopAppSpec app;
  final bool installed;
  final bool busy;
  final bool desktopReady;
  final bool graphicalReady;
  final ValueChanged<String> onInstall;
  final ValueChanged<String> onLaunch;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(app.icon, color: colors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(app.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    if (installed)
                      Icon(Icons.check_circle_rounded, size: 14, color: colors.success),
                  ],
                ),
                const SizedBox(height: 4),
                Text(installed ? 'Instalado' : app.role,
                    style: TextStyle(
                      color: installed
                          ? colors.success
                          : colors.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: installed ? FontWeight.w600 : FontWeight.w400,
                    )),
              ],
            ),
          ),
          if (!installed)
            IconButton(
              tooltip: 'Instalar paquete ${app.packageName}',
              onPressed: busy ? null : () => onInstall(app.packageName),
              icon: const Icon(Icons.download_rounded),
              color: colors.onSurfaceVariant,
            ),
          IconButton(
            tooltip: graphicalReady ? 'Abrir ${app.label}' : 'Instala el escritorio primero',
            onPressed: busy || !desktopReady || !graphicalReady ? null : () => onLaunch(app.appId),
            icon: const Icon(Icons.open_in_new_rounded),
            color: colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, this.body, this.bodyWidget, this.trailing});

  final String title;
  final String? body;
  final Widget? bodyWidget;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return NanoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          if (bodyWidget != null)
            Expanded(child: bodyWidget!)
          else
            Text(body ?? '', style: NanoType.body(colors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
