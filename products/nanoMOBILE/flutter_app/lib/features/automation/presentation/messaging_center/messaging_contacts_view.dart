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
import '../../engine/messaging/conversation_agent.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../widgets/conversation_detail_sheet.dart';
import 'messaging_center_banners.dart';
import 'messaging_contacts_policy_bar.dart';
import 'whatsapp_contact_card.dart';

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
          return MessagingPermissionBanner(
            icon: Icons.contacts_rounded,
            color: const Color(0xFF25D366),
            title: 'Permiso de Contactos requerido',
            subtitle: 'NanoAI necesita permiso de lectura de contactos para encontrar tus chats de WhatsApp.',
            actionLabel: 'Permitir acceso',
            onAction: () async {
              await ref.read(whatsappContactsServiceProvider).requestPermission();
              ref.invalidate(contactsPermissionProvider);
              ref.invalidate(allWhatsAppContactsProvider);
            },
          );
        }

        if (allContactsAsync.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: Color(0xFF25D366)),
            ),
          );
        }

        if (allContactsAsync.hasError) {
          return MessagingErrorCard(
            error: allContactsAsync.error.toString(),
            onRetry: () => ref.invalidate(allWhatsAppContactsProvider),
          );
        }

        if (contacts.isEmpty) {
          return _buildEmptyContacts(ref);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MessagingContactsPolicyBar(),
            MessagingSectionLabel(
              icon: Icons.people_alt_rounded,
              iconColor: const Color(0xFF25D366),
              label: 'Contactos de WhatsApp',
              count: contacts.length,
            ),
            const SizedBox(height: NanoSpacing.xs),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return WhatsAppContactCard(
                  contact: contact,
                  onTap: () {
                    // Crea un item fidedigno con el JID y número del contacto
                    final item = ConversationSummaryItem(
                      conversationId: contact.jid,
                      displayName: contact.name,
                      packageName: contact.isBusiness ? 'com.whatsapp.w4b' : 'com.whatsapp',
                      lastMessage: contact.number.isNotEmpty ? contact.number : contact.jid,
                      lastAtMs: DateTime.now().millisecondsSinceEpoch,
                      agentId: ConversationAgentId.personal,
                    );
                    ConversationDetailSheet.show(context, item);
                  },
                );
              },
            ),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: Color(0xFF25D366)),
        ),
      ),
      error: (e, _) => MessagingErrorCard(
        error: e.toString(),
        onRetry: () => ref.invalidate(allWhatsAppContactsProvider),
      ),
    );
  }

  Widget _buildEmptyContacts(WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF25D366).withValues(alpha: 0.3),
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.contact_phone_rounded,
                size: 30,
                color: Color(0xFF25D366),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No se encontraron contactos de WhatsApp',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Asegúrate de tener contactos guardados con cuenta de WhatsApp en tu teléfono.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              ref.invalidate(allWhatsAppContactsProvider);
            },
            icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF25D366)),
            label: const Text(
              'Actualizar contactos',
              style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
