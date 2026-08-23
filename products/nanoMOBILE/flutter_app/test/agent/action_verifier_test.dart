/// Tests del ActionVerifier: postcondiciones tras la acción.
///
/// La fuente de snapshots es inyectable → secuencias deterministas sin
/// MethodChannel. Tiempos de expectativa reducidos para tests rápidos.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/action_verifier.dart';
import 'package:nanoai/features/automation/engine/nano_selector.dart';
import 'package:nanoai/features/automation/engine/nano_snapshot.dart';

import 'fixtures.dart';

void main() {
  NanoSnapshot snap(Map<String, dynamic> raw) =>
      NanoSnapshot.fromRaw(raw);

  ActionVerifier verifierWith(List<NanoSnapshot?> sequence) {
    var i = 0;
    return ActionVerifier(
      snapshotFn: () async =>
          i < sequence.length ? sequence[i++] : sequence.last,
    );
  }

  const fast = ActionExpectation(
    timeout: Duration(milliseconds: 50),
    pollInterval: Duration(milliseconds: 5),
  );

  test('sin criterios → verified trivial', () async {
    final v = verifierWith([snap(snapshotAjustes())]);
    final out = await v.verify(const ActionExpectation());
    expect(out.isVerified, isTrue);
  });

  test('mustAppear ya presente → verified', () async {
    final v = verifierWith([snap(snapshotAjustes())]);
    final out = await v.verify(
      fast.copyWith(mustAppear: NanoSelector.parse('text=Bluetooth')),
    );
    expect(out.status, VerificationStatus.verified);
  });

  test('mustAppear nunca aparece → timeout (no false success)', () async {
    final v = verifierWith([snap(snapshotAjustes())]);
    final out = await v.verify(
      fast.copyWith(mustAppear: NanoSelector.parse('text=WiFi')),
    );
    expect(out.status, VerificationStatus.timeout);
    expect(out.reason, contains('mustAppear'));
  });

  test('mustAppear aparece en el 2º sondeo → verified', () async {
    final v = verifierWith([
      snap(snapshotAjustes()),
      snap(snapshotAjustes()),
    ]);
    final out = await v.verify(
      fast.copyWith(mustAppear: NanoSelector.parse('text=Bluetooth')),
    );
    expect(out.status, VerificationStatus.verified);
  });

  test('mustDisappear sigue presente → timeout', () async {
    final v = verifierWith([snap(snapshotAjustes())]);
    final out = await v.verify(
      fast.copyWith(mustDisappear: NanoSelector.parse('text=Aceptar')),
    );
    expect(out.status, VerificationStatus.timeout);
    expect(out.reason, contains('sigue presente'));
  });

  test('forbiddenText visible → notVerified inmediato', () async {
    final v = verifierWith([snap(snapshotAjustes())]);
    final out = await v.verify(fast.copyWith(forbiddenText: 'Aceptar'));
    expect(out.status, VerificationStatus.notVerified);
    expect(out.reason, contains('prohibido'));
  });

  test('expectedText contains case-insensitive → verified', () async {
    final v = verifierWith([snap(snapshotAjustes())]);
    final out = await v.verify(fast.copyWith(expectedText: 'bluetooth'));
    expect(out.status, VerificationStatus.verified);
  });

  test('package distinto del esperado → wrongPackage', () async {
    final v = verifierWith([snap(snapshotAjustes())]);
    final out = await v.verify(
      fast.copyWith(expectedPackage: 'com.android.chrome'),
    );
    expect(out.status, VerificationStatus.wrongPackage);
  });

  test('package correcto → verified', () async {
    final v = verifierWith([snap(snapshotAjustes())]);
    final out = await v.verify(
      fast.copyWith(expectedPackage: 'com.android.settings'),
    );
    expect(out.status, VerificationStatus.verified);
  });

  test('canal muerto (null) → serviceUnavailable', () async {
    final v = verifierWith([null]);
    final out = await v.verify(
      fast.copyWith(mustAppear: NanoSelector.parse('text=Bluetooth')),
    );
    expect(out.status, VerificationStatus.serviceUnavailable);
  });

  test('snapshot vacío sostenido → timeout con motivo de rebind', () async {
    final v = verifierWith([snap(snapshotRebindEmpty())]);
    final out = await v.verify(
      fast.copyWith(mustAppear: NanoSelector.parse('text=Bluetooth')),
    );
    expect(out.status, VerificationStatus.timeout);
    expect(out.reason, contains('ventana activa'));
  });

  test('mustChangeSnapshot con cambio real → verified', () async {
    final pre = snap(snapshotAjustes());
    final post = snap(snapshotDobleAceptar());
    final v = verifierWith([post]);
    final out = await v.verify(
      fast.copyWith(mustChangeSnapshot: true),
      preSnapshot: pre,
    );
    expect(out.status, VerificationStatus.verified);
  });

  test('mustChangeSnapshot sin cambio → timeout', () async {
    final pre = snap(snapshotAjustes());
    final v = verifierWith([snap(snapshotAjustes())]);
    final out = await v.verify(
      fast.copyWith(mustChangeSnapshot: true),
      preSnapshot: pre,
    );
    expect(out.status, VerificationStatus.timeout);
    expect(out.reason, contains('no cambió'));
  });

  test('mustChangeSnapshot sin preSnapshot → notVerified (no asumir)', () async {
    final v = verifierWith([snap(snapshotAjustes())]);
    final out = await v.verify(fast.copyWith(mustChangeSnapshot: true));
    expect(out.status, VerificationStatus.notVerified);
    expect(out.reason, contains('preSnapshot'));
  });

  test('postcondiciones combinadas: pkg + mustAppear juntas → verified',
      () async {
    final v = verifierWith([snap(snapshotAjustes())]);
    final out = await v.verify(
      fast.copyWith(
        expectedPackage: 'com.android.settings',
        mustAppear: NanoSelector.parse('desc=Buscar ajustes'),
      ),
    );
    expect(out.status, VerificationStatus.verified);
  });
}
