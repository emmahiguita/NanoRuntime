part of 'terminal_core.dart';

/// Componente tuning: mantiene las operaciones existentes y el dueño de sesión.
mixin _TerminalTuning on _TerminalStateBase {
  @override
  void _registerTuning() {
    _cmds['tune'] = (a, c, o, af) async {
      o('══ NanoAI Auto-Tune ══', Ln.header);
      final mem = ProcFs.meminfo();
      final totalMb = (mem['MemTotal'] ?? 0) ~/ 1024;
      final availMb = (mem['MemAvailable'] ?? mem['MemFree'] ?? 0) ~/ 1024;
      final cores = _devId?['cpuCores'] as int? ?? Platform.numberOfProcessors;
      final tempC = await _readCpuTemp();
      o(
        'Device: ${totalMb}MB RAM, ${availMb}MB libre, $cores cores'
        '${tempC != null ? ', ${tempC.toStringAsFixed(1)}Â°C' : ''}',
        Ln.info,
      );
      final engine = _engine;
      if (engine == null) {
        o('Motor LLM: no configurado (sin engine client)', Ln.warn);
        o('Sugerencias: instala llama.cpp en 127.0.0.1:8080', Ln.info);
        return;
      }
      o('Motor URL: ${engine.baseUrl}', Ln.info);
      final online = await engine.isOnline();
      if (!online) {
        o('Motor: OFFLINE (no responde en ${engine.baseUrl})', Ln.warn);
        o('Sugerencia: lanza llama.cpp con --server --port 8080', Ln.info);
        return;
      }
      o('Motor: ONLINE', Ln.success);
      o('Benchmark TPS... (prompt de prueba)', Ln.info);
      try {
        final res = await engine.generate(
          prompt: 'Hello',
          maxTokens: 10,
          temperature: 0.0,
        );
        o(
          'Respuesta: "${res.text.length > 40 ? '${res.text.substring(0, 40)}...' : res.text}"',
          Ln.stdout,
        );
        if (res.tps != null) {
          o('Velocidad: ${res.tps!.toStringAsFixed(1)} tok/s', Ln.success);
          if (res.tps! < 5) {
            o('âš  TPS bajo. Considera:', Ln.warn);
            o(
              '  - Usar un modelo más pequeño (Qwen 0.5B en vez de 1.5B)',
              Ln.info,
            );
            o('  - Reducir context window (--ctx-size 512)', Ln.info);
            o('  - Deshabilitar GPU layers si tenés poca RAM', Ln.info);
          } else if (res.tps! < 20) {
            o('TPS aceptable. Optimizaciones:', Ln.info);
            o('  - Subir --threads a $cores para mejor rendimiento', Ln.info);
            o('  - Aumentar --batch-size a 512 si tenés RAM', Ln.info);
          } else {
            o('TPS excelente. Sugerencias:', Ln.info);
            o('  - Podés usar modelos más grandes (Qwen 3B, 7B)', Ln.info);
            o('  - Aumentar --ctx-size a 4096 para prompts largos', Ln.info);
          }
        }
        if (availMb < 500) {
          o(
            'âš  RAM baja (${availMb}MB libre). Riesgo de OOM con modelos grandes.',
            Ln.warn,
          );
        } else if (availMb > 2000) {
          o(
            'RAM suficiente para modelos de hasta ~2B parámetros (Qwen-1.5B, Gemma-2B).',
            Ln.info,
          );
        } else {
          o('RAM adecuada para modelos de ~1B parámetros.', Ln.info);
        }
      } on LLMEngineException catch (e) {
        o('Benchmark falló: ${e.message}', Ln.stderr);
      }
    };
  }
}
