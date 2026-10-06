/// MESSAGING-CONTACTS-VIEW — Lista y explorador de contactos de WhatsApp.
///
/// **QUÉ HACE:**
/// Muestra los contactos reales de WhatsApp guardados en el dispositivo con opción de búsqueda,
/// gestión de permisos de lectura de contactos y apertura directa de conversación.
///
/// **CÓMO FUNCIONA:**
/// Escucha [contactsPermissionProvider] y [filteredWhatsAppContactsProvider].
/// Al pulsar un contacto, crea un [ConversationSummaryItem] fidedigno con el JID y número
/// y despliega [ConversationDetailSheet] con el historial y capacidades de envío listas.
///
/// **POR QUÉ:**
/// Permite al usuario iniciar o continuar chats con cualquier contacto sin tener que entrar
/// manualmente a la aplicación oficial de WhatsApp. Archivo < 200 líneas (SOLID).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../application/whatsapp_contacts_provider.dart';
import 'messaging_center_banners.dart';
import 'messaging_error_card.dart';
import 'messaging_contact_selection_list.dart';
import 'messaging_contacts_policy_bar.dart';

class MessagingContactsView extends ConsumerWidget {
  const MessagingContactsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermissionAsync = ref.watch(contactsPermissionProvider);
    final allContactsAsync = ref.watch(allWhatsAppContactsProvider);
    final contacts = ref.watch(filteredWhatsAppContactsProvider);

    return hasPermissionAsync.when(
      data: (hasPermission) {
        if (!hasPermission) {
          return SliverToBoxAdapter(
            child: MessagingPermissionBanner(
              icon: Icons.contacts_rounded,
              color: const Color(0xFF25D366),
              title: 'Permiso de Contactos requerido',
              subtitle:
                  'NanoAI necesita permiso de lectura de contactos para encontrar tus chats de WhatsApp.',
              actionLabel: 'Permitir acceso',
              onAction: () async {
                await ref
                    .read(whatsappContactsServiceProvider)
                    .requestPermission();
                ref.invalidate(contactsPermissionProvider);
                ref.invalidate(allWhatsAppContactsProvider);
              },
            ),
          );
        }

        if (allContactsAsync.isLoading) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final colors = NanoThemeExtension.of(context).colors;
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: CircularProgressIndicator(
                  color: isDark ? const Color(0xFF25D366) : colors.primary,
                ),
              ),
            ),
          );
        }

        if (allContactsAsync.hasError) {
          return SliverToBoxAdapter(
            child: MessagingErrorCard(
              error: allContactsAsync.error.toString(),
              onRetry: () => ref.invalidate(allWhatsAppContactsProvider),
            ),
          );
        }

        if (contacts.isEmpty) {
          return _buildEmptyContacts(context, ref);
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final colors = NanoThemeExtension.of(context).colors;
        final brandGreen = isDark ? const Color(0xFF25D366) : colors.primary;

        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MessagingContactsPolicyBar(),
                  MessagingSectionLabel(
                    icon: Icons.people_alt_rounded,
                    iconColor: brandGreen,
                    label: 'Contactos de WhatsApp',
                    count: contacts.length,
                  ),
                  const SizedBox(height: NanoSpacing.xs),
                ],
              ),
            ),
            MessagingContactSelectionList(contacts: contacts),
          ],
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(color: Color(0xFF25D366)),
          ),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: MessagingErrorCard(
          error: e.toString(),
          onRetry: () => ref.invalidate(allWhatsAppContactsProvider),
        ),
      ),
    );
  }

  Widget _buildEmptyContacts(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = NanoThemeExtension.of(context).colors;
    final brandGreen = isDark ? const Color(0xFF25D366) : colors.primary;

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: brandGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: brandGreen.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Icon(
                  Icons.contact_phone_rounded,
                  size: 30,
                  color: brandGreen,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No se encontraron contactos de WhatsApp',
              style: TextStyle(
                color: isDark ? Colors.white : colors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Asegúrate de tener contactos guardados con cuenta de WhatsApp en tu teléfono.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : colors.onSurfaceVariant,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                ref.invalidate(allWhatsAppContactsProvider);
              },
              icon: Icon(Icons.refresh_rounded, size: 16, color: brandGreen),
              label: Text(
                'Actualizar contactos',
                style: TextStyle(
                  color: brandGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
