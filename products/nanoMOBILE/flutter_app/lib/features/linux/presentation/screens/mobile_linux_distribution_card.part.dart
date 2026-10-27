part of 'mobile_linux_screen.dart';

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
