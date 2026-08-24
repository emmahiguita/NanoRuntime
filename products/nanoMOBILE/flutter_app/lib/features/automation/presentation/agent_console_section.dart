import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/widgets/nano_optical_surface.dart';
import 'package:nanoai/features/automation/engine/execution/agent_executor.dart';
import 'package:nanoai/core/services/nano_runtime_api_provider.dart';
import 'package:nanoai/features/automation/engine/agent_dependencies.dart';
import 'package:nanoai/features/automation/engine/perception/nano_selector.dart'
    show NanoSelector, SelectorFormatException;
import 'package:nanoai/core/theme/design_tokens.dart';
  import 'package:nanoai/core/theme/nano_type.dart';
    import 'package:nanoai/core/widgets/nano_section.dart';

/// Consola del agente de UI — consumidor real del Selector Engine.
///
/// Reemplaza la demo anterior (dump + tapOnText). Aquí:
/// - Snapshot con depth (canal `dumpSnapshot`).
/// - Resolver ponderado con top-5 y criterios (mini-DSL `NanoSelector.parse`).
/// - Tap seguro: actionability + estabilidad + tapAt(centro del bounds) —
///   nunca `tapOnText`.
/// - setText con foco verificado contra re-snapshot.
/// - Gestos puros de prueba (Back / Launch Ajustes / Swipe ↑).
class AgentConsoleSection extends ConsumerStatefulWidget {
  const AgentConsoleSection({super.key});

  @override
  ConsumerState<AgentConsoleSection> createState() =>
      _AgentConsoleSectionState();
}

class _AgentConsoleSectionState extends ConsumerState<AgentConsoleSection> {
  late final AgentExecutor _executor;
  final _selectorController = TextEditingController();
  final _setTextController = TextEditingController();

  String _status = 'Sin consultar';
  List<String> _nodes = const [];
  List<String> _candidates = const [];
  String _feedback = '';
  bool _busy = false;

  @override
void initState() {
  super.initState();
  _executor = ref.read(agentExecutorProvider);
  }

  @override
  void dispose() {
    _selectorController.dispose();
    _setTextController.dispose();
    super.dispose();
  }

  /// Parsea el mini-DSL del campo; null (con feedback) si inválido.
  NanoSelector? _parseSelector() {
    final expr = _selectorController.text.trim();
    if (expr.isEmpty) {
      setState(() => _feedback = 'Escribe un selector (ej. text=Bluetooth).');
      return null;
    }
    try {
      return NanoSelector.parse(expr);
    } on SelectorFormatException catch (e) {
      setState(() => _feedback = 'Selector inválido: ${e.message}');
      return null;
    }
  }

  Future<void> _probe() async {
    setState(() {
      _busy = true;
      _status = 'Consultando…';
    });
    final snap = await _executor.snapshot();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (snap == null) {
        _status = 'No conectado — activar en Ajustes → Accesibilidad → '
            'NanoAI Local';
        _nodes = const [];
        return;
      }
      if (snap.isEmpty) {
        _status = 'Conectado — sin ventana activa (rebind ColorOS)';
        _nodes = const [];
        return;
      }
      _status = 'Conectado — ${snap.package} · ${snap.nodes.length} nodos';
      _nodes = snap.visibleNodes
          .take(8)
          .map(
            (n) =>
                'd${n.depth} ${n.label} @(${n.bounds.left},${n.bounds.top})',
          )
          .toList();
    });
  }

  Future<void> _resolve() async {
    final selector = _parseSelector();
    if (selector == null) return;
    setState(() {
      _busy = true;
      _feedback = 'Resolviendo…';
    });
    final outcome = await _executor.resolve(selector);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _feedback = outcome.reason;
      _candidates = outcome.candidates
          .map(
            (e) =>
                '"${e.node.label}" — ${e.score} pts '
                '[${e.matchedCriteria.join(', ')}]',
          )
          .toList();
    });
  }

  Future<void> _tapSafe() async {
    final selector = _parseSelector();
    if (selector == null) return;
    setState(() {
      _busy = true;
      _feedback = 'Tap seguro…';
    });
    final r = await _executor.tap(selector);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _feedback = r.ok
          ? 'ok: tap en "${r.targetNode!.label}" '
              '@(${r.targetNode!.bounds.centerX},'
              '${r.targetNode!.bounds.centerY})'
          : 'FAIL [${r.errorCode!.name}]: ${r.reason}';
    });
  }

  Future<void> _setText() async {
    final selector = _parseSelector();
    if (selector == null) return;
    final text = _setTextController.text.trim();
    if (text.isEmpty) {
      setState(() => _feedback = 'Escribe el texto a introducir.');
      return;
    }
    setState(() {
      _busy = true;
      _feedback = 'Escribiendo…';
    });
    final r = await _executor.setText(selector, text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _feedback = r.ok
          ? 'ok: "$text" en "${r.targetNode!.label}"'
          : 'FAIL [${r.errorCode!.name}]: ${r.reason}';
    });
  }

  Future<void> _gesture(String kind) async {
    final runtime = ref.read(nanoRuntimeApiProvider);
    final ok = switch (kind) {
      'back' => await runtime.agentGlobalAction('back'),
      'launch' => await runtime.agentLaunchPackage('com.android.settings'),
      'swipe' => await runtime.agentSwipe(540, 2000, 540, 600),
      _ => false,
    };
    if (!mounted) return;
    setState(() => _feedback = '$kind → ${ok ? 'ok' : 'FAIL'}');
  }

  @override
  Widget build(BuildContext context) {
      final colors = NanoThemeExtension.of(context).colors;
      return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Percepción y acciones', Icons.smart_toy, colors: colors),
          NanoOpticalSurface(
            borderStrength: 0.45,
            reflectionStrength: 0.28,
            blurSigma: 12,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GroupLabel('Snapshot del árbol', colors),
              Text(
                _status,
                style: NanoType.body(colors.onSurface),
                softWrap: true,
              ),
              const SizedBox(height: NanoSpacing.md),
              // Acción de herramienta: botón compacto (content-sized) — nunca
              // se estira al ancho de la card ni de la pantalla.
              FilledButton.icon(
                onPressed: _busy ? null : _probe,
                icon: const Icon(Icons.visibility, size: 18),
                label: Text(
                  _busy ? 'Leyendo árbol…' : 'Leer pantalla actual',
                  style: NanoType.body(colors.onSurface),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accentCyan,
                  disabledBackgroundColor: colors.primary.withValues(
                    alpha: 0.4,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              if (_nodes.isNotEmpty) ...[
                const SizedBox(height: NanoSpacing.md),
                ..._nodes.map(
                  (n) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      n,
                      style: NanoType.caption(colors.onSurfaceVariant),
                      // Info descriptiva del debugger: 2 líneas (las
                      // coordenadas @(x,y) no deben perderse en un ellipsis).
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: NanoSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: NanoSpacing.md),
              _GroupLabel('Selector y toque', colors),
              TextField(
                controller: _selectorController,
                decoration: InputDecoration(
                  labelText: 'Selector (mini-DSL)',
                  helperText: 'ej. text=Bluetooth · editable=true · '
                      'editable=true;near=desc=Usuario',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: NanoSpacing.sm),
              Wrap(
                spacing: NanoSpacing.sm,
                runSpacing: NanoSpacing.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _resolve,
                    icon: const Icon(Icons.search, size: 16),
                    label: Text('Resolver', style: NanoType.caption(
                      colors.onSurface,
                    )),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _tapSafe,
                    icon: const Icon(Icons.touch_app, size: 16),
                    label: Text('Tap seguro', style: NanoType.caption(
                      colors.onSurface,
                    )),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accentCyan,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              if (_candidates.isNotEmpty) ...[
                const SizedBox(height: NanoSpacing.md),
                ..._candidates.map(
                  (c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      c,
                      style: NanoType.caption(colors.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: NanoSpacing.md),
              _GroupLabel('Insertar texto', colors),
              TextField(
                controller: _setTextController,
                decoration: InputDecoration(
                  labelText: 'Texto a escribir',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: NanoSpacing.sm),
              OutlinedButton.icon(
                onPressed: _busy ? null : _setText,
                icon: const Icon(Icons.keyboard, size: 16),
                label: Text('Escribir', style: NanoType.caption(
                  colors.onSurface,
                )),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(height: NanoSpacing.md),
              _GroupLabel('Gestos', colors),
              Wrap(
                spacing: NanoSpacing.sm,
                runSpacing: NanoSpacing.sm,
                children: [
                  _GestureButton(
                    label: 'Volver',
                    icon: Icons.arrow_back,
                    onPressed: _busy ? null : () => _gesture('back'),
                    colors: colors,
                  ),
                  _GestureButton(
                    label: 'Abrir Ajustes',
                    icon: Icons.launch,
                    onPressed: _busy ? null : () => _gesture('launch'),
                    colors: colors,
                  ),
                  _GestureButton(
                    label: 'Deslizar',
                    icon: Icons.swipe_up,
                    onPressed: _busy ? null : () => _gesture('swipe'),
                    colors: colors,
                  ),
                ],
              ),
              if (_feedback.isNotEmpty) ...[
                const SizedBox(height: NanoSpacing.md),
                Text(
                  _feedback,
                  style: NanoType.caption(
                    _feedback.startsWith('FAIL') ||
                            _feedback.startsWith('Selector inválido') ||
                            _feedback.startsWith('Escribe')
                        ? colors.error
                        : colors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Etiqueta overline de sub-grupo dentro de una sección Dev (ayuda a escanear).
class _GroupLabel extends StatelessWidget {
  final String text;
  final NanoColors colors;
  const _GroupLabel(this.text, this.colors);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NanoSpacing.xs),
      child: Text(
        text.toUpperCase(),
        style: NanoType.overline(colors.accentCyan),
      ),
    );
  }
}

/// Botón compacto de gesto puro (sin resolver).
class _GestureButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final NanoColors colors;

  const _GestureButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: NanoType.caption(colors.onSurface)),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
  }
}
