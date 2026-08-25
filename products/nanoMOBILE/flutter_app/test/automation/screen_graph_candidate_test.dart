import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_action.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_provider.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/screen_graph_candidate_provider.dart';
import 'package:nanoai/features/automation/engine/perception/mux/perception_source.dart';
import 'package:nanoai/features/automation/engine/perception/nano_snapshot.dart';
import 'package:nanoai/features/automation/engine/system/system_capability.dart';

class _FakeObserver implements ScreenObserver {
  _FakeObserver(this.value);
  NanoSnapshot? value;

  @override
  Future<NanoSnapshot?> snapshot() async => value;
}

NanoNode node(
  int index, {
  int depth = 0,
  String type = '',
  String text = '',
  String desc = '',
  String id = '',
  bool clickable = false,
}) => NanoNode(
  index: index,
  depth: depth,
  id: id,
  type: type,
  text: text,
  description: desc,
  clickable: clickable,
  editable: false,
  scrollable: false,
  checked: false,
  focusable: false,
  focused: false,
  visible: true,
  enabled: true,
  bounds: const NanoBounds(left: 0, top: 0, right: 100, bottom: 100),
);

void main() {
  test('botón "Enviar" → tap candidate grounded (accessibility)', () async {
    final provider = ScreenGraphCandidateProvider(
      _FakeObserver(
        NanoSnapshot(
          package: 'com.t',
          nodes: [
            node(
              0,
              type: 'android.widget.Button',
              text: 'Enviar',
              clickable: true,
            ),
          ],
        ),
      ),
    );
    final candidates = await provider.provide(const CandidateRequest('enviar'));
    expect(candidates, hasLength(1));
    final c = candidates.single;
    expect(c.tool, 'tap');
    expect(c.args['selector'], 'text=Enviar');
    expect(c.channel, ActionChannel.accessibility);
    expect(
      c.requiredCapabilities,
      contains(SystemCapability.interactAccessibility),
    );
    expect(c.evidence.single.source, ActionEvidenceSource.accessibility);
  });

  test('concepto sin match → sin candidatos', () async {
    final provider = ScreenGraphCandidateProvider(
      _FakeObserver(
        NanoSnapshot(
          package: 'com.t',
          nodes: [
            node(
              0,
              type: 'android.widget.Button',
              text: 'Enviar',
              clickable: true,
            ),
          ],
        ),
      ),
    );
    expect(await provider.provide(const CandidateRequest('noexiste')), isEmpty);
  });

  test('snapshot null → sin candidatos (no crash)', () async {
    final provider = ScreenGraphCandidateProvider(_FakeObserver(null));
    expect(await provider.provide(const CandidateRequest('x')), isEmpty);
  });

  test('resourceId fallback cuando no hay text/desc', () async {
    final provider = ScreenGraphCandidateProvider(
      _FakeObserver(
        NanoSnapshot(
          package: 'com.t',
          nodes: [
            node(
              0,
              type: 'android.widget.ImageButton',
              desc: 'Cerrar',
              id: 'com.x:id/close',
              clickable: true,
            ),
          ],
        ),
      ),
    );
    final candidates = await provider.provide(const CandidateRequest('cerrar'));
    expect(candidates.single.args['selector'], 'desc=Cerrar');
  });
}
