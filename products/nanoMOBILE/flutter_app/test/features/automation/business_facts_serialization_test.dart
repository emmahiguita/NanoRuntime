import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/business/business_facts.dart';
import 'package:nanoai/features/automation/engine/business/business_facts_providers.dart';
import 'package:nanoai/features/automation/engine/business/business_presets.dart';
import 'package:nanoai/features/automation/engine/business/business_response_templates.dart';

/// Almacén de prueba con barreras controlables para reproducir la carrera real.
class _DelayedStore extends BusinessFactsStore {
  final loaded = Completer<BusinessFacts>();
  final firstWrite = Completer<void>();
  final releaseWrite = Completer<void>();
  var writes = 0;
  BusinessFacts? saved;

  @override
  Future<BusinessFacts> load() => loaded.future;

  @override
  Future<bool> save(BusinessFacts facts) async {
    writes++;
    if (writes == 1) {
      firstWrite.complete();
      await releaseWrite.future;
    }
    saved = facts;
    return true;
  }
}

void main() {
  test(
    'espera hidratación y combina dos cambios concurrentes sin perder datos',
    () async {
      final store = _DelayedStore();
      final notifier = BusinessFactsNotifier(store);
      addTearDown(notifier.dispose);
      final name = notifier.setBusinessName('Nombre nuevo');
      final phrases = notifier.setResponseTemplates(
        const BusinessResponseTemplates(
          phrases: {'greeting': 'Bienvenido a {negocio}'},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(store.writes, 0);
      // Perfil configurado impide una escritura adicional de migración en _load.
      store.loaded.complete(
        const BusinessFacts(
          hours: '9 a 17',
        ).copyWith(profile: customPreset.profile),
      );
      await store.firstWrite.future;
      expect(store.writes, 1);
      store.releaseWrite.complete();
      expect(await name, isTrue);
      expect(await phrases, isTrue);
      expect(store.saved!.businessName, 'Nombre nuevo');
      expect(store.saved!.hours, '9 a 17');
      expect(
        store.saved!.responseTemplates.phrases['greeting'],
        'Bienvenido a {negocio}',
      );
    },
  );
}
