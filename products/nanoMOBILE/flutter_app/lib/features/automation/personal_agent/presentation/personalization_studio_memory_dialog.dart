/// PERSONALIZATION-STUDIO-MEMORY-01 — Diálogo de edición de memorias personales.
///
/// **QUÉ HACE:**
/// Permite crear o editar recuerdos episódicos y preferencias del usuario.
///
/// **CÓMO FUNCIONA:**
/// Validación de claves, valores y fechas de caducidad con scroll seguro en portrait y landscape.
///
/// **POR QUÉ:**
/// Asegura la consistencia temporal y previene distorsiones visuales en el teclado o rotación.
part of 'personalization_studio_screen.dart';

class _MemoryEditDialog extends StatefulWidget {
  const _MemoryEditDialog({
    required this.initialScope,
    required this.scopes,
    required this.busy,
    this.memory,
  });
  final PersonalMemory? memory;
  final String initialScope;
  final Map<String, _Scope> scopes;
  final bool busy;

  @override
  State<_MemoryEditDialog> createState() => _MemoryEditDialogState();
}

class _MemoryEditDialogState extends State<_MemoryEditDialog> {
  late final TextEditingController _key, _value, _observed, _expiry;
  late String kind, scope;
  late bool enabled;

  @override
  void initState() {
    super.initState();
    final m = widget.memory;
    _key = TextEditingController(text: m?.key ?? '');
    _value = TextEditingController(text: m?.value ?? '');
    _observed = TextEditingController(
      text: DateTime.fromMillisecondsSinceEpoch(
        m?.observedAt ?? DateTime.now().millisecondsSinceEpoch,
      ).toIso8601String(),
    );
    _expiry = TextEditingController(
      text: m?.expiresAt == null
          ? ''
          : DateTime.fromMillisecondsSinceEpoch(m!.expiresAt!).toIso8601String(),
    );
    kind = personalMemoryKinds.containsKey(m?.kind)
        ? m!.kind
        : m == null ? 'stablePreference' : 'episodicMemory';
    scope = widget.initialScope;
    enabled = m?.enabled ?? true;
  }

  @override
  void dispose() {
    _key.dispose();
    _value.dispose();
    _observed.dispose();
    _expiry.dispose();
    super.dispose();
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  void _submit() {
    final k = _key.text.trim(), v = _value.text.trim();
    final at = DateTime.tryParse(_observed.text);
    final until = _expiry.text.trim().isEmpty ? null : DateTime.tryParse(_expiry.text);
    if (k.isEmpty || v.isEmpty || at == null ||
        (_expiry.text.trim().isNotEmpty && (until == null || !until.isAfter(at))) ||
        (kind == 'temporaryFact' && (until == null || !until.isAfter(at)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verifica las fechas. Los datos temporales deben caducar después de observarse.')),
      );
      return;
    }
    Navigator.pop(
      context,
      _MemoryResult(
        scope: scope,
        key: k,
        value: v,
        kind: kind,
        observedAt: at,
        expiresAt: until,
        enabled: enabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isLandscape ? 8 : 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: EdgeInsets.fromLTRB(20, isLandscape ? 10 : 18, 20, isLandscape ? 4 : 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isLandscape ? 4 : 10),
      title: const Text('Memoria personal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isLandscape ? 500 : 380,
          maxHeight: size.height * (isLandscape ? 0.74 : 0.65),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey(scope),
                initialValue: widget.scopes.containsKey(scope) ? scope : 'owner',
                isExpanded: true,
                decoration: _deco('Aplicar solamente a'),
                items: [
                  for (final s in widget.scopes.values)
                    DropdownMenuItem(value: s.id, child: Text(s.label, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: widget.busy ? null : (v) => v != null ? setState(() => scope = v) : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: kind,
                isExpanded: true,
                decoration: _deco('Clasificación'),
                items: [
                  for (final entry in personalMemoryKinds.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (v) => setState(() => kind = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _key,
                maxLength: 120,
                decoration: _deco('Asunto / clave'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _value,
                maxLength: 2000,
                maxLines: 3,
                decoration: _deco('Dato declarado'),
              ),
              const SizedBox(height: 8),
              TextField(controller: _observed, decoration: _deco('Fecha de registro (ISO)')),
              const SizedBox(height: 10),
              TextField(controller: _expiry, decoration: _deco(kind == 'temporaryFact' ? 'Caduca (obligatorio ISO)' : 'Caduca (opcional ISO)')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Memoria activa', style: TextStyle(fontSize: 12)),
                value: enabled,
                onChanged: (v) => setState(() => enabled = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
