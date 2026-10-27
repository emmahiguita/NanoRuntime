part of 'browser_credentials_sheet.dart';

class _CredentialsHeader extends StatelessWidget {
  final ThemeData theme;
  final String? currentDomain;

  const _CredentialsHeader({required this.theme, required this.currentDomain});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 14, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0284C7).withValues(alpha: 0.2),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                width: 1.0,
              ),
            ),
            child: const Icon(
              Icons.vpn_key_rounded,
              size: 17,
              color: Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bóveda de Credenciales',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Almacenamiento seguro cifrado HMAC-SHA256',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'Agregar credencial',
            button: true,
            child: IconButton(
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: Color(0xFF38BDF8),
                size: 22,
              ),
              onPressed: () => BrowserAddCredentialDialog.show(
                context,
                initialDomain: currentDomain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CredentialsListView extends StatelessWidget {
  final List<dynamic> filtered;
  final ThemeData theme;
  final String? currentDomain;
  final Set<String> revealedIds;
  final ValueChanged<String> onToggleReveal;
  final void Function(dynamic cred, String user, String pass) onAutofill;
  final ValueChanged<String> onDelete;

  const _CredentialsListView({
    required this.filtered,
    required this.theme,
    required this.currentDomain,
    required this.revealedIds,
    required this.onToggleReveal,
    required this.onAutofill,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No hay contraseñas guardadas en la bóveda cifrada',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final cred = filtered[index];
        final isCurrent =
            currentDomain != null &&
            (cred.domain.contains(currentDomain!) ||
                currentDomain!.contains(cred.domain));
        return BrowserCredentialTile(
          credential: cred,
          isRevealed: revealedIds.contains(cred.id),
          isCurrentSite: isCurrent,
          onToggleReveal: () => onToggleReveal(cred.id),
          onAutofill: (user, pass) => onAutofill(cred, user, pass),
          onDelete: () => onDelete(cred.id),
        );
      },
    );
  }
}
