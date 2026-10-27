part of 'account_settings_card.dart';

/// Tarjeta de perfil de usuario autenticado estilo Apple ID / iOS.
///
/// - QUÉ HACE: Muestra el avatar, nombre, insignia sobria de suscripción, correo
///   y estado de sincronización local del usuario.
/// - CÓMO FUNCIONA: Utiliza [AutomationSurfaceCard] con borde neutro estructural
///   descartando cualquier halo o refracción colorida/neón.
/// - POR QUÉ: Sigue estrictamente la estética ejecutiva sobria sin bordes coloridos.
class _AuthenticatedProfileCard extends StatelessWidget {
  final NanoColors colors;
  final AuthUser user;
  final AccountProfile profile;

  const _AuthenticatedProfileCard({
    required this.colors,
    required this.user,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = profile.displayName.isNotEmpty
        ? profile.displayName
        : (user.displayName.isNotEmpty ? user.displayName : 'Usuario Soberano');
    final email = profile.email.isNotEmpty
        ? profile.email
        : (user.email.isNotEmpty ? user.email : 'usuario@nano.local');
    final initials = profile.displayName.trim().isEmpty
        ? user.initials
        : profile.displayName.trim().characters.first.toUpperCase();
    final photoUrl = profile.photoUrl ?? user.photoUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AutomationSurfaceCard(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: () => context.push('/account'),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? colors.surfaceVariant.withValues(alpha: 0.6)
                    : colors.surface,
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.50),
                  width: 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: _renderAvatar(photoUrl, initials),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: -0.3,
                            color: colors.onSurface,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(alpha: 0.3),
                            width: 0.6,
                          ),
                        ),
                        child: Text(
                          profile.planTier.isNotEmpty
                              ? profile.planTier.toUpperCase()
                              : 'LOCAL',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: colors.onSurfaceVariant,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurfaceVariant,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Local-first  •  Cifrado E2E  •  ${profile.syncEnabled ? 'Sincronizado' : 'Modo local'}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.75),
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderAvatar(String? path, String initials) {
    if (path == null || path.isEmpty) return _initials(initials);
    final uri = Uri.tryParse(path);
    if (uri?.scheme == 'https' || uri?.scheme == 'http') {
      return ClipOval(
        child: Image.network(
          path,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initials(initials),
        ),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return ClipOval(
        child: Image.file(
          file,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initials(initials),
        ),
      );
    }
    return _initials(initials);
  }

  Widget _initials(String text) => Text(
    text,
    style: TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w800,
      fontSize: 17,
      color: colors.primary,
      decoration: TextDecoration.none,
    ),
  );
}

/// Tarjeta de perfil no autenticado estilo Apple ID / iOS.
class _UnauthenticatedProfileCard extends StatelessWidget {
  final NanoColors colors;
  const _UnauthenticatedProfileCard({required this.colors});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AutomationSurfaceCard(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: () => context.push('/auth/login'),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceVariant.withValues(alpha: 0.5)
                    : colors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.50),
                  width: 1.0,
                ),
              ),
              child: Icon(
                Icons.person_rounded,
                color: colors.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Perfil Soberano Nano',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                      letterSpacing: -0.2,
                      color: colors.onSurface,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Identidad local, privacidad y modelos fuera de línea.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurfaceVariant,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
