import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/design_tokens.dart';

/// Noar Command Library â€” librerÃ­a de comandos organizada por tags.
///
/// Muestra el historial de comandos ejecutados en la terminal, organizados
/// por categorÃ­a (tag), con bÃºsqueda, copia al portapapeles, y una biblioteca
/// pre-cargada de comandos Ãºtiles con descripciones.
class NoarPanel extends StatefulWidget {
  final List<Map<String, dynamic>> library;
  final Color fg;
  final bool dark;

  const NoarPanel({
    super.key,
    required this.library,
    required this.fg,
    required this.dark,
  });

  @override
  State<NoarPanel> createState() => _NoarPanelState();
}

class _NoarPanelState extends State<NoarPanel> {
  String _search = '';
  String _activeTag = 'all';
  final _searchCtl = TextEditingController();

  static const _tags = {
    'all': 'Todo',
    'fs': 'FS',
    'shell': 'Shell',
    'rootfs': 'Rootfs',
    'pkgs': 'Pkgs',
    'kali': 'Kali',
    'containers': 'Docker',
    'monitor': 'Monitor',
    'remote': 'Remote',
    'ai': 'IA',
    'general': 'General',
  };

  // â”€â”€ Pre-built command library â”€â”€
  static const _builtin = [
    {
      'cmd': 'bootstrap',
      'desc': 'Instalar rootfs Termux (~30 MB). Requiere WiFi.',
      'tag': 'rootfs',
    },
    {
      'cmd': '!ls -la /usr/bin | head -20',
      'desc': 'Listar binarios reales del rootfs Termux (bash, apt, python...)',
      'tag': 'shell',
    },
    {
      'cmd': '!apt update && apt install python',
      'desc': 'Actualizar Ã­ndice de paquetes e instalar Python real en Termux.',
      'tag': 'pkgs',
    },
    {
      'cmd': '!pip install numpy torch',
      'desc': 'Instalar NumPy y PyTorch en el Python real del rootfs.',
      'tag': 'pkgs',
    },
    {
      'cmd': 'kali install',
      'desc': 'Descargar Kali Linux ARM64 (~200 MB). Requiere WiFi y proot.',
      'tag': 'kali',
    },
    {
      'cmd': 'kali shell',
      'desc': 'Abrir shell bash dentro de Kali Linux (vÃ­a proot).',
      'tag': 'kali',
    },
    {
      'cmd': 'kali run nmap -sV 192.168.1.1',
      'desc': 'Ejecutar nmap dentro de Kali (requiere Kali instalado).',
      'tag': 'kali',
    },
    {
      'cmd': 'docker pull alpine',
      'desc': 'Descargar imagen Alpine Linux ARM64 desde Docker Hub.',
      'tag': 'containers',
    },
    {
      'cmd': 'docker run alpine echo "hola desde contenedor"',
      'desc': 'Ejecutar un comando dentro de un contenedor Alpine (vÃ­a proot).',
      'tag': 'containers',
    },
    {
      'cmd': 'docker ps',
      'desc': 'Listar contenedores activos.',
      'tag': 'containers',
    },
    {
      'cmd': '!ps aux',
      'desc': 'Listar todos los procesos del sistema (vÃ­a toybox real).',
      'tag': 'monitor',
    },
    {
      'cmd': 'free',
      'desc': 'Mostrar memoria RAM disponible (datos reales de /proc/meminfo).',
      'tag': 'monitor',
    },
    {
      'cmd': 'df',
      'desc': 'Mostrar espacio en disco (datos reales de StatFs).',
      'tag': 'monitor',
    },
    {
      'cmd': 'uname -a',
      'desc': 'Info del kernel Android y arquitectura (aarch64).',
      'tag': 'monitor',
    },
    {
      'cmd': 'status',
      'desc': 'DiagnÃ³stico completo: shell, rootfs, proot, kali, docker, device.',
      'tag': 'general',
    },
    {
      'cmd': '!git clone https://github.com/user/repo',
      'desc': 'Clonar repositorio Git (requiere git instalado en Termux).',
      'tag': 'remote',
    },
    {
      'cmd': '!curl -L https://example.com',
      'desc': 'Descargar contenido web (requiere curl instalado en Termux).',
      'tag': 'remote',
    },
    {
      'cmd': 'ai Â¿cÃ³mo optimizar el uso de RAM en Android?',
      'desc': 'Consultar al motor LLM local sobre optimizaciÃ³n de memoria.',
      'tag': 'ai',
    },
    {
      'cmd': 'infer "explÃ­came quÃ© es proot y cÃ³mo funciona"',
      'desc': 'Inferencia directa en el motor LLM (llama.cpp en localhost:8080).',
      'tag': 'ai',
    },
    {
      'cmd': '!find /usr -name "*.so" | head -10',
      'desc': 'Buscar librerÃ­as .so en el rootfs Termux.',
      'tag': 'shell',
    },
    {
      'cmd': '!tar -czf backup.tar.gz /usr/share',
      'desc': 'Crear backup comprimido del rootfs.',
      'tag': 'shell',
    },
    {
      'cmd': '!python3 -c "import torch; print(torch.cuda.is_available())"',
      'desc': 'Verificar si PyTorch detecta GPU (requiere torch instalado).',
      'tag': 'ai',
    },
    {
      'cmd': '!nmap -sP 192.168.0.0/24',
      'desc': 'Escanear red local con nmap (dentro de Kali).',
      'tag': 'kali',
    },
    {
      'cmd': 'ls -la /models',
      'desc': 'Ver modelos GGUF descargados en el filesystem virtual.',
      'tag': 'fs',
    },
    {
      'cmd': 'cat /models/config.json',
      'desc': 'Ver configuraciÃ³n del motor LLM (temperature, context...).',
      'tag': 'fs',
    },
  ];

  List<Map<String, dynamic>> get _filtered {
    final all = [
      ..._builtin,
      ...widget.library,
    ];
    return all.where((c) {
      final tag = c['tag'] as String? ?? 'general';
      if (_activeTag != 'all' && tag != _activeTag) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final cmd = (c['cmd'] as String? ?? '').toLowerCase();
        final desc = (c['desc'] as String? ?? '').toLowerCase();
        if (!cmd.contains(q) && !desc.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copiado: $text', style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12)),
        duration: const Duration(seconds: 1),
        backgroundColor: widget.fg.withValues(alpha: 0.15),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = widget.dark ? const Color(0xFF0A0F1A) : const Color(0xFFE0E0EC);
    final items = _filtered;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: chrome,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: widget.fg.withValues(alpha: 0.15))),
      ),
      child: Column(
        children: [
          // â”€â”€ Handle bar â”€â”€
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: widget.fg.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // â”€â”€ Header â”€â”€
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, color: widget.fg, size: 22),
                const SizedBox(width: 8),
                Text('Noar Library',
                  style: TextStyle(fontFamily: 'JetBrainsMono', 
                    fontSize: 15, fontWeight: FontWeight.w700, color: widget.fg,
                  ),
                ),
                const Spacer(),
                Text('${items.length} comandos',
                  style: TextStyle(fontFamily: 'JetBrainsMono', 
                    fontSize: 11, color: widget.fg.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),

          // â”€â”€ Search â”€â”€
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchCtl,
              onChanged: (v) => setState(() => _search = v),
              style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13, color: widget.fg),
              cursorColor: widget.fg,
              decoration: InputDecoration(
                hintText: 'buscar comando o descripciÃ³n...',
                hintStyle: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12, color: widget.fg.withValues(alpha: 0.25)),
                prefixIcon: Icon(Icons.search, color: widget.fg.withValues(alpha: 0.35), size: 18),
                filled: true,
                fillColor: widget.fg.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: widget.fg.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: widget.fg.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: widget.fg.withValues(alpha: 0.3)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
          ),

          // â”€â”€ Tags â”€â”€
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: _tags.entries.map((e) {
                final active = _activeTag == e.key;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTag = e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? widget.fg.withValues(alpha: 0.12) : widget.fg.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: widget.fg.withValues(alpha: active ? 0.25 : 0.06)),
                      ),
                      child: Text(e.value,
                        style: TextStyle(fontFamily: 'JetBrainsMono', 
                          fontSize: 11, color: active ? widget.fg : widget.fg.withValues(alpha: 0.5),
                          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 4),

          // â”€â”€ Command list â”€â”€
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text('sin resultados',
                      style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12, color: widget.fg.withValues(alpha: 0.3)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final c = items[i];
                      final cmd = c['cmd'] as String? ?? '';
                      final desc = c['desc'] as String? ?? '';
                      final tag = c['tag'] as String? ?? 'general';
                      final tagLabel = _tags[tag] ?? tag;
                      final isHistory = c.containsKey('ts');
                      return Card(
                        color: widget.fg.withValues(alpha: 0.03),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: widget.fg.withValues(alpha: 0.06)),
                        ),
                        margin: const EdgeInsets.only(bottom: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Tag + copy button row
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: widget.fg.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(tagLabel,
                                      style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 9, color: widget.fg.withValues(alpha: 0.5)),
                                    ),
                                  ),
                                  if (isHistory) ...[
                                    const SizedBox(width: 6),
                                    Icon(Icons.history, size: 11, color: widget.fg.withValues(alpha: 0.25)),
                                  ],
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => _copy(cmd),
                                    child: Icon(Icons.copy, size: 16, color: widget.fg.withValues(alpha: 0.4)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Command
                              GestureDetector(
                                onTap: () => _copy(cmd),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: widget.dark ? const Color(0xFF111827) : const Color(0xFFF0F0F5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(cmd,
                                    style: TextStyle(fontFamily: 'JetBrainsMono', 
                                      fontSize: 12.5, color: widget.fg, height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(desc,
                                  style: TextStyle(fontFamily: 'JetBrainsMono', 
                                    fontSize: 11, color: widget.fg.withValues(alpha: 0.5), height: 1.3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
