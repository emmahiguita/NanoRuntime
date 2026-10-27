import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import 'nano_glass_field.dart';
import 'frost_login_button.dart';

/// Formulario de acceso con diseño sobrio y jerarquía visual estilo iOS.
/// Mantiene intacta la lógica de autenticación y los controladores.
class LoginAccessForm extends StatelessWidget {
  const LoginAccessForm({
    super.key,
    required this.email,
    required this.password,
    required this.busy,
    required this.onLogin,
    required this.onGoogle,
    required this.onLocal,
    required this.onForgot,
    this.error,
  });

  final TextEditingController email, password;
  final bool busy;
  final VoidCallback onLogin, onGoogle, onLocal, onForgot;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final themeExt = NanoThemeExtension.maybeOf(context);
    final colors = themeExt?.colors ?? const NanoDarkColors();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fieldBg = isDark
        ? colors.surfaceVariant.withValues(alpha: 0.40)
        : colors.surface.withValues(alpha: 0.85);
    final fieldBorder = colors.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.45);

    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: fieldBg,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          labelStyle: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: colors.onSurfaceVariant,
            decoration: TextDecoration.none,
          ),
          floatingLabelStyle: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: colors.primary,
            decoration: TextDecoration.none,
          ),
          prefixIconColor: colors.onSurfaceVariant,
          prefixIconConstraints: const BoxConstraints(minWidth: 46),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: fieldBorder, width: 0.9),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: fieldBorder, width: 0.9),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.primary, width: 1.4),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.error.withValues(alpha: 0.7), width: 1.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.error, width: 1.4),
          ),
        ),
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null) ...[
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.error.withValues(alpha: 0.30),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: colors.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          error!,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: colors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            NanoGlassField(
              controller: email,
              label: 'Correo electrónico',
              hint: 'nombre@correo.com',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (value) => value == null || !value.contains('@')
                  ? 'Ingresa un correo válido'
                  : null,
            ),
            const SizedBox(height: 12),
            NanoGlassField(
              controller: password,
              label: 'Contraseña',
              isPassword: true,
              prefixIcon: Icons.lock_outline_rounded,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (!busy) onLogin();
              },
              validator: (value) => value == null || value.length < 6
                  ? 'Mínimo 6 caracteres'
                  : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: busy ? null : onForgot,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '¿Olvidaste tu contraseña?',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: colors.primary,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FrostLoginButton(busy: busy, onPressed: onLogin),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: colors.outlineVariant.withValues(alpha: isDark ? 0.30 : 0.40),
                    height: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'o continúa con',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurfaceVariant,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: colors.outlineVariant.withValues(alpha: isDark ? 0.30 : 0.40),
                    height: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: isDark
                      ? colors.surfaceVariant.withValues(alpha: 0.30)
                      : colors.surface.withValues(alpha: 0.80),
                  foregroundColor: colors.onSurface,
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.50),
                    width: 0.9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: busy ? null : onGoogle,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.4),
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Continuar con Google',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: colors.onSurface,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: colors.onSurfaceVariant,
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.40),
                    width: 0.8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: busy ? null : onLocal,
                icon: Icon(
                  Icons.phonelink_lock_rounded,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                label: Text(
                  'Continuar en este dispositivo',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5,
                    color: colors.onSurfaceVariant,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
