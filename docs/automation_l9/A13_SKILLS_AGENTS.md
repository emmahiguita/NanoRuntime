# A13 — Skills + multiagentes lógicos

> Estado: IMPLEMENTADO (dominio) · NO WIRED (coordinator intacto) ·
> DEVICE-VERIFIED: N/A (puro Dart).

## Skills

`NanoSkill { id, canHandle(SkillContext), candidates(SkillContext) → List<CandidateAction> }`.
Un skill NO es texto ejecutable ni `runRawShell`: produce CandidateAction grounded
reusando la infraestructura A6. Ejecución sigue pasando por governance (A11) +
dispatcher + verifier.

Skills concretos: `OpenAppSkill` (launch_app grounded), `SystemNavigationSkill`
(open_system allowlisted), `ReadNotificationsSkill` (notifications read). Thin
wrappers sobre los providers A6 (sin duplicar lógica).

## Multiagentes lógicos

`AgentRole { planner, perception, executor, critic, verifier, memory }`. NO
ejecutan múltiples LLM: comparten el MISMO modelo/runtime. El valor es la
separación de responsabilidades, no seis modelos en RAM.

`AgentContext { goal, intent? }`, `AgentMessage { from, to, payload }`,
`AgentResult { role, value }`.

## NanoAgentOrchestrator

Orquesta roles lógicos sobre el pipeline Candidate-First (generator → selection
→ governance), SIN reemplazar AutomationCoordinator:

- planner/perception: generar candidatos grounded (0 LLM si determinista).
- executor: seleccionar (ranker; Koog solo si ambigüedad).
- critic: governance (firewall + critic + broker) sobre la intención.
- memory/verifier: aguas abajo (adapter → dispatcher → verifier).

No cableado al coordinator en A13 (test-wired; adaptador documentado).

## Seguridad

Skills y orchestrator no eluden governance (A11). Un skill produce candidatos;
el firewall/critic/broker deciden. Koog sigue siendo selector de ambigüedad, no
autoridad.

## Limitaciones

- Skills son thin wrappers (sin skills multi-step complejos todavía).
- Orquestador no cableado al coordinator (el coordinator sigue siendo la fachada).
- Sin ReplyNotificationSkill (notificación no tipada; diferido).

## A14 seam

MCP/Shizuku entrarán como adapters que producen CandidateAction → governance
(sin bypass). Koog subirá a coordinador de roles cuando los roles estén cableados.
