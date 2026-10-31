import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/glass_surface.dart';
import '../../../application/nano_share_coordinator.dart';
import '../../../application/whatsapp_contacts_provider.dart';
import '../../../domain/nano_share_payload.dart';
import '../../../domain/whatsapp_contact.dart';

part 'nano_contact_picker_header.part.dart';
part 'nano_contact_picker_apps.part.dart';
part 'nano_contact_picker_permission_card.part.dart';
part 'nano_contact_picker_recents.part.dart';
part 'nano_contact_picker_list.part.dart';

/// Hoja modal de compartición contextual y selección de contactos para Nano Mobile.
///
/// QUÉ HACE:
/// - Despliega un panel Glass inferior para buscar y seleccionar destinatarios de WhatsApp o el sistema.
/// - Conecta recientes, agenda telefónica filtrada y accesos directos a WhatsApp Personal / Business.
///
/// CÓMO SE CONECTA:
/// - Invocada por NanoShareCoordinator.showPicker(...).
///
/// POR QUÉ:
/// - Proporciona una experiencia nativa in-app sin depender de navegación externa ciega (< 120 líneas).
class NanoContactPickerSheet extends ConsumerStatefulWidget {
  final NanoSharePayload payload;

  const NanoContactPickerSheet({
    super.key,
    required this.payload,
  });

  @override
  ConsumerState<NanoContactPickerSheet> createState() =>
      _NanoContactPickerSheetState();
}

class _NanoContactPickerSheetState extends ConsumerState<NanoContactPickerSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onContactTap(WhatsAppContact contact) {
    Navigator.of(context).pop();
    NanoShareCoordinator.dispatchToContact(
      context: context,
      contact: contact,
      payload: widget.payload,
      ref: ref,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: GlassSurface(
          radius: 28,
          blur: 24,
          opacity: isDark ? 0.85 : 0.94,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NanoContactPickerHeader(
                payload: widget.payload,
                searchController: _searchController,
                searchQuery: _searchQuery,
                onQueryChanged: (val) => setState(() => _searchQuery = val),
                onClearQuery: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _NanoContactPickerRecents(onContactSelected: _onContactTap),
                      _NanoContactPickerApps(payload: widget.payload),
                      _NanoContactPickerList(
                        searchQuery: _searchQuery,
                        onContactSelected: _onContactTap,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
