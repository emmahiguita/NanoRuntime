import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
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
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4285F4).withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'G',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 26,
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
                        const Text(
                          'Cuenta de Google',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile.isConnected ? '🟢 ${profile.syncStatus}' : '🔴 Desconectada',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: profile.isConnected
                                ? const Color(0xFF34D399)
                                : const Color(0xFFF87171),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 16),

              // Campo: Nombre
              _fieldLabel('Nombre del titular'),
              const SizedBox(height: 6),
              _inputField(
                controller: _nameController,
                icon: Icons.person_rounded,
                iconColor: const Color(0xFF38BDF8),
              ),
              const SizedBox(height: 14),

              // Campo: Correo
              _fieldLabel('Correo Gmail / Google Account'),
              const SizedBox(height: 6),
              _inputField(
                controller: _emailController,
                icon: Icons.mail_rounded,
                iconColor: const Color(0xFFEA4335),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 18),

              // Toggles de servicios
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Navegador IA Web',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: const Text(
                  'Usa ChatGPT, DeepSeek, Gemini vía sesión de navegador',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                value: profile.browserAgentEnabled,
                activeThumbColor: const Color(0xFF38BDF8),
                onChanged: notifier.toggleBrowserAgent,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Búsqueda Web Google',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: const Text(
                  'Consultas enciclopédicas y datos en vivo',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                value: profile.googleSearchEnabled,
                activeThumbColor: const Color(0xFF38BDF8),
                onChanged: notifier.toggleGoogleSearch,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Sincronización Cloud',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: const Text(
                  'Mantiene configuración sincronizada',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                value: profile.cloudSyncEnabled,
                activeThumbColor: const Color(0xFF38BDF8),
                onChanged: notifier.toggleCloudSync,
              ),
              const SizedBox(height: 20),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.sync_rounded, size: 16),
                      label: const Text('Sincronizar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        side: const BorderSide(color: Color(0xFF38BDF8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _inputField({
    required TextEditingController controller,
    required IconData icon,
    required Color iconColor,
    TextInputType? keyboardType,
  }) =>
      TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          prefixIcon: Icon(icon, color: iconColor, size: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF38BDF8)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
}
