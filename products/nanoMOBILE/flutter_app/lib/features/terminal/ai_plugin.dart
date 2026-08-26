import 'terminal_types.dart';
import 'terminal_plugin.dart';

/// AI/LLM commands (ai, infer, tune) — extracted from _TermState for OCP.
///
/// These commands depend on LLMEngineClient which is injected lazily.
/// Registration is idempotent: calling registerInto twice overwrites
/// the previous registrations (last-write-wins).
class AiPlugin extends TerminalPlugin {
  // No const: TerminalPlugin's implicit constructor is non-const, and a
  // const constructor can't call it (error visto en build 2026-08-08).
  AiPlugin();

  @override
  void registerInto(
    CmdRegistrar reg,
    TerminalCtx ctx,
    void Function(String, Ln) out,
    Object? Function() getEngine,
  ) {
    reg('infer', (a, c, o, af) {
      if (a.isEmpty) {
        o(
          'infer: prompt requerido. Ej: infer "responde en español"',
          Ln.stderr,
        );
        return;
      }
      final engine = getEngine();
      if (engine == null) {
        o('infer: motor LLM no disponible', Ln.stderr);
        return;
      }
      // Dynamic dispatch — engine.generate is checked at runtime.
      try {
        final prompt = a.join(' ');
        o('[NanoRuntime] Enviando...', Ln.system);
        (engine as dynamic)
            .generate(prompt: prompt, maxTokens: 128)
            .then((res) {
              for (final line in (res.text as String).split('\n')) {
                if (line.isNotEmpty) o(line, Ln.success);
              }
            })
            .catchError((e) {
              o('infer: el motor no respondió — $e', Ln.stderr);
            });
      } catch (e) {
        o('infer: engine type mismatch — $e', Ln.stderr);
      }
    });

    reg('ai', (a, c, o, af) {
      if (a.isEmpty) {
        o('ai: escribe un prompt. Ej: ai ¿cómo optimizar RAM?', Ln.stderr);
        return;
      }
      final engine = getEngine();
      if (engine == null) {
        o('ai: motor LLM no disponible', Ln.stderr);
        return;
      }
      try {
        final prompt = a.join(' ');
        o('[NanoAI] Pensando...', Ln.info);
        (engine as dynamic)
            .generate(prompt: prompt, maxTokens: 512)
            .then((res) {
              for (final line in (res.text as String).split('\n')) {
                if (line.isNotEmpty) o(line, Ln.stdout);
              }
            })
            .catchError((e) {
              o(
                'ai: el motor no respondió. ¿Está corriendo llama.cpp?',
                Ln.stderr,
              );
              o('  $e', Ln.stderr);
            });
      } catch (e) {
        o('ai: engine error — $e', Ln.stderr);
      }
    });
  }
}
