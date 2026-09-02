import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/linux/linux_distribution.dart';
import '../../../../core/linux/linux_distribution_registry.dart';
import '../../../../core/linux/linux_init.dart';
import '../../../../core/providers/kali_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_transitions.dart';
import '../../../../core/widgets/nano_ambient_background.dart';
import '../../../../core/widgets/nano_optical_surface.dart';

/// Dashboard nativo Mobile Linux Mode (White Optical Glass).
class MobileLinuxScreen extends ConsumerStatefulWidget {
  const MobileLinuxScreen({super.key});

  @override
  ConsumerState<MobileLinuxScreen> createState() => _MobileLinuxScreenState();
}

class _MobileLinuxScreenState extends ConsumerState<MobileLinuxScreen> {
  final LinuxDistributionRegistry _registry =
      LinuxDistributionRegistry.instance;
  bool _kaliRegistered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerKaliIfNeeded();
    });
  }

  void _registerKaliIfNeeded() {
    if (_kaliRegistered) return;

    final kaliManager = ref.read(kaliProvider);
    if (kaliManager != null) {
      registerKaliDistribution(kaliManager);
      _kaliRegistered = true;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_kaliRegistered) {
      _registerKaliIfNeeded();
    }

    final colors = NanoThemeExtension.of(context).colors;

    return Stack(
      children: [
        const Positioned.fill(child: NanoAmbientBackground()),
        Column(
          children: [
            _buildHeader(context, colors),
            Expanded(child: _buildBody(context, colors)),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, NanoColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // Retroceso: /linux es ruta empujada — botón visible para volver.
          IconButton(
            tooltip: 'Atrás',
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nano Linux',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Entorno y contenedores locales',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          NanoOpticalSurface(
            geometry: NanoSurfaceGeometry.circle,
            blurSigma: 10,
            borderStrength: 0.65,
            reflectionStrength: 0.50,
            accent: colors.accentSky,
            onTap: () => context.push('/desktop'),
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
          const SizedBox(width: 8),
          NanoOpticalSurface(
            geometry: NanoSurfaceGeometry.circle,
            blurSigma: 10,
            borderStrength: 0.65,
            reflectionStrength: 0.50,
            accent: colors.accentCyan,
            onTap: () => context.push('/settings'),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.settings_rounded,
                size: 20,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, NanoColors colors) {
    final distributions = _registry.getAllDistributions();

    if (distributions.isEmpty) {
      return Center(
        child: Text(
          'No hay distribuciones disponibles',
          style: TextStyle(fontFamily: 'Inter', color: colors.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: distributions.length,
            itemBuilder: (context, index) {
              final dist = distributions[index];
              return _DistributionCard(
                distribution: dist,
                onTap: () => _handleDistributionTap(dist),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleDistributionTap(LinuxDistribution dist) async {
    final isInstalled = await dist.isInstalled();
    if (!isInstalled) {
      _showInstallDialog(dist);
    } else {
      _showDistributionOptions(dist);
    }
  }

  void _showInstallDialog(LinuxDistribution dist) {
    final colors = NanoThemeExtension.of(context).colors;
    showNanoModalDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.backgroundElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Instalar ${dist.name}',
          style: TextStyle(
            fontFamily: 'Inter',
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Se descargará el rootfs de ${dist.name} (${dist.architecture}). '
          'Esto requiere conexión a internet.',
          style: TextStyle(fontFamily: 'Inter', color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(
                fontFamily: 'Inter',
                color: colors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _installDistribution(dist);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accentCyan,
              foregroundColor: colors.textPrimary,
            ),
            child: const Text('Instalar'),
          ),
        ],
      ),
    );
  }

  void _showDistributionOptions(LinuxDistribution dist) {
    final colors = NanoThemeExtension.of(context).colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colors.backgroundElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OptionTile(
              icon: Icons.terminal_rounded,
              title: 'Abrir Terminal',
              onTap: () {
                Navigator.pop(context);
                if (dist.id == 'kali') {
                  context.push('/terminal/shell?cmd=kali%20shell');
                } else {
                  context.push('/terminal/shell');
                }
              },
            ),
            const SizedBox(height: 8),
            _OptionTile(
              icon: Icons.desktop_windows_rounded,
              title: 'Abrir Desktop (VNC)',
              onTap: () {
                Navigator.pop(context);
                context.push('/desktop');
              },
            ),
            const SizedBox(height: 8),
            _OptionTile(
              icon: Icons.settings_applications_rounded,
              title: 'Info del sistema',
              onTap: () async {
                Navigator.pop(context);
                final info = await dist.getInfo();
                if (mounted) {
                  _showDistributionInfo(dist, info);
                }
              },
            ),
            const SizedBox(height: 8),
            _OptionTile(
              icon: Icons.delete_rounded,
              title: 'Desinstalar',
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _confirmUninstall(dist);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDistributionInfo(
    LinuxDistribution dist,
    LinuxDistributionInfo info,
  ) {
    final colors = NanoThemeExtension.of(context).colors;
    showNanoModalDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.backgroundElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          dist.name,
          style: TextStyle(
            fontFamily: 'Inter',
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow('ID', info.id),
            _InfoRow('Versión', info.version),
            _InfoRow('Pretty Name', info.prettyName),
            _InfoRow('ID Like', info.idLike),
            _InfoRow('Arquitectura', dist.architecture),
            _InfoRow('Package Backend', dist.packageBackend),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cerrar',
              style: TextStyle(
                fontFamily: 'Inter',
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmUninstall(LinuxDistribution dist) {
    final colors = NanoThemeExtension.of(context).colors;
    showNanoModalDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.backgroundElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Desinstalar ${dist.name}',
          style: TextStyle(
            fontFamily: 'Inter',
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Esto eliminará todos los archivos de ${dist.name}. '
          'La acción no se puede deshacer.',
          style: TextStyle(fontFamily: 'Inter', color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(
                fontFamily: 'Inter',
                color: colors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _uninstallDistribution(dist);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.textPrimary,
            ),
            child: const Text('Desinstalar'),
          ),
        ],
      ),
    );
  }

  Future<void> _installDistribution(LinuxDistribution dist) async {
    try {
      await dist.install(
        onProgress: (stage, pct) {
          debugPrint('[install] $stage: $pct%');
        },
      );
      if (mounted) {
        setState(() {});
        final colors = NanoThemeExtension.of(context).colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${dist.name} instalado correctamente'),
            backgroundColor: colors.accentMint,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final colors = NanoThemeExtension.of(context).colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al instalar ${dist.name}: $e'),
            backgroundColor: colors.error,
          ),
        );
      }
    }
  }

  Future<void> _uninstallDistribution(LinuxDistribution dist) async {
    try {
      await dist.uninstall();
      if (mounted) {
        setState(() {});
        final colors = NanoThemeExtension.of(context).colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${dist.name} desinstalado'),
            backgroundColor: colors.accentSky,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final colors = NanoThemeExtension.of(context).colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al desinstalar ${dist.name}: $e'),
            backgroundColor: colors.error,
          ),
        );
      }
    }
  }
}

class _DistributionCard extends StatelessWidget {
  final LinuxDistribution distribution;
  final VoidCallback onTap;

  const _DistributionCard({required this.distribution, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return FutureBuilder<bool>(
      future: distribution.isInstalled(),
      builder: (context, snapshot) {
        final isInstalled = snapshot.data ?? false;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NanoOpticalSurface(
            borderRadius: NanoRadius.large,
            blurSigma: 16,
            borderStrength: 0.70,
            reflectionStrength: 0.50,
            accent: isInstalled ? colors.accentMint : colors.accentSky,
            onTap: onTap,
            tilt: true,
            autoReflect: true,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _DistributionIcon(isInstalled: isInstalled),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        distribution.name,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${distribution.architecture} • ${distribution.packageBackend}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(isInstalled: isInstalled),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DistributionIcon extends StatelessWidget {
  final bool isInstalled;

  const _DistributionIcon({required this.isInstalled});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return NanoOpticalSurface(
      geometry: NanoSurfaceGeometry.circle,
      blurSigma: 10,
      borderStrength: 0.65,
      reflectionStrength: 0.50,
      accent: isInstalled ? colors.accentMint : colors.accentSky,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(
          isInstalled ? Icons.check_circle_rounded : Icons.download_rounded,
          color: isInstalled ? colors.accentMint : colors.accentSky,
          size: 22,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isInstalled;

  const _StatusBadge({required this.isInstalled});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isInstalled ? colors.accentMint : colors.metalSilver)
            .withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: isInstalled ? colors.accentMint : colors.metalSilver,
          width: 0.8,
        ),
      ),
      child: Text(
        isInstalled ? 'Instalado' : 'No instalado',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isInstalled ? colors.accentMint : colors.textSecondary,
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDestructive;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final color = isDestructive ? colors.error : colors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
