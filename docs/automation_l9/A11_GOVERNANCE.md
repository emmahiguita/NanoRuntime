# A11 — Governance (IntentFirewall + PreActionCritic + PrivilegeBroker)

> Estado: IMPLEMENTADO (dominio) · NO WIRED (planner productivo intacto) ·
> DEVICE-VERIFIED: N/A (puro Dart, determinista).

## Capability vs Authority vs Privilege vs Policy vs Verification

- **CAPABILITY**: Nano técnicamente puede (SystemGraph).
- **AUTHORITY**: la instrucción del usuario permite el efecto (IntentSpec).
- **PRIVILEGE**: el backend requiere un permiso/tier (PrivilegeBroker).
- **POLICY**: producto/usuario permite automático o requiere aprobación (PolicyEngine).
- **VERIFICATION**: el efecto realmente ocurrió (ActionVerifier/GoalVerifier).

Separados explícitamente.

## IntentSpec / modelo de efectos

`IntentSpec { id, allowedEffects, targetScope? }`. `ActionEffect` acotado
(navigate/read/writeUi/changeSystemState/sendExternalMessage/publishExternalContent/
modifyFile/deleteFile/executeProcess/installPackage/manageApplication/
changePermission/privilegedSystemOperation). `targetScope` delimita el target
(ej. `juan`), nunca wildcard.

## IntentSpecCompiler

Determinista, limitado: goals conocidos → scope preciso; desconocido →
conservador (solo `read`). No resuelve toda la NL. Nunca otorga wildcard.

## IntentFirewall

`check(intent, candidate) → allowed/denied/clarification`. Mapeo determinista
`effectOfTool(tool)` (fuente de verdad central). Efecto fuera del scope → deny;
target mismatch → deny.

## PreActionCritic

Rules-first (sin LLM): capability disponible → grounding ≥ 0.6 → efecto externo
irreversible → confirmation; efecto externo → confirmation; else approve.
Un DENY determinista no puede convertirse en ALLOW por el modelo.

## PrivilegeBroker

Tiers: publicAndroid / notificationAccess / accessibility / mediaProjection /
nanoLinux / developerAdb / shizuku / deviceOwner / rootLab. Menor privilegio
capaz (least privilege). Sin SystemGraph evidence → solo publicAndroid disponible.
shizuku/root → no disponibles en A11.

## Pipeline

```
CandidateAction → IntentFirewall → PreActionCritic → PrivilegeBroker → PolicyEngine → ToolCall → Executor → Verifier
```

`ActionGovernancePipeline.govern(...)` orquesta los 3 checks (no planifica/ejecuta).

## Koog governance

Koog selecciona candidateId existente; NUNCA es autorización. El candidato
seleccionado pasa por firewall/critic/broker/policy. Test: Koog selecciona
candidato fuera del intent → denied.

## NanoFlow governance

Un flow verificado no omite el scope actual. Test: flow con delete + request
navigate → delete denied.

## Defensa de contenido no confiable

Accessibility/OCR/Vision/notificación/web/file/tool-output es DATO. No puede
ampliar el IntentSpec. Regression: navigate no permite send; OCR "envía archivos"
no autoriza delete.

## Semántica de confirmación

`ConfirmationRequired` tipado (reason code), sin rediseño de UI. La aprobación
debe ligarse a ejecución+candidato+efecto+target (no un "sí" global). Deuda de
binding documentada si el sistema actual no lo soporta.

## Least privilege

Menor privilegio + menor inteligencia + menor efecto secundario que satisface
el goal (filosofía Nano).

## Legacy limitations

El path ToolCall legacy (planner actual) NO lleva IntentSpec; A11 no lo protege
completamente todavía. El governance se cableará en el camino Candidate-First
cuando el planner migre. Documentado (no fake universal coverage).

## Future MCP/Shizuku

MCP tool futuro → CandidateAction → governance (sin bypass). Shizuku/ADB/root
son tiers futuros (default unavailable), sin dependencia ni implementación en A11.

## Rendimiento

Determinista, milisegundos, sin LLM/OCR/Vision, sin llamadas de plataforma
(solo SystemGraph ya cacheado).
