part of 'mobile_linux_screen.dart';

extension _MobileLinuxActions on _MobileLinuxScreenState {
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
