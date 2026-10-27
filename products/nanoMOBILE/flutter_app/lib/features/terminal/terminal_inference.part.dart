part of 'terminal_core.dart';

/// Componente inference: mantiene las operaciones existentes y el dueño de sesión.
mixin _TerminalInference on _TerminalStateBase {
  @override
  void _registerInference() {
    _cmds['infer'] = (a, c, o, af) {
      if (a.isEmpty) {
        o('infer: prompt requerido', Ln.stderr);
        return;
      }
      final prompt = a.join(' ');
      final engine = _engine;
      if (engine == null) {
        o('infer: motor LLM no disponible', Ln.stderr);
        return;
      }
      o('[NanoRuntime] Enviando a ${engine.baseUrl}...', Ln.system);
      final start = DateTime.now();
      engine
          .generate(prompt: prompt, maxTokens: 128)
          .then((res) {
            if (!_alive || !mounted) return;
            final ms = DateTime.now().difference(start).inMilliseconds;
            for (final line in res.text.split('\n')) {
              if (line.isNotEmpty) o(line, Ln.success);
            }
            o('${ms}ms @ ${res.tps?.toStringAsFixed(1) ?? "?"} tok/s', Ln.info);
          })
          .catchError((e) {
            if (!_alive || !mounted) return;
            o('infer: el motor no respondió — $e', Ln.stderr);
          });
    };
    _cmds['ai'] = (a, c, o, af) {
      if (a.isEmpty) {
        o('ai: escribe un prompt. Ej: ai ¿cómo optimizar RAM?', Ln.stderr);
        return;
      }
      final prompt = a.join(' ');
      final engine = _engine;
      if (engine == null) {
        o('ai: motor LLM no disponible', Ln.stderr);
        return;
      }
      o('[NanoAI] Pensando... (${engine.baseUrl})', Ln.info);
      engine
          .generate(prompt: prompt, maxTokens: 512)
          .then((res) {
            if (!_alive || !mounted) return;
            for (final line in res.text.split('\n')) {
              if (line.isNotEmpty) o(line, Ln.stdout);
            }
            if (res.tps != null) {
              o('${res.tps!.toStringAsFixed(1)} tok/s', Ln.info);
            }
          })
          .catchError((e) {
            if (!_alive || !mounted) return;
            o(
              'ai: el motor no respondió. ¿Está corriendo llama.cpp en 127.0.0.1:8080?',
              Ln.stderr,
            );
            o('  $e', Ln.stderr);
          });
    };
  }
}
