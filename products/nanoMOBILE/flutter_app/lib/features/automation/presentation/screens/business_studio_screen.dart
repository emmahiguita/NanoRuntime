import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/widgets/feather_core_icon.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart'
    show ruleRegistryProvider;
import 'package:nanoai/features/automation/engine/business/business_facts.dart';
import 'package:nanoai/features/automation/engine/business/business_facts_providers.dart';
import 'package:nanoai/features/automation/engine/messaging/messaging_package.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile_providers.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';
import 'package:nanoai/features/automation/presentation/automation_layout.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';
import 'package:nanoai/features/automation/presentation/widgets/dialogs/business_presets_sheet.dart';
import 'package:nanoai/features/automation/presentation/widgets/dialogs/delivery_edit_dialog.dart';
import 'package:nanoai/features/automation/presentation/widgets/dialogs/hours_edit_dialog.dart';
import 'package:nanoai/features/automation/presentation/widgets/dialogs/location_edit_dialog.dart';
import 'package:nanoai/features/automation/presentation/widgets/dialogs/payment_methods_dialog.dart';
import 'package:nanoai/features/automation/presentation/widgets/dialogs/product_dialog.dart';
import 'package:nanoai/features/automation/presentation/widgets/settings_tile_components.dart';

/// Pantalla dedicada y centralizada (SOLID - SRP) para la gestión integral de
/// WhatsApp Negocio: modo de respuesta, tono de venta, catálogo, pagos,
/// ubicación, horarios y plantillas comerciales.
class BusinessStudioScreen extends ConsumerWidget {
  const BusinessStudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = AutomationVisual.of(context);
    final facts = ref.watch(businessFactsNotifierProvider);
    final notifier = ref.read(businessFactsNotifierProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final tone = ref.watch(toneProfileNotifierProvider);
    final toneNotifier = ref.read(toneProfileNotifierProvider.notifier);

    final isW4bActive = ref.watch(ruleRegistryProvider).isWhatsAppRuleActive(
      MessagingPackage.whatsappBusiness,
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: NanoShellBarScope(
        slotId: 'business_studio',
        child: SafeArea(
          top: true,
          bottom: false,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, kNanoBarScrollReserve),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: AutomationLayout.contentMaxWidth(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AutomationBackHeader(),
                      const SizedBox(height: 16),
                      _buildHeaderBanner(visual),
                      const SizedBox(height: 20),

                      // SECCIÓN 1: MODO DE ATENCIÓN Y SUPERVISIÓN
                      const AutomationSectionLabel('Modo de Atención y Supervisión'),
                      SettingsCard(
                        children: [
                          SettingsRow(
                            featherType: FeatherCoreType.whatsappBusiness,
                            title: 'WhatsApp Business',
                            subtitle: isW4bActive
                                ? 'Activo — Atiende consultas comerciales'
                                : 'Inactivo — Toca para activar atención comercial',
                            trailing: Switch(
                              value: isW4bActive,
                              onChanged: (v) {
                                if (v) {
                                  ref
                                      .read(ruleRegistryProvider)
                                      .seedWhatsAppRule(
                                        MessagingPackage.whatsappBusiness,
                                      );
                                } else {
                                  ref
                                      .read(ruleRegistryProvider)
                                      .removeWhatsAppRule(
                                        MessagingPackage.whatsappBusiness,
                                      );
                                }
                              },
                            ),
                            showChevron: false,
                          ),
                          _buildAutonomyRow(settings, settingsNotifier),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // SECCIÓN 2: ESTRATEGIA Y TONO DE VENTA
                      const AutomationSectionLabel('Estrategia y Tono de Venta'),
                      SettingsCard(
                        children: [
                          SettingsRow(
                            imageAsset: 'assets/automation/icons/icon_enfoque_venta.png',
                            title: 'Enfoque de venta',
                            subtitle: tone.sales == ToneSales.persuasivo
                                ? 'Persuasivo — Resalta beneficios, crea urgencia y busca cerrar la venta'
                                : 'Natural — Informativo, responde claro sin presionar la compra',
                            trailing: ValueBadge(
                              label: tone.sales == ToneSales.persuasivo
                                  ? 'PERSUASIVO'
                                  : 'NATURAL',
                            ),
                            onTap: () => toneNotifier.update(
                              tone.copyWith(
                                enabled: true,
                                sales: tone.sales == ToneSales.persuasivo
                                    ? ToneSales.natural
                                    : ToneSales.persuasivo,
                              ),
                            ),
                          ),
                          SettingsRow(
                            imageAsset: 'assets/automation/icons/icon_trato_cliente.png',
                            title: 'Trato al cliente',
                            subtitle: tone.warmth == ToneWarmth.cercano
                                ? 'Cercano y amable (tuteo respetuoso)'
                                : 'Formal y respetuoso (usted)',
                            trailing: ValueBadge(
                              label: tone.warmth == ToneWarmth.cercano
                                  ? 'CERCANO'
                                  : 'FORMAL',
                            ),
                            onTap: () => toneNotifier.update(
                              tone.copyWith(
                                enabled: true,
                                warmth: tone.warmth == ToneWarmth.cercano
                                    ? ToneWarmth.formal
                                    : ToneWarmth.cercano,
                              ),
                            ),
                          ),
                          SettingsRow(
                            imageAsset: 'assets/automation/icons/icon_emoji.png',
                            title: 'Emojis en mensajes',
                            subtitle: tone.emojis
                                ? 'Permitidos con moderación comercial'
                                : 'Sin emojis (más formal y sobrio)',
                            trailing: Switch(
                              value: tone.emojis,
                              onChanged: (v) => toneNotifier.update(
                                tone.copyWith(enabled: true, emojis: v),
                              ),
                            ),
                            showChevron: false,
                          ),
                          SettingsRow(
                            imageAsset: 'assets/automation/icons/icon_extension.png',
                            title: 'Extensión de mensajes',
                            subtitle: switch (tone.verbosity) {
                              ToneVerbosity.breve =>
                                'Breve — Respuestas directas al grano',
                              ToneVerbosity.media =>
                                'Media — Equilibradas y completas',
                              ToneVerbosity.extensa =>
                                'Detallada — Explicaciones amplias si se requiere',
                            },
                            trailing: ValueBadge(
                              label: switch (tone.verbosity) {
                                ToneVerbosity.breve => 'BREVE',
                                ToneVerbosity.media => 'MEDIA',
                                ToneVerbosity.extensa => 'EXTENSA',
                              },
                            ),
                            onTap: () => toneNotifier.update(
                              tone.copyWith(
                                enabled: true,
                                verbosity: ToneVerbosity.values[
                                    (tone.verbosity.index + 1) %
                                        ToneVerbosity.values.length],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // SECCIÓN 3: CATÁLOGO DE PRODUCTOS / SERVICIOS
                      const AutomationSectionLabel('Catálogo Comercial'),
                      SettingsCard(
                        children: [
                          if (facts.products.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 24,
                                horizontal: 16,
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 40,
                                    color: visual.textMuted.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Sin productos configurados',
                                    style: TextStyle(
                                      color: visual.text,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Agrega productos manualmente o carga una plantilla para responder precios y stock.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: visual.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...facts.products.map(
                              (p) => SettingsRow(
                                icon: Icons.sell_outlined,
                                title: p.name,
                                subtitle: _productSubtitle(p),
                                trailing: Semantics(
                                  label: 'Eliminar producto',
                                  button: true,
                                  child: IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    color: visual.textMuted,
                                    onPressed: () => notifier.removeProduct(p.id),
                                  ),
                                ),
                                showChevron: false,
                                onTap: () async {
                                  final prod = await showDialog<BusinessProduct>(
                                    context: context,
                                    builder: (_) => ProductDialog(initial: p),
                                  );
                                  if (prod != null) {
                                    notifier.upsertProduct(prod);
                                  }
                                },
                              ),
                            ),
                          SettingsRow(
                            icon: Icons.add_circle_outline_rounded,
                            title: 'Agregar producto o servicio',
                            subtitle: 'Nombre, precio en pesos y stock disponible',
                            showChevron: false,
                            trailing: Icon(
                              Icons.add_rounded,
                              color: visual.accent,
                            ),
                            onTap: () async {
                              final prod = await showDialog<BusinessProduct>(
                                context: context,
                                builder: (_) => const ProductDialog(),
                              );
                              if (prod != null) {
                                notifier.upsertProduct(prod);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // SECCIÓN 4: INFORMACIÓN DEL NEGOCIO, PAGOS Y POLÍTICAS
                      const AutomationSectionLabel('Pagos, Ubicación y Políticas'),
                      SettingsCard(
                        children: [
                          SettingsRow(
                            imageAsset: 'assets/automation/icons/icon_metodos_pago.png',
                            title: 'Métodos de pago y transferencias',
                            subtitle: facts.payments.trim().isEmpty
                                ? 'Sin definir — Nequi, Daviplata, Bancolombia, etc.'
                                : facts.payments.trim(),
                            onTap: () async {
                              final text = await showDialog<String>(
                                context: context,
                                builder: (_) => PaymentMethodsDialog(
                                  initial: facts.payments,
                                ),
                              );
                              if (text != null) {
                                notifier.setPayments(text);
                              }
                            },
                          ),
                          SettingsRow(
                            imageAsset: 'assets/automation/icons/icon_ubicacion.png',
                            title: 'Ubicación o dirección',
                            subtitle: facts.location.trim().isEmpty
                                ? 'Sin definir — Sede física o tienda virtual'
                                : facts.location.trim(),
                            onTap: () async {
                              final text = await showDialog<String>(
                                context: context,
                                builder: (_) => LocationEditDialog(
                                  initial: facts.location,
                                ),
                              );
                              if (text != null) {
                                notifier.setLocation(text);
                              }
                            },
                          ),
                          SettingsRow(
                            imageAsset: 'assets/automation/icons/icon_horarios.png',
                            title: 'Horario de atención',
                            subtitle: facts.hours.trim().isEmpty
                                ? 'Sin definir — Franjas de atención'
                                : facts.hours.trim(),
                            onTap: () async {
                              final text = await showDialog<String>(
                                context: context,
                                builder: (_) => HoursEditDialog(
                                  initial: facts.hours,
                                ),
                              );
                              if (text != null) {
                                notifier.setHours(text);
                              }
                            },
                          ),
                          SettingsRow(
                            icon: Icons.local_shipping_outlined,
                            title: 'Envíos y domicilios',
                            subtitle: facts.delivery.trim().isEmpty
                                ? 'Sin definir — Cobertura y costos de entrega'
                                : facts.delivery.trim(),
                            onTap: () async {
                              final text = await showDialog<String>(
                                context: context,
                                builder: (_) => DeliveryEditDialog(
                                  initial: facts.delivery,
                                ),
                              );
                              if (text != null) {
                                notifier.setDelivery(text);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // SECCIÓN 5: PLANTILLAS POR RUBRO
                      const AutomationSectionLabel('Plantillas Rápidas'),
                      SettingsCard(
                        children: [
                          SettingsRow(
                            icon: Icons.dashboard_customize_outlined,
                            title: 'Cargar plantilla predefinida',
                            subtitle:
                                'Restaurante, Clínica, Barbería, Tienda de Ropa o Servicios',
                            trailing: const ValueBadge(label: 'PLANTILLAS'),
                            onTap: () => BusinessPresetsSheet.show(context),
                          ),
                          if (facts.products.isNotEmpty)
                            SettingsRow(
                              icon: Icons.cleaning_services_outlined,
                              title: 'Limpiar catálogo comercial',
                              subtitle:
                                  'Borrar productos actuales para empezar desde cero',
                              trailing: Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: visual.textMuted,
                              ),
                              showChevron: false,
                              onTap: () => _confirmResetCatalog(context, notifier),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
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

  Widget _buildHeaderBanner(AutomationVisualPalette visual) {
    return Row(
      children: [
        const FeatherCoreIcon(
          type: FeatherCoreType.whatsappBusiness,
          size: 52,
          glow: true,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WhatsApp Negocio',
                style: TextStyle(
                  color: visual.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Control total de ventas, catálogo, pagos y atención',
                style: TextStyle(
                  color: visual.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAutonomyRow(
    SettingsState settings,
    SettingsNotifier settingsNotifier,
  ) {
    final autonomy = ConversationAutonomyModeName.fromName(
      settings.waAutonomyMode,
    );
    return SettingsRow(
      icon: Icons.auto_awesome_rounded,
      title: 'Respuesta en WhatsApp',
      subtitle: switch (autonomy) {
        ConversationAutonomyMode.autonomous =>
          'Autónomo — Nano responde automáticamente al cliente',
        ConversationAutonomyMode.safeAuto =>
          'Auto Seguro — Responde lo seguro y retiene dudas para aprobación',
        ConversationAutonomyMode.suggestions =>
          'Supervisado — Redacta borradores con opciones para tu aprobación',
        ConversationAutonomyMode.disabled =>
          'Pausado — No responde automáticamente en WhatsApp',
      },
      trailing: ValueBadge(
        label: switch (autonomy) {
          ConversationAutonomyMode.autonomous => 'AUTÓNOMO',
          ConversationAutonomyMode.safeAuto => 'AUTO SEGURO',
          ConversationAutonomyMode.suggestions => 'SUPERVISADO',
          ConversationAutonomyMode.disabled => 'PAUSADO',
        },
      ),
      onTap: () {
        final next = switch (autonomy) {
          ConversationAutonomyMode.autonomous =>
            ConversationAutonomyMode.suggestions,
          ConversationAutonomyMode.suggestions =>
            ConversationAutonomyMode.safeAuto,
          ConversationAutonomyMode.safeAuto =>
            ConversationAutonomyMode.autonomous,
          ConversationAutonomyMode.disabled =>
            ConversationAutonomyMode.suggestions,
        };
        settingsNotifier.setWaAutonomyMode(next.name);
      },
    );
  }

  String _productSubtitle(BusinessProduct p) {
    final parts = <String>[];
    if (p.details.isNotEmpty) parts.add(p.details);
    parts.add('\$${_formatPrice(p.price)}');
    if (p.stock != null) {
      parts.add(p.stock! > 0 ? 'Stock: ${p.stock}' : 'Agotado');
    }
    return parts.join(' • ');
  }

  String _formatPrice(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    var count = 0;
    for (var i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) buffer.write('.');
    }
    return buffer.toString().split('').reversed.join('');
  }

  Future<void> _confirmResetCatalog(
    BuildContext context,
    BusinessFactsNotifier notifier,
  ) async {
    final visual = AutomationVisual.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: visual.isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('¿Vaciar catálogo?', style: TextStyle(color: visual.text, fontWeight: FontWeight.bold)),
        content: Text(
          'Se eliminarán los productos, pagos y políticas comerciales configuradas.',
          style: TextStyle(color: visual.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: TextStyle(color: visual.textMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      notifier.loadPreset(const BusinessFacts());
    }
  }
}
