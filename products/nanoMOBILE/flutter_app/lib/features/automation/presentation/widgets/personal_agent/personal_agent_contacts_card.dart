import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart';
import 'package:nanoai/features/automation/application/whatsapp_contacts_provider.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_owner.dart';
import '../../automation_visual_theme.dart';
import '../settings_tile_components.dart';
import 'personal_contacts_selector_sheet.dart';

/// QUÉ HACE:
/// Tarjeta de configuración para elegir la política de destinatarios del Agente Personal.
///
/// CÓMO FUNCIONA:
/// Permite alternar entre responder a 'Todos los contactos' o 'Solo seleccionados',
/// y brinda acceso directo al selector de contactos para activar/pausar personas reales.
///
/// POR QUÉ:
/// Ofrece transparencia y control determinista sobre qué contactos interactúan con la IA,
/// eliminando sorpresas y cumpliendo con principios de diseño Material Expressive.
class PersonalAgentContactsCard extends ConsumerWidget {
  const PersonalAgentContactsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final mode = settings.waTargetContactsMode;
    final isAll = mode == 'all';
    final visual = AutomationVisual.of(context);
    final allContactsAsync = ref.watch(allWhatsAppContactsProvider);
    final ownershipStore = ref.watch(conversationOwnershipStoreProvider);

    final activeCount = allContactsAsync.maybeWhen(
      data: (contacts) => isAll
          ? contacts.length
          : contacts.where((c) {
              final key = c.jid.isNotEmpty ? c.jid : c.number;
              final ownership = ownershipStore.ownershipFor(key) ??
                  (c.number.isNotEmpty ? ownershipStore.ownershipFor(c.number) : null) ??
                  (c.name.isNotEmpty ? ownershipStore.ownershipFor(c.name) : null);
              final isEmm = c.name.toLowerCase().contains('emm') ||
                  c.name.toLowerCase().contains('emma');
              return (ownership?.owner == ConversationOwner.bot) ||
                  (ownership?.owner != ConversationOwner.human && isEmm);
            }).length,
      orElse: () => 0,
    );

    return SettingsCard(
      children: [
        SettingsRow(
          icon: Icons.contact_emergency_rounded,
          title: 'Destinatarios de WhatsApp',
          subtitle: isAll
              ? 'Atención global — responde a todos tus chats'
              : 'Atención selectiva — solo contactos autorizados',
          trailing: ValueBadge(
            label: isAll ? 'TODOS' : '$activeCount ACTIVOS',
          ),
          showChevron: false,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSegmentedSelector(isAll, ref, visual),
              const SizedBox(height: 8),
              _buildPolicyDescription(isAll, visual),
              const SizedBox(height: 10),
              _buildManageButton(context, visual, activeCount, isAll),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedSelector(
    bool isAll,
    WidgetRef ref,
    AutomationVisualPalette visual,
  ) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        side: WidgetStateProperty.all(BorderSide(color: visual.cardBorder)),
      ),
      segments: const [
        ButtonSegment(
          value: 'all',
          icon: Icon(Icons.public_rounded, size: 14),
          label: Text('Todos los contactos', maxLines: 1),
        ),
        ButtonSegment(
          value: 'selected',
          icon: Icon(Icons.playlist_add_check_rounded, size: 14),
          label: Text('Solo seleccionados', maxLines: 1),
        ),
      ],
      selected: {isAll ? 'all' : 'selected'},
      onSelectionChanged: (set) {
        ref.read(settingsProvider.notifier).setWaTargetContactsMode(set.first);
      },
    );
  }

  Widget _buildPolicyDescription(bool isAll, AutomationVisualPalette visual) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isAll
            ? const Color(0xFF00E676).withValues(alpha: 0.08)
            : const Color(0xFF00D2FF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAll
              ? const Color(0xFF00E676).withValues(alpha: 0.3)
              : const Color(0xFF00D2FF).withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isAll ? Icons.info_outline_rounded : Icons.shield_outlined,
            size: 14,
            color: isAll ? const Color(0xFF00E676) : const Color(0xFF00D2FF),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isAll
                  ? 'El agente responde a cualquier chat entrante. Puedes pausar contactos específicos.'
                  : 'El agente responderá ÚNICAMENTE a los contactos que actives manualmente (ej. Emm).',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: visual.isDark ? const Color(0xFFD6DEE8) : visual.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManageButton(
    BuildContext context,
    AutomationVisualPalette visual,
    int activeCount,
    bool isAll,
  ) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF00E676),
        side: const BorderSide(color: Color(0x5500E676)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: () => PersonalContactsSelectorSheet.show(context),
      icon: const Icon(Icons.manage_accounts_rounded, size: 16),
      label: Text(
        isAll
            ? 'Pausar o revisar contactos individuales'
            : 'Seleccionar contactos autorizados ($activeCount activos)',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
