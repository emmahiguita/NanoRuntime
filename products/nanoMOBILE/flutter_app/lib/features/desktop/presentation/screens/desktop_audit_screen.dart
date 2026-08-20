import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/kali_provider.dart';
import '../../../../core/services/package_service.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/nano_ambient_background.dart';
import '../../../../core/widgets/nano_optical_surface.dart';

class DesktopAuditScreen extends ConsumerStatefulWidget {
  const DesktopAuditScreen({super.key});

  @override
  ConsumerState<DesktopAuditScreen> createState() => _DesktopAuditScreenState();
}

class _DesktopAuditScreenState extends ConsumerState<DesktopAuditScreen> {
  final PackageService _pkg = const PackageService();
  bool _busy = false;
  String? _message;

  static const List<_DesktopAppSpec> _desktopApps = [
    _DesktopAppSpec(
      packageName: 'lxterminal',
      appId: 'lxterminal',
      label: 'LXTerminal',
      role: 'Terminal gráfica',
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
      role: 'Compresor gráfico',
      icon: Icons.unarchive_rounded,
    ),
    _DesktopAppSpec(
      packageName: 'feh',
      appId: 'feh',
      label: 'feh',
      role: 'Imágenes y fondo',
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
    return _run('Instalación gráfica NanoAI', _pkg.installGraphical);
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
          backgroundColor: colors.backgroundPrimary,
          body: Stack(
            children: [
              const Positioned.fill(
                child: NanoAmbientBackground(),
              ),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
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
                              ],
                            ),
                          ),
                          SliverToBoxAdapter(
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
                          if (_message != null)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  _message!,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
        NanoOpticalSurface(
          geometry: NanoSurfaceGeometry.circle,
          blurSigma: 10,
          borderStrength: 0.65,
          reflectionStrength: 0.50,
          accent: colors.accentSky,
          onTap: onBack,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (rect) {
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.65, 0.85, 1.0],
                colors: [
                  colors.textPrimary,
                  colors.textPrimary,
                  colors.accentSky,
                  colors.accentCyan,
                ],
              ).createShader(rect);
            },
            child: const Text(
              'Auditoría Escritorio',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        NanoOpticalSurface(
          geometry: NanoSurfaceGeometry.circle,
          blurSigma: 10,
          borderStrength: 0.65,
          reflectionStrength: 0.50,
          accent: colors.accentSky,
          onTap: onDesktop,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.desktop_windows_rounded,
              size: 20,
              color: colors.textPrimary,
            ),
          ),
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
    final colors = NanoThemeExtension.of(context).colors;
    final text = status == null
        ? 'Leyendo estado real del runtime.'
        : status!.installed
            ? status!.graphicalExtras
                ? 'Rootfs y escritorio gráfico instalados. Stage: ${status!.stage}.'
                : 'Rootfs instalado, faltan extras gráficos. Stage: ${status!.stage}.'
            : 'Rootfs gráfico pendiente. Stage: ${status!.stage}.';

    return _InfoCard(
      title: 'Estado NanoAI',
      body: text,
      trailing: NanoOpticalSurface(
        borderRadius: NanoRadius.small,
        blurSigma: 10,
        borderStrength: 0.60,
        reflectionStrength: 0.40,
        accent: colors.accentSky,
        onTap: busy ? null : onInstallGraphical,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.build_rounded, size: 14, color: colors.accentSky),
            const SizedBox(width: 4),
            Text(
              busy ? 'Procesando' : 'Reparar',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
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
      title: 'Kali / Rootfs',
      body: missingCount == 0 ? summary : '$summary. Faltan $missingCount herramientas auditadas.',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: (installed ? colors.accentMint : colors.warning).withValues(alpha: 0.15),
          border: Border.all(
            color: installed ? colors.accentMint : colors.warning,
            width: 0.8,
          ),
        ),
        child: Text(
          installed ? 'INSTALADO' : 'NO INSTALADO',
          style: TextStyle(
            fontFamily: 'Inter',
            color: installed ? colors.accentMint : colors.warning,
            fontWeight: FontWeight.w600,
            fontSize: 10.5,
            letterSpacing: 0.3,
          ),
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
  final Map<String, bool> installedApps;
  final bool busy;
  final bool desktopReady;
  final bool graphicalReady;
  final ValueChanged<String> onInstall;
  final ValueChanged<String> onLaunch;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Apps del Escritorio',
      bodyWidget: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 600 ? 2 : 1;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
    return NanoOpticalSurface(
      borderRadius: NanoRadius.small,
      blurSigma: 12,
      borderStrength: 0.65,
      reflectionStrength: 0.45,
      accent: installed ? colors.accentMint : colors.accentSky,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Icon(app.icon, color: installed ? colors.accentMint : colors.accentSky, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        app.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (installed)
                      Icon(Icons.check_circle_rounded, size: 14, color: colors.accentMint),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  installed ? 'Instalado' : app.role,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: installed ? colors.accentMint : colors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: installed ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (!installed)
            IconButton(
              tooltip: 'Instalar paquete ${app.packageName}',
              onPressed: busy ? null : () => onInstall(app.packageName),
              icon: const Icon(Icons.download_rounded, size: 20),
              color: colors.accentSky,
            ),
          IconButton(
            tooltip: graphicalReady ? 'Abrir ${app.label}' : 'Instala el escritorio primero',
            onPressed: busy || !desktopReady || !graphicalReady ? null : () => onLaunch(app.appId),
            icon: const Icon(Icons.open_in_new_rounded, size: 20),
            color: colors.textPrimary,
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
    return NanoOpticalSurface(
      borderRadius: NanoRadius.medium,
      blurSigma: 16,
      borderStrength: 0.70,
      reflectionStrength: 0.50,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          if (bodyWidget != null)
            bodyWidget!
          else
            Text(
              body ?? '',
              style: TextStyle(
                fontFamily: 'Inter',
                color: colors.textSecondary,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
        ],
      ),
    );
  }
}
