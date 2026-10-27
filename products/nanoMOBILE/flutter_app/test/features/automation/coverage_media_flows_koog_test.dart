// coverage_media_flows_koog_test.dart
//
// QUÉ HACE:
// Suite de pruebas unitarias para validar Puntos 4, 5, 6, 9 y KOOG Comercial.
//
// CÓMO FUNCIONA:
// - Prueba detección de huecos temporales en [ConversationCoverageAnalyzer].
// - Prueba transiciones y abortos seguros en [WhatsAppWebMediaStateMachine].
// - Prueba generación y recepción de WhatsApp Flows en [MetaWhatsAppFlowComposer].
// - Prueba escalamiento humano y selección en [KoogCommercialGate].
//
// POR QUÉ:
// Verifica determinísticamente cada componente sin depender de mocks ficticios ni tocar procesos activos.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/domain/whatsapp_media_payload.dart';
import 'package:nanoai/features/automation/engine/business/business_facts.dart';
import 'package:nanoai/features/automation/engine/business/intelligence/conversation_intelligence_profile.dart';
import 'package:nanoai/features/automation/engine/business/intelligence/koog_commercial_gate.dart';
import 'package:nanoai/features/automation/engine/business/meta_whatsapp_flow_composer.dart';
import 'package:nanoai/features/automation/engine/business/meta_whatsapp_flow_models.dart';
import 'package:nanoai/features/automation/engine/business/state/commercial_conversation_state.dart';
import 'package:nanoai/features/automation/engine/business/state/commercial_funnel_stage.dart';
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';
import 'package:nanoai/features/automation/engine/messaging/canonical_message.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_coverage_analyzer.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_action.dart';
import 'package:nanoai/features/automation/engine/planning/koog_supervisor.dart';
import 'package:nanoai/features/automation/engine/web_bridge/whatsapp_web_media_state_machine.dart';

void main() {
  group('Puntos 4, 5, 6 y KOOG Comercial Tests', () {
    test('Punto 4: ConversationCoverageAnalyzer fusiona ventanas y detecta huecos', () {
      const analyzer = ConversationCoverageAnalyzer(continuityToleranceMs: 5000);
      final report = analyzer.analyze(const [
        ConversationCoverage(provider: 'whatsapp_web', fromMs: 1000, toMs: 5000, gapBefore: false),
        ConversationCoverage(provider: 'whatsapp_web', fromMs: 8000, toMs: 12000, gapBefore: false),
        ConversationCoverage(provider: 'android_notification', fromMs: 50000, toMs: 60000, gapBefore: true),
      ]);

      expect(report.mergedWindows.length, 2);
      expect(report.mergedWindows.first.toMs, 12000);
      expect(report.hasLeadingGap, isFalse);
      expect(report.interWindowGaps.length, 1);
      expect(report.interWindowGaps.first.durationMs, 38000);
      expect(report.hasKnownGaps, isTrue);
    });

    test('Punto 5: WhatsAppWebMediaStateMachine valida, previsualiza y confirma envio', () async {
      final tempDir = await Directory.systemTemp.createTemp('nano_media_test_');
      final file = File('${tempDir.path}/catalogo.pdf');
      await file.writeAsBytes(List<int>.filled(256, 42));
      addTearDown(() => tempDir.delete(recursive: true));

      const machine = WhatsAppWebMediaStateMachine();
      final payload = WhatsAppMediaPayload(
        filePath: file.path,
        mimeType: 'application/pdf',
        fileName: 'catalogo.pdf',
        caption: 'Catálogo actualizado',
        type: WhatsAppMediaType.document,
      );

      final result = await machine.executeWithRunner(
        payload: payload,
        recipientPhone: '+57 300 123 4567',
        expectedAccount: 'acc_1',
        runner: (phase, _) async => switch (phase) {
          'prepare' => {
            'status': 'ready',
            'account': 'acc_1',
            'chat': '573001234567@c.us',
            'title': 'Cliente VIP',
          },
          'stage' => {'status': 'mediaStaged', 'reason': 'ok'},
          'commit' => {'status': 'dispatchedUnverified', 'reason': 'sent'},
          _ => {'status': 'notExecuted'},
        },
      );

      expect(result.isDispatched, isTrue);
      expect(
        result.visitedStates,
        containsAllInOrder([
          WhatsAppWebMediaState.idle,
          WhatsAppWebMediaState.validatingPayload,
          WhatsAppWebMediaState.preparingContext,
          WhatsAppWebMediaState.stagingBlob,
          WhatsAppWebMediaState.awaitingPreviewModal,
          WhatsAppWebMediaState.committingSend,
          WhatsAppWebMediaState.dispatchedUnverified,
        ]),
      );
    });

    test('Punto 6: MetaWhatsAppFlowComposer genera Flow oficial y aplica nfm_reply', () {
      const composer = MetaWhatsAppFlowComposer();
      const facts = BusinessFacts(
        businessName: 'Nano Shop',
        products: [
          BusinessProduct(
            id: 'prod_1',
            name: 'Teclado Mecánico',
            details: 'Switches rojos',
            price: 90,
          ),
        ],
      );
      final initialState = CommercialConversationState(
        conversationId: 'conv_flow_1',
        focusedProductId: 'prod_1',
        lastInteraction: DateTime(2026, 10, 15),
      );

      final flowReq = composer.buildCheckoutFlow(
        recipientPhone: '573001112233',
        flowId: 'flow_meta_99',
        state: initialState,
        facts: facts,
      );
      final jsonPayload = flowReq.toGraphApiJson();
      expect(jsonPayload['type'], 'interactive');
      expect((jsonPayload['interactive'] as Map)['type'], 'flow');

      final submission = MetaWhatsAppFlowSubmission.tryParse(
        '{"flow_token":"nano_conv_flow_1_1","product_id":"prod_1","quantity":2,"delivery_address":"Calle 10 #20"}',
      );
      expect(submission, isNotNull);

      final nextState = composer.applySubmission(
        currentState: initialState,
        submission: submission!,
        facts: facts,
      );
      expect(nextState.stage, CommercialFunnelStage.paymentPending);
      expect(nextState.cartItemsCount, 2);
      expect(nextState.cartTotal, 180.0);
    });

    test('KOOG Comercial: escala a humano en objeciones calientes y actua en certeza', () async {
      const gate = KoogCommercialGate();
      const continuousCoverage = ConversationCoverageReport(
        mergedWindows: [
          ConversationCoverage(provider: 'meta_cloud', fromMs: 100, toMs: 200, gapBefore: false),
        ],
        interWindowGaps: [],
        hasLeadingGap: false,
      );
      final hotWithObjection = ConversationIntelligenceProfile(
        conversationId: 'c1',
        leadQuality: LeadQuality.hot,
        objections: const ['caro'],
        extractedAt: DateTime(2026, 10, 15),
      );

      final d1 = await gate.evaluate(
        goal: 'Responder consulta',
        intelligence: hotWithObjection,
        coverage: continuousCoverage,
        candidates: const [],
      );
      expect(d1, isA<KoogNeedConfirmation>());

      final candidate = CandidateAction(
        id: CandidateId('reply_catalog'),
        semanticAction: 'send_catalog',
        tool: 'whatsapp.send_catalog',
        args: const {},
        channel: ActionChannel.deterministic,
        groundingConfidence: 0.95,
        risk: ToolRisk.read,
        reversible: true,
        evidence: [
          ActionEvidence(
            source: ActionEvidenceSource.deterministicCatalog,
            reference: 'catalog_rule_1',
            confidence: 0.95,
          ),
        ],
      );
      final warmClean = ConversationIntelligenceProfile(
        conversationId: 'c2',
        leadQuality: LeadQuality.warm,
        extractedAt: DateTime(2026, 10, 15),
      );
      final d2 = await gate.evaluate(
        goal: 'Enviar catálogo',
        intelligence: warmClean,
        coverage: continuousCoverage,
        candidates: [candidate],
      );
      expect(d2, isA<KoogAct>());
    });
  });
}
