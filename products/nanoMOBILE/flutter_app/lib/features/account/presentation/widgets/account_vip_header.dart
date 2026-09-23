import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_optical_surface.dart';

/// QUÉ HACE:
/// Cabecera VIP de perfil de usuario para AccountCenterScreen.
///
/// CÓMO FUNCIONA:
/// Muestra avatar con halo, iniciales, badge metálico de plan, correo corporativo
/// e ID de nodo local con interacción de copiado al portapapeles.
class AccountVipHeader extends StatelessWidget {
  final String name;
  final String email;
  final String plan;
  final String initials;
  final String uid;
  final VoidCallback onCopied;

  const AccountVipHeader({
    super.key,
    required this.name,
    required this.email,
    required this.plan,
    required this.initials,
    required this.uid,
    required this.onCopied,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final effectiveName = name.isNotEmpty ? name : 'Operador Soberano';
    final effectiveInitials = initials.isNotEmpty ? initials : 'OP';

    return NanoOpticalSurface(
      borderRadius: NanoRadius.large,
      padding: const EdgeInsets.fromLTRB(NanoSpacing.md, NanoSpacing.md, NanoSpacing.xl + 4, NanoSpacing.md),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: colors.primary.withValues(alpha: 0.16),
                child: Text(
                  effectiveInitials,
                  style: NanoType.headline(colors.primary).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: NanoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        effectiveName,
                        style: NanoType.title(colors.onSurface).copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        plan.toUpperCase(),
                        style: NanoType.caption(colors.primary).copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(email, style: NanoType.caption(colors.onSurfaceVariant)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: uid));
                    onCopied();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tag_rounded, size: 12, color: colors.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Text(
                        uid.length > 16 ? '${uid.substring(0, 16)}...' : uid,
                        style: NanoType.caption(colors.onSurfaceVariant).copyWith(fontSize: 10),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.copy_rounded, size: 10, color: colors.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
