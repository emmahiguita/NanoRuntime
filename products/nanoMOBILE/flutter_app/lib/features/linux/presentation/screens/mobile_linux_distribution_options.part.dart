part of 'mobile_linux_screen.dart';

extension _MobileLinuxDistributionOptions on _MobileLinuxScreenState {
  void _showDistributionOptions(LinuxDistribution dist) {
    final colors = NanoThemeExtension.of(context).colors;
    showNanoGlassWindow<void>(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (sheetContext) {
        final screenHeight = MediaQuery.sizeOf(sheetContext).height;
        final bottomInset = MediaQuery.paddingOf(sheetContext).bottom;
        return Container(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
          child: SafeArea(
            top: false,
            bottom: true,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset / 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      NanoOpticalSurface(
                        geometry: NanoSurfaceGeometry.roundedRectangle,
                        borderRadius: NanoRadius.small,
                        blurSigma: 10,
                        borderStrength: 0.65,
                        reflectionStrength: 0.5,
                        accent: colors.accentMint,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(
                            Icons.terminal_rounded,
                            color: colors.accentMint,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dist.name,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${dist.architecture} • ${dist.packageBackend} • Contenedor local',
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
                      Semantics(
                        label: 'Cerrar opciones',
                        button: true,
                        child: IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: colors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: colors.borderSecondaryColor.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  _OptionTile(
                    icon: Icons.terminal_rounded,
                    title: 'Abrir Terminal',
                    subtitle:
                        'Iniciar shell interactivo (${dist.defaultShell})',
                    accentColor: colors.accentMint,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      final cmd = switch (dist.id) {
                        'kali' => 'kali%20shell',
                        'ubuntu' => 'ubuntu%20shell',
                        _ => null,
                      };
                      if (cmd != null) {
                        context.push('/terminal/shell?cmd=$cmd');
                      } else {
                        context.push('/terminal/shell');
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _OptionTile(
                    icon: Icons.desktop_windows_rounded,
                    title: 'Abrir Desktop (VNC)',
                    subtitle: 'Conectar a entorno gráfico XFCE / escritorio',
                    accentColor: colors.accentSky,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.push('/desktop');
                    },
                  ),
                  const SizedBox(height: 10),
                  _OptionTile(
                    icon: Icons.settings_applications_rounded,
                    title: 'Info del sistema',
                    subtitle: 'Ver arquitectura, versión y metadatos del OS',
                    accentColor: colors.metalSilver,
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      final info = await dist.getInfo();
                      if (mounted) {
                        _showDistributionInfo(dist, info);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _OptionTile(
                    icon: Icons.delete_rounded,
                    title: 'Desinstalar',
                    subtitle: 'Eliminar contenedor y almacenamiento local',
                    accentColor: colors.error,
                    isDestructive: true,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _confirmUninstall(dist);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
