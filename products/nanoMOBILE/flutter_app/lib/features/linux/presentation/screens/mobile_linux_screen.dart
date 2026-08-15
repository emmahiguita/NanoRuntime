import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/linux/linux_distribution.dart';
import '../../../../core/linux/linux_distribution_registry.dart';
import '../../../../core/linux/linux_init.dart';
import '../../../../core/providers/kali_provider.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      appBar: _buildAppBar(context),
      body: _buildBody(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF161B22),
      elevation: 0,
      title: const Text(
        'Nano Linux',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.desktop_windows_rounded, color: Colors.white),
          onPressed: () => context.push('/desktop'),
          tooltip: 'Modo Desktop',
        ),
        IconButton(
          icon: const Icon(Icons.settings_rounded, color: Colors.white),
          onPressed: () => context.push('/settings'),
          tooltip: 'Ajustes',
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final distributions = _registry.getAllDistributions();

    if (distributions.isEmpty) {
      return const Center(
        child: Text(
          'No hay distribuciones disponibles',
          style: TextStyle(color: Colors.white70),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(
          'Instalar ${dist.name}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Se descargará el rootfs de ${dist.name} (${dist.architecture}). '
          'Esto requiere conexión a internet.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _installDistribution(dist);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Instalar'),
          ),
        ],
      ),
    );
  }

  void _showDistributionOptions(LinuxDistribution dist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF161B22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(
          dist.name,
          style: const TextStyle(color: Colors.white),
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
            child: const Text('Cerrar', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _confirmUninstall(LinuxDistribution dist) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(
          'Desinstalar ${dist.name}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Esto eliminará todos los archivos de ${dist.name}. '
          'La acción no se puede deshacer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _uninstallDistribution(dist);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${dist.name} instalado correctamente'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al instalar ${dist.name}: $e'),
            backgroundColor: Colors.red,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${dist.name} desinstalado'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al desinstalar ${dist.name}: $e'),
            backgroundColor: Colors.red,
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
    return FutureBuilder<bool>(
      future: distribution.isInstalled(),
      builder: (context, snapshot) {
        final isInstalled = snapshot.data ?? false;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: const Color(0xFF1E2430),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
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
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${distribution.architecture} • ${distribution.packageBackend}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Colors.white54,
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
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isInstalled
            ? const Color(0xFF10B981).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isInstalled ? Icons.check_circle_rounded : Icons.download_rounded,
        color: isInstalled ? const Color(0xFF10B981) : Colors.white54,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isInstalled
            ? const Color(0xFF10B981).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isInstalled
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        isInstalled ? 'Instalado' : 'No instalado',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isInstalled ? const Color(0xFF10B981) : Colors.white70,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                color: Colors.white,
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
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
