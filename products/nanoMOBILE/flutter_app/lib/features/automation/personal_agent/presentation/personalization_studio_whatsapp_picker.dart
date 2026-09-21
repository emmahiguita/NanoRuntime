part of 'personalization_studio_screen.dart';

/// PERSONALIZATION-STUDIO-WHATSAPP-PICKER — Selector de Contactos Reales de WhatsApp.
///
/// **QUÉ HACE:**
/// Consulta los contactos reales del teléfono que poseen cuenta activa de WhatsApp
/// (personal o Business) mediante ContactsContract de Android y permite seleccionarlos
/// para preparar el perfil del agente sin escribir manualmente.
///
/// **CÓMO FUNCIONA:**
/// Invoca WhatsAppContactsService por MethodChannel ('com.nanoai/contacts'), verifica y
/// solicita permisos READ_CONTACTS, ofreciendo búsqueda instantánea y badges visuales.
///
/// **POR QUÉ:**
/// Elimina fricción de entrada de datos, garantiza identidades telefónicas verídicas
/// y cumple con Single Responsibility con código menor a 200 líneas.
class _WhatsAppContactPickerDialog extends StatefulWidget {
  final Map<String, _Scope> existingScopes;

  const _WhatsAppContactPickerDialog({required this.existingScopes});

  @override
  State<_WhatsAppContactPickerDialog> createState() => _WhatsAppContactPickerDialogState();
}

class _WhatsAppContactPickerDialogState extends State<_WhatsAppContactPickerDialog> {
  final _service = WhatsAppContactsService();
  final _searchCtrl = TextEditingController();
  List<WhatsAppContact> _all = [];
  List<WhatsAppContact> _filtered = [];
  bool _loading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkAndLoad();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAndLoad() async {
    final has = await _service.hasPermission();
    if (!mounted) return;
    setState(() => _hasPermission = has);
    if (has) {
      final list = await _service.getContacts();
      if (!mounted) return;
      setState(() {
        _all = list;
        _filtered = list;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _loading = true);
    final granted = await _service.requestPermission();
    if (!mounted) return;
    setState(() => _hasPermission = granted);
    if (granted) {
      final list = await _service.getContacts();
      if (!mounted) return;
      setState(() {
        _all = list;
        _filtered = list;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _all;
      } else {
        _filtered = _all.where((c) => c.name.toLowerCase().contains(q) || c.number.contains(q)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0x22FFFFFF))),
      backgroundColor: const Color(0xFF162036),
      titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      title: Row(
        children: [
          const Icon(Icons.perm_contact_calendar_rounded, size: 16, color: Color(0xFF25D366)),
          const SizedBox(width: 8),
          const Expanded(child: Text('Contactos de WhatsApp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
          TextButton(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
            onPressed: () => Navigator.of(context).pop('manual'),
            child: const Text('Manual', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        height: size.height * 0.58,
        child: _buildBody(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar', style: TextStyle(fontSize: 11))),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF25D366), strokeWidth: 2));
    }
    if (!_hasPermission) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security, size: 36, color: Colors.white38),
          const SizedBox(height: 10),
          const Text('Acceso a contactos requerido', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('NanoAI identifica automáticamente los contactos con WhatsApp en tu libreta.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.white60)),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.black),
            onPressed: _requestPermission,
            icon: const Icon(Icons.check_circle_outline, size: 14),
            label: const Text('Permitir acceso', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }
    return Column(
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: _onSearch,
          style: const TextStyle(fontSize: 11),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Buscar en ${_all.length} contactos de WhatsApp...',
            hintStyle: const TextStyle(fontSize: 10.5, color: Colors.white38),
            prefixIcon: const Icon(Icons.search, size: 14, color: Color(0xFF25D366)),
            filled: true,
            fillColor: const Color(0x0CFFFFFF),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0x22FFFFFF))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0x22FFFFFF))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0x8025D366))),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _filtered.isEmpty
              ? Center(child: Text(_all.isEmpty ? 'No se encontraron contactos con WhatsApp' : 'Sin coincidencias', style: const TextStyle(fontSize: 11, color: Colors.white54)))
              : ListView.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x12FFFFFF)),
                  itemBuilder: (_, i) {
                    final c = _filtered[i];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0x2525D366),
                        child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF25D366))),
                      ),
                      title: Text(c.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(c.number.isNotEmpty ? c.number : c.jid, style: const TextStyle(fontSize: 9.5, color: Colors.white60)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0x1825D366), borderRadius: BorderRadius.circular(5), border: Border.all(color: const Color(0x4025D366), width: 0.6)),
                        child: Text(c.isBusiness ? 'WhatsApp Business' : 'WhatsApp', style: const TextStyle(fontSize: 8.5, color: Color(0xFF25D366), fontWeight: FontWeight.w600)),
                      ),
                      onTap: () => Navigator.of(context).pop(c),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
