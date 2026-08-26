# A14.8 — Semantic ScreenGraph Candidates

> Estado: ScreenGraphCandidateProvider genera candidatos SEMÁNTICOS
> (open_conversation, write_message_text, send_message), no solo `tap_<role>`.

## Principio

```
ScreenGraph object != action.

Bad:  tap_button_42
Good: send_message / open_conversation / write_message_text
```

El tool subyacente sigue siendo tap/write, pero la semántica de planificación es
explícita. El provider SOLO GENERA candidatos grounded; no ejecuta, no verifica,
no autoriza, no usa LLM, no inventa target.

## Candidatos semánticos

| Objeto | semanticAction | tool | riesgo |
|--------|----------------|------|--------|
| listItem/card/button que matchea target | `open_conversation` | tap | device (reversible) |
| textField editable (no search/password) | `write_message_text` | write | device |
| textField editable | `focus_message_input` | tap | device |
| button/iconButton con label send/enviar | `send_message` | tap | **externalWrite** (reversible=false) |

## Gate de contexto (corrección clave)

Los candidatos de mensajería SOLO se generan si el objetivo es de mensajería
(verbos: responde/responder/contesta/contestar/enviar/envía/reply). Un textField
o botón "Enviar" en pantalla NO es un compositor de mensaje para un objetivo
arbitrario ("concepto sin match" no produce write/send).

## Deduplicación

Si el mismo objeto produce un candidato semántico + el tap genérico, el
semántico GANA y el tap genérico se omite (object ID cubierto). Evita que el
ranker vea acciones equivalentes duplicadas.

## Target binding

El target ("Juan") se extrae del objetivo y se preserva en el candidato
(`args.conversation`, `id: ui:conversation:<obj>:juan`). El send lleva
`effect=sendExternalMessage` (riesgo externalWrite) para que la governance
verifique el alcance del target. El envío sigue gobernado (policy/critic).

## Verificación

- open_conversation → `mustChangeSnapshot` (cambio de pantalla).
- write → `TextFieldContains(draft)` cuando el draft existe (no false success).
- send → la postcondición observable más fuerte; `delivered`/`read` NO asumidos.

## Seguridad / genericidad

- Sin WhatsApp-specific: vale para Telegram, Signal, Slack, Teams, Discord, Gmail.
- Selector primero (text/desc/resourceId), coordenadas solo último.
- OCR-derived → confianza menor + screenAbsolute (ya normalizado en A15.6).
- Vision no disponible → MoreEvidenceRequired, sin coordenada adivinada.

## Legacy

El tap genérico (A15.5) se mantiene como fallback para objetivos no-mensajería.
No se elimina; el semántico lo reemplaza cuando es equivalente y más fuerte.
