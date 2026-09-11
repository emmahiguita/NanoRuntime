import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart'
    show ruleRegistryProvider;
import 'package:nanoai/features/automation/domain/automation_policy.dart';
import 'package:nanoai/features/automation/engine/business/business_facts.dart';
import 'package:nanoai/features/automation/engine/business/business_facts_providers.dart';
import 'package:nanoai/features/automation/engine/business/business_presets.dart';
import 'package:nanoai/features/automation/engine/messaging/messaging_package.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile_providers.dart';
import 'package:nanoai/features/automation/presentation/automation_layout.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';
import 'package:nanoai/features/automation/presentation/widgets/settings_tile_components.dart';

/// Pantalla dedicada y centralizada (SOLID - SRP) para la gestión integral de
/// WhatsApp Negocio: modo de respuesta, tono de venta, catálogo, pagos,
/// ubicación, horarios y plantillas.
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
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: visual.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: visual.accent.withValues(
                                  alpha: visual.isDark ? 0.35 : 0.22,
                                ),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: visual.accent.withValues(alpha: 0.12),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.asset(
                                'assets/automation/whatsapp_business_icon.png',
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
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
                      ),
                      const SizedBox(height: 20),

                      // SECCIÓN 1: MODO DE ATENCIÓN Y SUPERVISIÓN
                      const AutomationSectionLabel('Modo de Atención y Supervisión'),
                      SettingsCard(
                        children: [
                          SettingsRow(
                            imageAsset: 'assets/automation/whatsapp_business_icon.png',
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
                          SettingsRow(
                            icon: Icons.auto_awesome_rounded,
                            title: 'Respuesta en WhatsApp',
                            subtitle: switch (settings.agentAutomationMode) {
                              AgentAutomationMode.autonomous =>
                                'Autónomo — Nano responde automáticamente al cliente',
                              AgentAutomationMode.assisted =>
                                'Asistido — Nano redacta el borrador para que tú lo apruebes',
                              AgentAutomationMode.manual =>
                                'Manual — Respuestas pausadas en WhatsApp',
                            },
                            trailing: ValueBadge(
                              label: switch (settings.agentAutomationMode) {
                                AgentAutomationMode.autonomous => 'AUTÓNOMO',
                                AgentAutomationMode.assisted => 'ASISTIDO',
                                AgentAutomationMode.manual => 'MANUAL',
                              },
                            ),
                            onTap: () {
                              final next = switch (settings.agentAutomationMode) {
                                AgentAutomationMode.autonomous =>
                                  AgentAutomationMode.assisted,
                                AgentAutomationMode.assisted =>
                                  AgentAutomationMode.autonomous,
                                AgentAutomationMode.manual =>
                                  AgentAutomationMode.assisted,
                              };
                              settingsNotifier.setAgentAutomationMode(next);
                            },
                          ),
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
                                trailing: IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  color: visual.textMuted,
                                  tooltip: 'Eliminar producto',
                                  onPressed: () => notifier.removeProduct(p.id),
                                ),
                                showChevron: false,
                              ),
                            ),
                          SettingsRow(
                            icon: Icons.add_circle_outline_rounded,
                            title: 'Agregar producto o servicio',
                            subtitle:
                                'Nombre, precio en pesos y stock disponible',
                            showChevron: false,
                            trailing: Icon(
                              Icons.add_rounded,
                              color: visual.accent,
                            ),
                            onTap: () async {
                              final prod =
                                  await showDialog<BusinessProduct>(
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
                                builder: (_) => TextEditDialog(
                                  title: 'Métodos de pago autorizados',
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
                                builder: (_) => TextEditDialog(
                                  title: 'Ubicación o dirección física',
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
                                builder: (_) => TextEditDialog(
                                  title: 'Horario de atención',
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
                                builder: (_) => TextEditDialog(
                                  title: 'Envíos y domicilios',
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
                            onTap: () => _openPresetsSheet(context, ref),
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
                              onTap: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('¿Vaciar catálogo?'),
                                    content: const Text(
                                      'Se eliminarán los productos, pagos y políticas comerciales.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: const Text('Vaciar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  notifier.loadPreset(const BusinessFacts());
                                }
                              },
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

  void _openPresetsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final visual = AutomationVisual.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Plantillas de negocio predefinidas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: visual.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Carga productos, horarios, pagos y políticas con un solo toque.',
                  style: TextStyle(
                    fontSize: 12,
                    color: visual.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: BusinessPresetsCatalog.presets.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final preset = BusinessPresetsCatalog.presets[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: visual.accentSoft,
                          child: Icon(preset.icon, color: visual.accent),
                        ),
                        title: Text(
                          preset.title,
                          style: TextStyle(
                            color: visual.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          preset.description,
                          style: TextStyle(
                            color: visual.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dlgContext) => AlertDialog(
                              title: Text('Aplicar estrategia "${preset.title}"'),
                              content: Text(
                                'Se configurará el tono comercial (${preset.tone.sales == ToneSales.persuasivo ? "Persuasivo" : "Natural"}, trato ${preset.tone.warmth == ToneWarmth.cercano ? "Cercano" : "Formal"}).\n\n'
                                'Tus productos reales, precios y métodos de pago deben ser agregados por ti.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dlgContext).pop(false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(dlgContext).pop(true),
                                  child: const Text('Aplicar'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true && context.mounted) {
                            await ref
                                .read(toneProfileNotifierProvider.notifier)
                                .update(preset.tone);
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Estrategia de venta para "${preset.title}" aplicada.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ProductDialog extends StatefulWidget {
  const ProductDialog({super.key});

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final _name = TextEditingController();
  final _variant = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _variant.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return AlertDialog(
      backgroundColor: visual.surface,
      title: Text('Nuevo producto', style: TextStyle(color: visual.text)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre (ej. Galaxy S24)',
              ),
            ),
            TextField(
              controller: _variant,
              decoration: const InputDecoration(
                labelText: 'Variante (ej. negro 256GB) — opcional',
              ),
            ),
            TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Precio en pesos (ej. 899000)',
              ),
            ),
            TextField(
              controller: _stock,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stock (número) — opcional',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: visual.textMuted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }

  void _save() {
    final name = _name.text.trim();
    final price = int.tryParse(_price.text.trim());
    if (name.isEmpty || price == null || price <= 0) {
      setState(() {
        _error = 'Nombre obligatorio y precio numérico mayor que cero.';
      });
      return;
    }
    final stock = int.tryParse(_stock.text.trim());
    Navigator.of(context).pop(
      BusinessProduct(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        details: _variant.text.trim(),
        price: price,
        stock: stock,
      ),
    );
  }
}

class TextEditDialog extends StatefulWidget {
  const TextEditDialog({super.key, required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<TextEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return AlertDialog(
      backgroundColor: visual.surface,
      title: Text(widget.title, style: TextStyle(color: visual.text)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        minLines: 1,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final v = _controller.text.trim();
            if (v.isEmpty) return;
            Navigator.of(context).pop(v);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

