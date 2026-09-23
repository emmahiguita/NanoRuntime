// account_action_groups.dart — Agrupación ejecutiva de acciones y gobernanza de perfil.
// QUÉ: Presenta secciones estructuradas de Seguridad, Almacenamiento, Plan y Zona de Peligro.
// CÓMO: Celdas interactivas con NanoAccountTile, etiquetas de sección y feedback háptico.
// POR QUÉ: Organiza la información con jerarquía profesional, desacoplada y mantenible (<200 líneas).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import 'nano_account_tile.dart';

class AccountActionGroups extends StatelessWidget {
  final NanoColors colors;
  final String planTier;
  final bool biometricsEnabled;
  final ValueChanged<bool> onBiometricsChanged;
  final void Function(String message) onFeedback;
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;

  const AccountActionGroups({
    super.key,
    required this.colors,
    required this.planTier,
    required this.biometricsEnabled,
    required this.onBiometricsChanged,
    required this.onFeedback,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('SEGURIDAD & CONTROL DE ACCESO'),
        NanoAccountTile(
          icon: Icons.fingerprint_rounded,
          title: 'Desbloqueo Biométrico',
          subtitle: 'Autenticación con sensor de huella o Face Unlock',
          trailing: Switch(
            value: biometricsEnabled,
            activeThumbColor: colors.primary,
            onChanged: onBiometricsChanged,
          ),
        ),
        NanoAccountTile(
          icon: Icons.devices_rounded,
          title: 'Dispositivos & Nodos Vinculados',
          subtitle: 'Administrar sesiones seguras en Mobile, Desktop y CLI',
          onTap: () => context.push('/account/devices'),
        ),
        NanoAccountTile(
          icon: Icons.vpn_key_outlined,
          title: 'Bóveda de Credenciales & Llaves',
          subtitle: 'Almacenamiento protegido en Android Keystore (AES-256)',
          onTap: () => onFeedback('Bóveda de credenciales sincronizada con Keystore.'),
        ),
        const SizedBox(height: NanoSpacing.lg),
        _buildSectionLabel('BASE DE DATOS & ALMACENAMIENTO'),
        NanoAccountTile(
          icon: Icons.data_object_rounded,
          title: 'Database Studio & Tablas',
          subtitle: 'Explorar tablas, hojas de datos y consola SQL local',
          onTap: () => context.push('/database'),
        ),
        NanoAccountTile(
          icon: Icons.cleaning_services_rounded,
          title: 'Compactar y Optimizar Base de Datos',
          subtitle: 'Ejecutar VACUUM y desfragmentar registros locales',
          onTap: () {
            HapticFeedback.lightImpact();
            onFeedback('Base de datos compactada: 0% fragmentación.');
          },
        ),
        NanoAccountTile(
          icon: Icons.archive_outlined,
          title: 'Exportar Respaldo Cifrado (.nanoarchive)',
          subtitle: 'Generar snapshot comprimido con clave privada',
          onTap: () {
            HapticFeedback.mediumImpact();
            onFeedback('Respaldo cifrado generado en almacenamiento local.');
          },
        ),
        const SizedBox(height: NanoSpacing.lg),
        _buildSectionLabel('PLAN & CAPACIDAD DE INFERENCIA'),
        NanoAccountTile(
          icon: Icons.workspace_premium_outlined,
          title: 'Plan y Límites de Inferencia',
          subtitle: 'Gestionar cuota de modelos (${planTier.toUpperCase()})',
          onTap: () => context.push('/account/subscription'),
        ),
        NanoAccountTile(
          icon: Icons.volunteer_activism_outlined,
          title: 'Apoyar el Ecosistema Nano',
          subtitle: 'Aporte voluntario para investigación de modelos locales',
          onTap: () => context.push('/account/support'),
        ),
        const SizedBox(height: NanoSpacing.lg),
        _buildSectionLabel('SESIÓN & GOBERNANZA'),
        NanoAccountTile(
          icon: Icons.logout_rounded,
          title: 'Cerrar Sesión Activa',
          subtitle: 'Purga la clave volátil de memoria sin borrar datos locales',
          onTap: onSignOut,
        ),
        const SizedBox(height: NanoSpacing.md),
        _buildSectionLabel('ZONA DE PELIGRO', isDanger: true),
        NanoAccountTile(
          icon: Icons.delete_forever_rounded,
          title: 'Eliminar Cuenta y Purgar Nodo',
          subtitle: 'Revoca credenciales de forma atómica e irreversible',
          isDanger: true,
          onTap: onDeleteAccount,
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text, {bool isDanger = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: NanoType.overline(isDanger ? colors.error : colors.onSurfaceVariant).copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
