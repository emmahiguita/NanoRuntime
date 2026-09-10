import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/automation/engine/business/business_facts.dart';
import 'package:nanoai/features/automation/engine/business/business_facts_providers.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile_providers.dart';
import 'package:nanoai/features/automation/personal_agent/application/persona_context.dart';
import 'package:nanoai/features/automation/personal_agent/application/persona_repository.dart';
import '../automation_visual_theme.dart';
import 'settings_tile_components.dart';

/// PERSONA-PROFILE-05 — perfil del dueño (nombre + datos que Nano debe
/// saber) y perfiles de relación por contacto. Guardado automático.
class PersonalAgentCard extends ConsumerStatefulWidget {
  const PersonalAgentCard({super.key});

  @override
  ConsumerState<PersonalAgentCard> createState() => _PersonalAgentCardState();
}

class _PersonalAgentCardState extends ConsumerState<PersonalAgentCard> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final personas = await PersonaRepository.instance.listPersonas();
      final owner = personas.where((p) => p.personaKey == 'owner').firstOrNull;
      if (!mounted) return;
      setState(() {
        _nameController.text = owner?.displayName ?? '';
        _notesController.text = owner?.facts['notas'] ?? '';
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo leer tu perfil. Reintenta antes de editarlo.';
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving || _loading || _error != null) return;
    final name = _nameController.text.trim();
    final notes = _notesController.text.trim();
    if (name.length > 80 || notes.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Máximo 80 caracteres para el nombre y 500 para las notas.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = PersonaRepository.instance;
      final profiles = await repo.listPersonas();
      final owner = profiles.where((p) => p.personaKey == 'owner').firstOrNull;
      final saved = await repo.upsertPersona('owner', name, {
        ...?owner?.facts,
        'notas': notes,
      });
      if (!saved) throw StateError('No se pudo guardar el perfil.');
      if (!mounted) return;
      await ref.read(personaContextProvider).refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Perfil guardado.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo completar el guardado. Reintenta.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: visual.textMuted)),
                TextButton(onPressed: _load, child: const Text('Reintentar')),
              ],
              TextField(
                controller: _nameController,
                enabled: !_loading && !_saving && _error == null,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Tu nombre',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                style: TextStyle(color: visual.text, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                enabled: !_loading && !_saving && _error == null,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Preferencias estables sobre ti',
                  hintText: 'Ej. Prefiero respuestas cortas.',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                style: TextStyle(color: visual.text, fontSize: 14),
              ),
              FilledButton(
                onPressed: _loading || _saving || _error != null ? null : _save,
                child: Text(_saving ? 'Guardando…' : 'Guardar perfil'),
              ),
              const SizedBox(height: 8),
              Text(
                'Contactos, ejemplos y memorias se administran en «Aprender de mis conversaciones».',
                style: TextStyle(color: visual.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// WA-BUSINESS-01 — datos reales del negocio que el agente puede afirmar:
/// productos (nombre, variante, precio, stock), horario y envío. Se guardan
/// en el store durable y viajan al prompt como bloque <DATOS DEL NEGOCIO>.
class BusinessDataCard extends ConsumerWidget {
  const BusinessDataCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facts = ref.watch(businessFactsNotifierProvider);
    final products = facts.products;
    return SettingsCard(
      children: [
        SettingsRow(
          icon: Icons.sell_outlined,
          title: 'Productos',
          subtitle: products.isEmpty
              ? 'Sin productos — el agente no afirmará precios ni stock'
              : '${products.length} producto${products.length == 1 ? '' : 's'} · '
                    'primero: ${products.first.name}',
          trailing: ValueBadge(label: '${products.length}'),
          onTap: () => _openProductsSheet(context, ref),
        ),
        SettingsRow(
          icon: Icons.schedule_rounded,
          title: 'Horario',
          subtitle: facts.hours.trim().isEmpty
              ? 'Sin definir — no lo afirmará'
              : facts.hours.trim(),
          onTap: () => _editText(
            context,
            ref,
            title: 'Horario del negocio',
            initial: facts.hours,
            onSave: (v) =>
                ref.read(businessFactsNotifierProvider.notifier).setHours(v),
          ),
        ),
        SettingsRow(
          icon: Icons.local_shipping_outlined,
          title: 'Envío',
          subtitle: facts.delivery.trim().isEmpty
              ? 'Sin definir — no lo afirmará'
              : facts.delivery.trim(),
          onTap: () => _editText(
            context,
            ref,
            title: 'Envío',
            initial: facts.delivery,
            onSave: (v) =>
                ref.read(businessFactsNotifierProvider.notifier).setDelivery(v),
          ),
        ),
      ],
    );
  }

  void _openProductsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
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
                'Productos del catálogo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AutomationVisual.of(sheetContext).text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'El agente responde precios y stock SOLO de lo que está aquí.',
                style: TextStyle(
                  fontSize: 12,
                  color: AutomationVisual.of(sheetContext).textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Consumer(
                  builder: (context, ref, _) {
                    final list = ref
                        .watch(businessFactsNotifierProvider)
                        .products;
                    if (list.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Sin productos todavía.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AutomationVisual.of(context).textMuted,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final p = list[i];
                        final variant = p.details.trim();
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            variant.isEmpty ? p.name : '${p.name} ($variant)',
                            style: TextStyle(
                              color: AutomationVisual.of(context).text,
                            ),
                          ),
                          subtitle: Text(
                            '${p.priceLabel}'
                            '${p.stock == null ? ' · stock no informado' : (p.stock == 0 ? ' · agotado' : ' · stock ${p.stock}')}',
                            style: TextStyle(
                              color: AutomationVisual.of(context).textMuted,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: AutomationVisual.of(context).textMuted,
                            ),
                            tooltip: 'Quitar producto',
                            onPressed: () => ref
                                .read(businessFactsNotifierProvider.notifier)
                                .removeProduct(p.id),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _addProduct(sheetContext, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Agregar producto'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addProduct(BuildContext context, WidgetRef ref) async {
    final product = await showDialog<BusinessProduct>(
      context: context,
      builder: (_) => const ProductDialog(),
    );
    if (product == null) return;
    await ref
        .read(businessFactsNotifierProvider.notifier)
        .upsertProduct(product);
  }

  Future<void> _editText(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String initial,
    required Future<void> Function(String) onSave,
  }) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => TextEditDialog(title: title, initial: initial),
    );
    if (value == null || value.trim().isEmpty) return;
    await onSave(value);
  }
}

/// WA-NATURAL-01 — perfil de tono de las respuestas automáticas.
class ToneCard extends ConsumerWidget {
  const ToneCard({super.key});

  static const _warmthLabels = {
    ToneWarmth.cercano: 'Cercano',
    ToneWarmth.formal: 'Formal',
  };
  static const _verbosityLabels = {
    ToneVerbosity.breve: 'Breve',
    ToneVerbosity.media: 'Media',
    ToneVerbosity.extensa: 'Extensa',
  };
  static const _salesLabels = {
    ToneSales.natural: 'Natural',
    ToneSales.persuasivo: 'Persuasivo',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(toneProfileNotifierProvider);
    final notifier = ref.read(toneProfileNotifierProvider.notifier);
    return SettingsCard(
      children: [
        SettingsRow(
          icon: Icons.record_voice_over_outlined,
          title: 'Tono automático',
          subtitle: profile.enabled
              ? 'Activo — guía de forma en las respuestas'
              : 'Inactivo — respuestas como hasta ahora',
          trailing: Switch(
            value: profile.enabled,
            onChanged: (v) => notifier.update(profile.copyWith(enabled: v)),
          ),
          showChevron: false,
        ),
        if (profile.enabled) ...[
          SettingsRow(
            icon: Icons.waving_hand_outlined,
            title: 'Trato',
            subtitle: 'Cómo se dirige al cliente',
            trailing: ValueBadge(
              label: _warmthLabels[profile.warmth]!.toUpperCase(),
            ),
            onTap: () => notifier.update(
              profile.copyWith(
                warmth:
                    ToneWarmth.values[(profile.warmth.index + 1) %
                        ToneWarmth.values.length],
              ),
            ),
            showChevron: false,
          ),
          SettingsRow(
            icon: Icons.format_size_rounded,
            title: 'Extensión',
            subtitle: 'Longitud típica de las respuestas',
            trailing: ValueBadge(
              label: _verbosityLabels[profile.verbosity]!.toUpperCase(),
            ),
            onTap: () => notifier.update(
              profile.copyWith(
                verbosity:
                    ToneVerbosity.values[(profile.verbosity.index + 1) %
                        ToneVerbosity.values.length],
              ),
            ),
            showChevron: false,
          ),
          SettingsRow(
            icon: Icons.emoji_emotions_outlined,
            title: 'Emojis',
            subtitle: profile.emojis ? 'Con moderación' : 'Sin emojis',
            trailing: Switch(
              value: profile.emojis,
              onChanged: (v) => notifier.update(profile.copyWith(emojis: v)),
            ),
            showChevron: false,
          ),
          SettingsRow(
            icon: Icons.trending_up_rounded,
            title: 'Venta',
            subtitle: 'Presión comercial en las respuestas',
            trailing: ValueBadge(
              label: _salesLabels[profile.sales]!.toUpperCase(),
            ),
            onTap: () => notifier.update(
              profile.copyWith(
                sales:
                    ToneSales.values[(profile.sales.index + 1) %
                        ToneSales.values.length],
              ),
            ),
            showChevron: false,
          ),
        ],
      ],
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
