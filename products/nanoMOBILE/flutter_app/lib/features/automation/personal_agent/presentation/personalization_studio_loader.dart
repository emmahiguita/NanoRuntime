part of 'personalization_studio_screen.dart';

/// PERSONALIZATION-STUDIO-DATA-LOADER — Carga reactiva de perfiles y estados.
///
/// **QUÉ HACE:**
/// Consulta SQLite y la API del runtime de notificaciones para consolidar
/// el estado completo del estudio de personalización del Agente EMMA.
///
/// **CÓMO FUNCIONA:**
/// Ejecuta consultas protegidas por generación para descartar resultados
/// obsoletos ante navegación rápida o cambios de scope.
///
/// **POR QUÉ:**
/// Extrae la orquestación de datos de la pantalla visual reduciendo su tamaño a < 200 líneas.
extension _PersonalizationStudioDataLoader on _PersonalizationStudioScreenState {
  Future<void> _reload() async {
    if (!mounted) return;
    final gen = ++_reloadGeneration;
    final req = _scope;
    _safeSetState(() => _loading = true);
    try {
      await ensurePersonalStyleSeed(_repo);
      final sum = await _repo.personalizationSummary();
      final profs = await _repo.listRelationships();
      final owners = await _repo.listPersonas();
      final active = await NanoRuntimeApi.instance.listNotifications(limit: 100);
      final scs = <String, _Scope>{
        'owner': const _Scope('owner', 'Estilo global del dueño'),
        'role:personal': const _Scope('role:personal', 'Rol: personal'),
        'role:sales': const _Scope('role:sales', 'Rol: ventas / negocio'),
        'role:support': const _Scope('role:support', 'Rol: soporte'),
      };
      for (final p in profs) {
        scs[p.relationshipKey] = _Scope(p.relationshipKey, p.displayName, profile: p, conversationId: p.facts['conversationId']);
      }
      for (final k in (sum['scopeKeys'] as List? ?? const []).whereType<String>()) {
        if (k.isNotEmpty && !scs.containsKey(k)) {
          scs[k] = _Scope(k, _scopes[k]?.label ?? 'Perfil · ', conversationId: _scopes[k]?.conversationId);
        }
      }
      for (final r in active) {
        final n = NotificationObject.fromMap(r);
        final id = resolveConversationIdentity(n);
        if (id.safeToWrite && id.key.id.isNotEmpty && n.canReply) {
          final k = personalizationScope(id.key.id);
          final lbl = n.isGroup ? n.conversationTitle : n.sender;
          if (lbl.isNotEmpty) scs[k] = _Scope(k, ' · ', conversationId: id.key.id, profile: scs[k]?.profile);
        }
      }
      final sel = scs.containsKey(req) ? req : 'owner';
      final exs = await _repo.listExamples(limit: 100, scopeKey: sel);
      final mems = await _repo.listPersonalMemories(scopeKey: sel, limit: 100);
      if (!mounted || gen != _reloadGeneration) return;
      _safeSetState(() {
        _summary = sum; _scopes = scs; _scope = sel; _owner = owners.where((o) => o.personaKey == 'owner').firstOrNull;
        _examples = exs; _memories = mems; _error = null; _loading = false;
      });
    } catch (e) {
      if (mounted && gen == _reloadGeneration) _safeSetState(() { _error = ''; _loading = false; });
    }
  }
}
