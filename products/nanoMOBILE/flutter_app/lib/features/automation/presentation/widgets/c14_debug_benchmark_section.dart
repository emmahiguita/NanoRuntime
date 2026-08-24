import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/interactive_glass_card.dart';
import 'package:nanoai/core/widgets/nano_section.dart';

import '../../benchmark/c14_runner.dart';
import '../../benchmark/c14_metrics.dart';

/// Sección DEBUG (solo kDebugMode) del benchmark físico C14-A.
///
/// Usa el MISMO [runC14Benchmark] que el integration_test — una sola fuente de
/// verdad. Preflight primero (si falta modelo → aborta con código, no corre 10
/// tareas rojas). Reporte de gates + export JSON reproducible (contexto
/// commit/modelo).
class C14DebugBenchmarkSection extends ConsumerStatefulWidget {
  const C14DebugBenchmarkSection({super.key});

  @override
  ConsumerState<C14DebugBenchmarkSection> createState() =>
      _C14DebugBenchmarkSectionState();
}

class _C14DebugBenchmarkSectionState
    extends ConsumerState<C14DebugBenchmarkSection> {
  C14RunResult? _result;
  int _progressIndex = 0;
  String _currentGoal = '';
  C14Execution? _lastExecution;
  bool _running = false;

  dynamic get _colors => NanoThemeExtension.of(context).colors;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _result = null;
      _progressIndex = 0;
      _currentGoal = '';
      _lastExecution = null;
    });
    final container = ProviderScope.containerOf(context);
    try {
      final result = await runC14Benchmark(
        container,
        onStart: (i, g) {
          if (!mounted) return;
          setState(() {
            _progressIndex = i;
            _currentGoal = g;
          });
        },
        onExecution: (e) {
          if (!mounted) return;
          setState(() => _lastExecution = e);
        },
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('C14 infra error: $e')),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copiado al portapapeles')),
    );
  }

  String _reportText() {
    final r = _result!;
    final b = StringBuffer()
      ..writeln('C14-A REPORT')
      ..writeln('device=${r.context.device} model=${r.context.model} '
          'commit=${r.context.gitCommit}')
      ..writeln();
    for (final g in r.report!.gates) {
      b.writeln('${g.name.padRight(24)} ${(g.value * 100).toStringAsFixed(0)}%'
          '  ${g.pass ? 'PASS' : 'FAIL'}');
    }
    b
      ..writeln()
      ..writeln('Goal success  ${r.report!.passed}/${r.report!.total}')
      ..writeln('Total  ${r.total.inMilliseconds}ms');
    return b.toString();
  }

  void _exportJson() {
    final json = const JsonEncoder.withIndent('  ').convert(_result!.toJson());
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('C14-A JSON'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(json, style: const TextStyle(fontSize: 12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _copy(json),
            child: const Text('Copiar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Diagnostics', Icons.bug_report_rounded, colors: _colors),
        InteractiveGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(NanoSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('C14 Automation Benchmark',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: NanoSpacing.sm),
                _preflightStatus(),
                const SizedBox(height: NanoSpacing.md),
                FilledButton.icon(
                  onPressed: _running ? null : _run,
                  icon: _running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(_running ? 'Ejecutando…' : 'RUN C14-A'),
                ),
                if (_running) _progress(),
                if (_result != null) ...[
                  const SizedBox(height: NanoSpacing.md),
                  _report(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _preflightStatus() {
    final preflight = _result?.preflight;
    if (preflight == null) {
      return Text(
        'Preflight se evalúa al pulsar RUN (modelo, runtime, accesibilidad).',
        style: NanoType.label(_colors.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final c in preflight.checks)
          Chip(
            label: Text('${c.name}: ${c.ok ? 'OK' : 'FAIL'}',
                style: const TextStyle(fontSize: 11)),
            backgroundColor: (c.ok ? _colors.success : _colors.error)
                .withValues(alpha: 0.15),
            side: BorderSide.none,
          ),
      ],
    );
  }

  Widget _progress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: NanoSpacing.sm),
        Text('Progress  ${_progressIndex + 1} / 10'),
        if (_currentGoal.isNotEmpty)
          Text('"$_currentGoal"', style: const TextStyle(fontSize: 12)),
        if (_lastExecution != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Planner ${_lastExecution!.planValid ? 'PASS' : 'FAIL'} · '
              'Execution ${_lastExecution!.goalSuccess ? 'PASS' : 'FAIL'} · '
              'Cache ${_lastExecution!.cacheHit ? 'HIT' : 'MISS'} · '
              '${_lastExecution!.totalLatency.inMilliseconds}ms',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _report() {
    final r = _result!;
    final rep = r.report!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Text('C14-A REPORT',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        for (final g in rep.gates)
          Text('${g.name}: ${(g.value * 100).toStringAsFixed(0)}% '
              '${g.pass ? 'PASS' : 'FAIL'}'),
        const SizedBox(height: NanoSpacing.sm),
        Text('Goal success  ${rep.passed}/${rep.total}'),
        Text('Total  ${r.total.inMilliseconds}ms'),
        const SizedBox(height: NanoSpacing.sm),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _copy(_reportText()),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copiar reporte'),
            ),
            const SizedBox(width: NanoSpacing.xs),
            OutlinedButton.icon(
              onPressed: _exportJson,
              icon: const Icon(Icons.ios_share_rounded, size: 16),
              label: const Text('Exportar JSON'),
            ),
          ],
        ),
      ],
    );
  }
}
