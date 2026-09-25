part of 'personalization_studio_screen.dart';

extension _ExampleEditDialogFields on _ExampleEditDialogState {
  Widget _respItem(int i) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3.5),
      padding: const EdgeInsets.all(4.5),
      decoration: BoxDecoration(color: const Color(0x0EFFFFFF), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0x22FFFFFF), width: 0.6)),
      child: Column(
        children: [
          Row(
            children: [
              Text('#${i + 1}', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
              const Spacer(),
              InkWell(onTap: () => setState(() => _respActives[i] = !_respActives[i]), child: Text(_respActives[i] ? 'Activo ✓' : 'Inactivo', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: _respActives[i] ? const Color(0xFF00E676) : Colors.white38))),
              if (_respCtrls.length > 1) ...[
                const SizedBox(width: 4),
                InkWell(onTap: () => setState(() { _respCtrls.removeAt(i).dispose(); _respTones.removeAt(i); _respActives.removeAt(i); }), child: const Icon(Icons.delete_outline, size: 11, color: Colors.redAccent)),
              ],
            ],
          ),
          const SizedBox(height: 1.5),
          TextField(controller: _respCtrls[i], maxLines: 2, minLines: 1, style: const TextStyle(fontSize: 10), decoration: _dec('Respuesta posible #${i + 1}')),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.3, color: Colors.white70));

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 9, color: Colors.white24),
    filled: true,
    fillColor: const Color(0x0BFFFFFF),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0x22FFFFFF), width: 0.7)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0x22FFFFFF), width: 0.7)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0x8000E676), width: 0.7)),
  );
}
