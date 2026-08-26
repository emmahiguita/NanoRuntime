# A14.7 — Notification → AppGraph → ScreenGraph Continuation Bridge

> Estado: fallback trigger implementado (canReply=false → launch_app grounded con
> `ForegroundPackageEquals`). Es un puente de continuidad, NO un segundo planner.
> Ruta más barata verificada primero.

## Principio de enrutamiento

```
1. native notification RemoteInput   ← más barata y fiable
2. official Android/system API
3. verified NanoFlow
4. structured app capability
5. Accessibility / ScreenGraph
6. OCR enriched UI
7. Vision
8. coordinates LAST
```

No se abre una app si RemoteInput puede satisfacer la tarea.

## Flujo

```
"responde a Juan"
        │
        ▼
Notification Graph
        │
   canReply?
    /     \
   sí      no
   │        │
RemoteInput launch_app(grounded)
   │        │
   │     VERIFY ForegroundPackageEquals
   │        │
   │     ScreenGraph (re-percibe)
   │        │
   │     Candidate UI (tap/write/send)
   │        │
   └────┬───┘
        ▼
    Governance → Execute → Verify → Learn
```

## Qué se implementó

- `NotificationCandidateProvider` distingue:
  - `canReply=true` → `reply_notification` (RemoteInput), sin abrir app.
  - `canReply=false` → `launch_app` grounded al `packageName` real de la
    notificación, con `expectation: ForegroundPackageEquals(package)`.
- El package sale de la notificación (evidencia), NUNCA del LLM.
- Tras el launch, el `ScreenGraphCandidateProvider` (ya existente, A15.5)
  re-percibe la pantalla y genera candidatos UI grounded.

## Infra que YA existía (A15.x) y se reutiliza

- `ScreenGraphCandidateProvider` (A15.5): objetos UI → candidatos tap con
  selector text=/desc=/id= (no coordenadas ambiguas).
- `PerceptionMux` (Accessibility → OCR → Vision seam).
- Normalización OCR `imageRelative → screenAbsolute` (A15.6) — `toScreenAbsolute`
  en `ocr_perception_source.dart`. **Corregido antes de que el puente use OCR
  para un tap real.** Ninguna acción física usa bounds ambiguos.

## Continuidad del intent

Abrir WhatsApp NO crea un nuevo intent. El `IntentSpec` original (reply a Juan)
sigue durante toda la tarea. La notificación y el ScreenGraph son DATO; el goal
sigue siendo la autoridad. El contenido de notificación/pantalla es NO CONFIABLE
(no puede expandir el alcance).

## Outcomes tipados (fallo de continuación)

directCapabilityUnavailable · appNotLaunchable · foregroundNotVerified ·
targetNotFound · targetAmbiguous · inputNotFound · sendControlNotFound ·
moreEvidenceRequired · confirmationRequired · denied · completedUnverified.

No hay "automation failed" genérico.

## Seguridad

- Sin nuevos privilegios (usa notification + public Android + Accessibility + OCR).
- El envío de mensaje sigue siendo `externalWrite` → policy/critic/confirmation.
- `message_delivered`/`message_read` NO se asumen sin evidencia independiente.

## Limitaciones / siguiente paso

- La re-planificación tras el launch depende del loop multi-paso ya existente
  (`runPlanGuarded` + `replans`). El write/send como candidatos semánticos
  (`write_text`, `send_message`) y la resolución de conversación en pantalla son
  el foco de **A14.8** (ScreenGraphCandidateProvider productivo para esos roles).
- `ConversationOpenEquals` se resuelve como foreground package (el id exacto de
  conversación no es observable fiable).
