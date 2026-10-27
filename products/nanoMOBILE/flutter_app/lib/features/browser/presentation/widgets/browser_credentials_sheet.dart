import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';
import 'package:nanoai/features/browser/application/browser_credential_notifier.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_add_credential_dialog.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_credential_tile.dart';

part 'browser_credentials_search.part.dart';
part 'browser_credentials_sheet_views.part.dart';

/// Ventana flotante estilo Liquid Glass para administrar contraseñas guardadas en el navegador.
class BrowserCredentialsSheet extends ConsumerStatefulWidget {
  final String? currentDomain;
  final void Function(String username, String password)? onAutofill;

  const BrowserCredentialsSheet({
    super.key,
    this.currentDomain,
    this.onAutofill,
  });

  static Future<void> show({
    required BuildContext context,
    String? currentDomain,
    void Function(String username, String password)? onAutofill,
  }) {
    return showNanoGlassWindow(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => BrowserCredentialsSheet(
        currentDomain: currentDomain,
        onAutofill: onAutofill,
      ),
    );
  }

  @override
  ConsumerState<BrowserCredentialsSheet> createState() =>
      _BrowserCredentialsSheetState();
}

class _BrowserCredentialsSheetState
    extends ConsumerState<BrowserCredentialsSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _revealedIds = {};
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final credentials = ref.watch(browserCredentialProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mq = MediaQuery.of(context);

    final filtered = credentials.where((c) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return c.domain.toLowerCase().contains(q) ||
          c.username.toLowerCase().contains(q);
    }).toList();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CredentialsHeader(theme: theme, currentDomain: widget.currentDomain),
          _CredentialsSearchBar(
            theme: theme,
            isDark: isDark,
            searchCtrl: _searchCtrl,
            query: _query,
            onChanged: (val) => setState(() => _query = val.trim()),
            onClear: () {
              _searchCtrl.clear();
              setState(() => _query = '');
            },
          ),
          const SizedBox(height: 8),
          Divider(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            height: 1,
          ),
          Flexible(
            child: _CredentialsListView(
              filtered: filtered,
              theme: theme,
              currentDomain: widget.currentDomain,
              revealedIds: _revealedIds,
              onToggleReveal: (id) => setState(
                () => _revealedIds.contains(id)
                    ? _revealedIds.remove(id)
                    : _revealedIds.add(id),
              ),
              onAutofill: (cred, user, pass) {
                widget.onAutofill?.call(user, pass);
                ref
                    .read(browserCredentialProvider.notifier)
                    .updateLastUsed(cred.id);
                Navigator.pop(context);
              },
              onDelete: (id) => ref
                  .read(browserCredentialProvider.notifier)
                  .deleteCredential(id),
            ),
          ),
        ],
      ),
    );
  }
}
