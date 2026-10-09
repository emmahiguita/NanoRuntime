import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_tokens.dart';
import '../google_account_provider.dart';

/// Diálogo de cuenta Google — sin API Keys, sesión vía navegador integrado.
class GoogleAccountDialog extends ConsumerStatefulWidget {
  const GoogleAccountDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const GoogleAccountDialog(),
    );
  }

  @override
  ConsumerState<GoogleAccountDialog> createState() => _GoogleAccountDialogState();
}

class _GoogleAccountDialogState extends ConsumerState<GoogleAccountDialog> {
  late final TextEditingController _emailController;
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(googleAccountProvider);
    _emailController = TextEditingController(text: profile.email);
    _nameController = TextEditingController(text: profile.displayName);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(googleAccountProvider);
    final notifier = ref.read(googleAccountProvider.notifier);
    final colors = NanoThemeExtension.of(context).colors;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colors.outline.withValues(alpha: 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surfaceVariant,
                      border: Border.all(color: const Color(0xFF4285F4), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'G',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4285F4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cuenta de Google',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile.isConnected ? '🟢 ${profile.syncStatus}' : '🔴 Desconectada',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: profile.isConnected ? colors.success : colors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.onSurfaceVariant),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: colors.outlineVariant.withValues(alpha: 0.30), height: 1),
              const SizedBox(height: 14),

              // Campo: Nombre
              _fieldLabel('Nombre del titular', colors),
              const SizedBox(height: 6),
              _inputField(
                controller: _nameController,
                icon: Icons.person_rounded,
                iconColor: colors.primary,
                colors: colors,
              ),
              const SizedBox(height: 12),

              // Campo: Correo
              _fieldLabel('Correo Gmail / Google Account', colors),
              const SizedBox(height: 6),
              _inputField(
                controller: _emailController,
                icon: Icons.mail_rounded,
                iconColor: const Color(0xFFEA4335),
                colors: colors,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),

              // Toggles de servicios
              _switch(
                'Navegador IA Web',
                'Usa ChatGPT, DeepSeek, Gemini vía sesión de navegador',
                profile.browserAgentEnabled,
                notifier.toggleBrowserAgent,
                colors,
              ),
              _switch(
                'Búsqueda Web Google',
                'Consultas enciclopédicas y datos en vivo',
                profile.googleSearchEnabled,
                notifier.toggleGoogleSearch,
                colors,
              ),
              _switch(
                'Sincronización Cloud',
                'Mantiene configuración sincronizada',
                profile.cloudSyncEnabled,
                notifier.toggleCloudSync,
                colors,
              ),
              const SizedBox(height: 18),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.sync_rounded, size: 16),
                      label: const Text('Sincronizar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.primary,
                        side: BorderSide(color: colors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: notifier.syncNow,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await notifier.connectAccount(
                          email: _emailController.text,
                          displayName: _nameController.text,
                        );
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switch(String title, String subtitle, bool value, ValueChanged<bool> onChanged, NanoColors colors) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(title, style: TextStyle(color: colors.onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
        value: value,
        activeThumbColor: colors.primary,
        onChanged: onChanged,
      );

  Widget _fieldLabel(String text, NanoColors colors) => Text(
        text,
        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600),
      );

  Widget _inputField({
    required TextEditingController controller,
    required IconData icon,
    required Color iconColor,
    required NanoColors colors,
    TextInputType? keyboardType,
  }) =>
      TextField(
        controller: controller,
        style: TextStyle(color: colors.onSurface, fontSize: 14),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          filled: true,
          fillColor: colors.surfaceVariant.withValues(alpha: 0.50),
          prefixIcon: Icon(icon, color: iconColor, size: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.20)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
}
