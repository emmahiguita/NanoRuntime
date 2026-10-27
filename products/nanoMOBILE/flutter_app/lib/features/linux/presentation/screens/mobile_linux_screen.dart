import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/linux/linux_distribution.dart';
import '../../../../core/linux/linux_distribution_registry.dart';
import '../../../../core/linux/linux_init.dart';
import '../../../../core/providers/kali_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_transitions.dart';
import '../../../../core/widgets/nano_glass_window.dart';
import '../../../../core/widgets/nano_optical_surface.dart';

part 'mobile_linux_actions.part.dart';
part 'mobile_linux_distribution_card.part.dart';
part 'mobile_linux_distribution_options.part.dart';
part 'mobile_linux_tiles.part.dart';

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
      if (mounted) setState(() {});
    });
  }

  void _registerKaliIfNeeded() {
    if (_kaliRegistered) return;

    final kaliManager = ref.read(kaliProvider);
    if (kaliManager != null) {
      registerKaliDistribution(kaliManager);
      _kaliRegistered = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_kaliRegistered) {
      _registerKaliIfNeeded();
    }

    final colors = NanoThemeExtension.of(context).colors;

    return Column(
      children: [
        _buildHeader(context, colors),
        Expanded(child: _buildBody(context, colors)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, NanoColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Semantics(
            label: 'Atrás',
            button: true,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: colors.textPrimary,
              ),
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
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, NanoColors colors) {
    final distributions = _registry.getAllDistributions();

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
            children: [
              if (distributions.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'DISTRIBUCIONES LINUX',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                for (final dist in distributions)
                  _DistributionCard(
                    distribution: dist,
                    onTap: () => _handleDistributionTap(dist),
                  ),
              ],
            ],
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
}
