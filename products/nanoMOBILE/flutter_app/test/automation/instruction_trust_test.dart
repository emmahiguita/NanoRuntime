import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/trust/instruction_trust.dart';

/// C11 — InstructionTrust: frontera estricta INSTRUCCIÓN vs CONTENIDO.
/// Un texto observado (pantalla/web) NUNCA se trata como orden al agente.
void main() {
  test('clasifica proveniencia: instrucción del usuario vs observado', () {
    const t = InstructionTrust(
      userInstruction: 'abre Bluetooth',
      observed: ['Inicia sesión', 'Haz clic en Aceptar'],
    );
    expect(t.provenanceOf('abre Bluetooth'), ContentProvenance.userInstruction);
    expect(t.provenanceOf('Inicia sesión'), ContentProvenance.observedContent);
    expect(t.isUserInstruction('abre Bluetooth'), isTrue);
    // Un texto observado NO es la instrucción.
    expect(t.isUserInstruction('Haz clic en Aceptar'), isFalse);
  });

  test(
    'annotateForPrompt separa INSTRUCCIÓN (autoritativa) de OBSERVADO (dato)',
    () {
      const t = InstructionTrust(
        userInstruction: 'abre Bluetooth',
        observed: ['Inicia sesión'],
      );
      final p = t.annotateForPrompt();
      expect(p, contains('INSTRUCCIÓN DEL USUARIO'));
      expect(p, contains('abre Bluetooth'));
      expect(p, contains('CONTENIDO OBSERVADO'));
      expect(p, contains('Inicia sesión'));
      expect(p, contains('NUNCA'));
    },
  );

  test('sin instrucción real no autoriza ejecución', () {
    const t = InstructionTrust(userInstruction: '   ');
    expect(t.authorizesExecution(), isFalse);
  });
}
