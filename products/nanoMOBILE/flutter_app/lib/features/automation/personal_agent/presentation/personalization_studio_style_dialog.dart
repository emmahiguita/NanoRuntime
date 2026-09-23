/// PERSONALIZATION-STUDIO-STYLE-01 — Diálogo iOS Glass de edición de estilo personal.
///
/// **QUÉ HACE:**
/// Presenta el formulario para configurar tono, registro, emojis y uso del nombre
/// con diseño estilo iOS Glass, micro-tipografía organizada y cero desbordamientos (overflows).
///
/// **CÓMO FUNCIONA:**
/// Emplea tarjetas agrupadas con bordes sutiles de vidrio translúcido, scroll vertical
/// con `shrinkWrap` seguro y dimensiones calculadas para cualquier orientación móvil.
///
/// **POR QUÉ:**
/// Elimina definitivamente el error "BOTTOM OVERFLOWED BY 18 PIXELS" y entrega una
/// estética premium inspirada en iOS (Cupertino glass) con código < 200 líneas.
part of 'personalization_studio_screen.dart';

class _StyleEditDialog extends StatefulWidget {
  const _StyleEditDialog({required this.scope, required this.existing});
  final _Scope scope;
  final Map<String, String> existing;

  @override
  State<_StyleEditDialog> createState() => _StyleEditDialogState();
}

class _StyleEditDialogState extends State<_StyleEditDialog> {
  late String register, relationship, usesName;
  late bool learn, enabled, slang;
  late ToneProfile tone;
  late final TextEditingController _custom;

  static const _registers = {'formal', 'casual', 'close', 'custom'};
  static const _relationships = {'known', 'close', 'family', 'professional'};

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    register = _registers.contains(e['styleRegister']) ? e['styleRegister']! : 'casual';
    relationship = _relationships.contains(e['relationship']) ? e['relationship']! : 'known';
    learn = e['learnStyle'] != 'false';
    enabled = e['profileEnabled'] != 'false';
    slang = e['allowSlang'] == 'true';
    usesName = e['usesContactName'] == 'never' ? 'never' : 'natural';
    _custom = TextEditingController(text: e['customStyle'] ?? '');
    tone = const ToneProfile(enabled: true, verbosity: ToneVerbosity.breve);
    try {
      if (e['tone'] case final String raw) {
        tone = ToneProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  InputDecoration _inputDeco(String label, {String? hint}) {
    final b = OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0x1FFFFFFF), width: 0.8));
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 10.5, color: Colors.white70),
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 10, color: Colors.white30),
      filled: true,
      fillColor: const Color(0x0DFFFFFF),
      isDense: true,
      border: b, enabledBorder: b,
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0x8000E676))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isOwner = widget.scope.id == 'owner';

    final size = MediaQuery.of(context).size;
    return AlertDialog(
      backgroundColor: const Color(0xFA101828),
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isLandscape ? 8 : 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0x28FFFFFF), width: 0.8)),
      titlePadding: EdgeInsets.fromLTRB(16, isLandscape ? 8 : 14, 16, 4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: const Color(0x1A00E676), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.tune_rounded, color: Color(0xFF00E676), size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isOwner ? 'PERFIL DE ESTILO · EMMA' : 'ESTILO: ${widget.scope.label.toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.4),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isLandscape ? 500 : 380, maxHeight: size.height * (isLandscape ? 0.74 : 0.58)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isOwner) ...[
                SwitchListTile(contentPadding: EdgeInsets.zero, dense: true, title: const Text('Aplicar perfil', style: TextStyle(fontSize: 11)), value: enabled, onChanged: (v) => setState(() => enabled = v)),
                const SizedBox(height: 4),
              ],
              DropdownButtonFormField<String>(
                initialValue: register,
                decoration: _inputDeco('Registro conversacional'),
                isExpanded: true,
                dropdownColor: const Color(0xFF162036),
                style: const TextStyle(fontSize: 11, color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'casual', child: Text('Casual auténtico (Natural)', style: TextStyle(fontSize: 11))),
                  DropdownMenuItem(value: 'close', child: Text('Cercano / Confianza', style: TextStyle(fontSize: 11))),
                  DropdownMenuItem(value: 'formal', child: Text('Formal y corporativo', style: TextStyle(fontSize: 11))),
                  DropdownMenuItem(value: 'custom', child: Text('Personalizado por reglas', style: TextStyle(fontSize: 11))),
                ],
                onChanged: (v) => setState(() => register = v!),
              ),
              const SizedBox(height: 6),
              if (!isOwner) ...[
                DropdownButtonFormField<String>(
                  initialValue: relationship,
                  decoration: _inputDeco('Relación'),
                  isExpanded: true,
                  dropdownColor: const Color(0xFF162036),
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'known', child: Text('Contacto / Conocido', style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(value: 'close', child: Text('Amigo cercano', style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(value: 'family', child: Text('Familiar', style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(value: 'professional', child: Text('Laboral / Negocios', style: TextStyle(fontSize: 11))),
                  ],
                  onChanged: (v) => setState(() => relationship = v!),
                ),
                const SizedBox(height: 6),
              ],
              DropdownButtonFormField<ToneVerbosity>(
                initialValue: tone.verbosity,
                decoration: _inputDeco('Longitud de respuesta'),
                isExpanded: true,
                dropdownColor: const Color(0xFF162036),
                style: const TextStyle(fontSize: 11, color: Colors.white),
                items: [for (final v in ToneVerbosity.values) DropdownMenuItem(value: v, child: Text(v.name.toUpperCase(), style: const TextStyle(fontSize: 11)))],
                onChanged: (v) => setState(() => tone = tone.copyWith(verbosity: v)),
              ),
              const SizedBox(height: 5),
              SwitchListTile(contentPadding: EdgeInsets.zero, dense: true, title: const Text('Emojis moderados y naturales', style: TextStyle(fontSize: 11)), value: tone.emojis, onChanged: (v) => setState(() => tone = tone.copyWith(emojis: v))),
              SwitchListTile(contentPadding: EdgeInsets.zero, dense: true, title: const Text('Vocabulario coloquial propio (jerga)', style: TextStyle(fontSize: 11)), subtitle: const Text('Solo cuando encaje naturalmente.', style: TextStyle(fontSize: 9.5, color: Colors.white54)), value: slang, onChanged: (v) => setState(() => slang = v)),
              const SizedBox(height: 5),
              DropdownButtonFormField<String>(
                initialValue: usesName,
                decoration: _inputDeco('Uso del nombre de contacto'),
                isExpanded: true,
                dropdownColor: const Color(0xFF162036),
                style: const TextStyle(fontSize: 11, color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'natural', child: Text('Solo cuando sea natural', style: TextStyle(fontSize: 11))),
                  DropdownMenuItem(value: 'never', child: Text('Omitir nombre en saludos', style: TextStyle(fontSize: 11))),
                ],
                onChanged: (v) => setState(() => usesName = v!),
              ),
              const SizedBox(height: 6),
              TextField(controller: _custom, maxLength: 240, maxLines: 2, style: const TextStyle(fontSize: 11), decoration: _inputDeco('Instrucciones adicionales de estilo', hint: 'Breve, dinámico, sin frases de operador…')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(fontSize: 10.5))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
          onPressed: () => Navigator.pop(context, _StyleResult(register: register, relationship: relationship, learn: learn, enabled: enabled, slang: slang, usesName: usesName, custom: _custom.text.trim(), tone: tone)),
          child: const Text('Guardar', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
