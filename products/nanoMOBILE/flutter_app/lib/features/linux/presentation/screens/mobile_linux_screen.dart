import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/linux/linux_distribution.dart';
import '../../../../core/linux/linux_distribution_registry.dart';
import '../../../../core/linux/linux_init.dart';
import '../../../../core/providers/kali_provider.dart';
import '../../../../core/theme/design_tokens.dart';

/// Dashboard nativo Mobile Linux Mode.
///
/// Esta pantalla proporciona una interfaz 100% Flutter nativa para
/// gestionar distribuciones Linux sin depender de VNC. Es el punto
/// de entrada principal para usuarios que prefieren una experiencia
/// mobile optimizada en lugar del escritorio VNC completo.
class MobileLinuxScreen extends ConsumerStatefulWidget {
  const MobileLinuxScreen({super.key});

  @override
  ConsumerState<MobileLinuxScreen> createState() => _MobileLinuxScreenState();
}

class _MobileLinuxScreenState extends ConsumerState<MobileLinuxScreen> {
  final LinuxDistributionRegistry _registry = LinuxDistributionRegistry.instance;
  bool _kaliRegistered = false;

  @override
  void initState() {
    super.initState();
    // Registrar Kali cuando el provider esté disponible
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
    // Intentar registrar Kali en cada build si aún no está registrado
    if (!_kaliRegistered) {
      _registerKaliIfNeeded();
    }

    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: _buildAppBar(context),
      body: _buildBody(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return AppBar(
      backgroundColor: colors.surface,
      elevation: 0,
      title: Text(
        'Nano Linux',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colors.onSurface,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.desktop_windows_rounded, color: colors.onSurface),
          onPressed: () => context.push('/desktop'),
          tooltip: 'Modo Desktop',
        ),
        IconButton(
          icon: Icon(Icons.settings_rounded, color: colors.onSurface),
          onPressed: () => context.push('/settings'),
          tooltip: 'Ajustes',
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final distributions = _registry.getAllDistributions();

    if (distributions.isEmpty) {
      return Center(
        child: Text(
          'No hay distribuciones disponibles',
          style: TextStyle(color: colors.onSurface.withValues(alpha: 0.7)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: distributions.length,
        itemBuilder: (context, index) {
          final dist = distributions[index];
          return _DistributionCard(
            distribution: dist,
            onTap: () => _handleDistributionTap(dist),
          );
        },
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
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Instalar ${dist.name}',
          style: TextStyle(color: colors.onSurface),
        ),
        content: Text(
          'Se descargará el rootfs de ${dist.name} (${dist.architecture}). '
          'Esto requiere conexión a internet.',
          style: TextStyle(
            color: colors.onSurface.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _installDistribution(dist);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onSurface,
            ),
            child: const Text('Instalar'),
          ),
        ],
      ),
    );
  }

  void _showDistributionOptions(LinuxDistribution dist) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
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
                // Si es Kali, inyectar comando "kali shell"
                if (dist.id == 'kali') {
                  context.push('/terminal?cmd=kali shell');
                } else {
                  context.push('/terminal');
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

  void _showDistributionInfo(LinuxDistribution dist, LinuxDistributionInfo info) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          dist.name,
          style: TextStyle(color: colors.onSurface),
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
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmUninstall(LinuxDistribution dist) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Desinstalar ${dist.name}',
          style: TextStyle(color: colors.onSurface),
        ),
        content: Text(
          'Esto eliminará todos los archivos de ${dist.name}. '
          'La acción no se puede deshacer.',
          style: TextStyle(
            color: colors.onSurface.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.7),
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
              foregroundColor: colors.onSurface,
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
          // TODO: Mostrar progreso en UI
          debugPrint('[install] $stage: $pct%');
        },
      );
      if (mounted) {
        setState(() {});
        final colors =
            Theme.of(context).extension<NanoThemeExtension>()!.colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${dist.name} instalado correctamente'),
            backgroundColor: colors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final colors =
            Theme.of(context).extension<NanoThemeExtension>()!.colors;
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
        final colors =
            Theme.of(context).extension<NanoThemeExtension>()!.colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${dist.name} desinstalado'),
            backgroundColor: colors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final colors =
            Theme.of(context).extension<NanoThemeExtension>()!.colors;
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

  const _DistributionCard({
    required this.distribution,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return FutureBuilder<bool>(
      future: distribution.isInstalled(),
      builder: (context, snapshot) {
        final isInstalled = snapshot.data ?? false;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: colors.surfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colors.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
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
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${distribution.architecture} • ${distribution.packageBackend}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: colors.onSurface.withValues(alpha: 0.54),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(isInstalled: isInstalled),
                ],
              ),
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
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isInstalled
            ? colors.primary.withValues(alpha: 0.2)
            : colors.onSurface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isInstalled ? Icons.check_circle_rounded : Icons.download_rounded,
        color:
            isInstalled ? colors.primary : colors.onSurface.withValues(alpha: 0.54),
        size: 24,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isInstalled;

  const _StatusBadge({required this.isInstalled});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isInstalled
            ? colors.primary.withValues(alpha: 0.2)
            : colors.onSurface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isInstalled
              ? colors.primary.withValues(alpha: 0.5)
              : colors.onSurface.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        isInstalled ? 'Instalado' : 'No instalado',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isInstalled
              ? colors.primary
              : colors.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: colors.onSurface.withValues(alpha: 0.7), size: 20),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                color: colors.onSurface,
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
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.7),
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
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
