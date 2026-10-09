import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/automation/application/whatsapp_contacts_provider.dart';
import 'package:nanoai/features/automation/domain/whatsapp_contact.dart';
import 'package:nanoai/features/automation/presentation/messaging_center/whatsapp_contact_card.dart';

/// QUÉ HACE:
/// Hoja modal responsiva para gestionar qué contactos tienen el agente personal activo.
///
/// CÓMO FUNCIONA:
/// Permite buscar entre los contactos de WhatsApp sincronizados y cambiar de forma
/// instantánea su estado (Activo / Pausado) en [conversationOwnershipStoreProvider].
///
/// POR QUÉ:
/// Ofrece al usuario control granular determinista sin depender de reglas automáticas
/// ambiguas, asegurando que solo los contactos autorizados reciban respuestas autónomas.
class PersonalContactsSelectorSheet extends ConsumerStatefulWidget {
  const PersonalContactsSelectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PersonalContactsSelectorSheet(),
    );
  }

  @override
  ConsumerState<PersonalContactsSelectorSheet> createState() =>
      _PersonalContactsSelectorSheetState();
}

class _PersonalContactsSelectorSheetState
    extends ConsumerState<PersonalContactsSelectorSheet> {
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = NanoThemeExtension.of(context).colors;
    final allContactsAsync = ref.watch(allWhatsAppContactsProvider);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final maxHeight =
        MediaQuery.sizeOf(context).height * (isLandscape ? 0.90 : 0.80);

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141923) : colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildDragHandle(isDark),
          _buildHeader(colors, isDark),
          _buildSearchField(colors, isDark),
          Expanded(
            child: allContactsAsync.when(
              data: (contacts) => _buildList(contacts),
              loading: () => Center(
                child: CircularProgressIndicator(color: colors.primary),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Error al cargar contactos: $e',
                  style: TextStyle(color: isDark ? Colors.white70 : colors.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(dynamic colors, bool isDark) {
    final mode = ref.watch(settingsProvider).waTargetContactsMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.people_alt_rounded,
            color: colors.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mode == 'all'
                  ? 'Contactos de WhatsApp (Modo Global)'
                  : 'Contactos Autorizados (Modo Selectivo)',
              style: TextStyle(
                color: isDark ? Colors.white : colors.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: isDark ? Colors.white70 : colors.onSurfaceVariant,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(dynamic colors, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        style: TextStyle(color: isDark ? Colors.white : colors.onSurface, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre o número...',
          hintStyle: TextStyle(
            color: isDark ? Colors.white.withValues(alpha: 0.35) : colors.onSurfaceVariant,
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? Colors.white54 : colors.onSurfaceVariant,
            size: 18,
          ),
          filled: true,
          fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.primary, width: 1.2),
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<WhatsAppContact> contacts) {
    final filtered = _query.isEmpty
        ? contacts
        : contacts.where((c) {
            final name = c.name.toLowerCase();
            final num = c.number.toLowerCase();
            return name.contains(_query) || num.contains(_query);
          }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _query.isEmpty
              ? 'No hay contactos de WhatsApp disponibles'
              : 'No se encontraron coincidencias para "$_query"',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final contact = filtered[index];
        return WhatsAppContactCard(contact: contact, onTap: () {});
      },
    );
  }
}
