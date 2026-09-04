# WA-GAPS-01: textMatch + retry de arranque en frío

Fecha: 2026-09-04. Alcance: módulo de automatización universal, parte WhatsApp.
Dos gaps verificados en código tras el cierre del programa WA (WA-PHYS-11,
WA-AGENT-09, SUG-01, SKILL-CONS-01).

## Contexto

- `NotificationTrigger` solo filtra por `packageName` + `senderMatch`
  (`engine/scheduling/trigger.dart:33-40`): cualquier mensaje del contacto
  dispara la regla. No existe filtro por contenido del mensaje.
- Primera llamada al motor local tras arranque devuelve 0 chars en ~45ms
  (warm-up frío): el borrador dinámico falla fail-closed sin reintento
  (evidencia WA-PHYS-EMM 2026-09-03).
- Metodología del repo: sin tests unitarios; validación manual física en Oppo
  CPH2557. Fail-closed honesto es pilar (Filosofía NanoRuntime).

## 1. textMatch — filtro por contenido

### Modelo y matching

- `NotificationTrigger` gana `final String? textMatch` (null = cualquiera).
- `triggerToJson`/`triggerFromJson`: clave `'textMatch'`.
- `NotificationEvent` gana `final String? text` (texto del mensaje).
- `NotificationEventAdapter.fromNotification` pasa `n.interpretableText`
  (`NotificationObject.interpretableText` = mensaje individual > texto grande).
- `evaluateTrigger`: `textOk` = textMatch null/vacío OR
  `event.text?.toLowerCase().contains(match.toLowerCase())`, en AND con
  pkgOk/senderOk. Evento sin texto → textMatch no matchea (fail-closed).
- Sin cambios Kotlin: `NotificationAutomationService.toMap` ya expone
  `messageText` (línea 154, MessagingStyle). Único constructor de eventos en
  `notification_event_adapter.dart`; único evaluador `rule_engine.dart` →
  `evaluateTrigger`. Cambios acotados.

### Parser (`trigger_parser.dart`)

- Verbo ampliado: `(?:escrib|dig[ao])` — cubre diga/digas/digan/digo sin
  matchear "dime".
- Extracción de textMatch: tras el verbo, resto antes de la coma (sin coma →
  todo el resto tras el verbo es textMatch y el goal queda vacío).
  - Contiene comillas simples/dobles → contenido entre comillas.
  - Resto plano no vacío → textMatch = resto.
  - Resto vacío → null.
- "cuando digan 'hola'" (sin remitente) ahora permitido: parse devuelve null
  solo si sender Y textMatch quedan vacíos.
- Camino "mensaje de X": captura de sender para en comilla/coma
  (`(.+?)(?=\s+['"]|,|$)`), para no tragarse el texto del filtro.

### UI (`automation_rules_screen.dart:385` `_triggerLabel`)

- Con textMatch: `$package · contacto "$sender" · texto "$match"`.
- Sin sender: `$package · texto "$match"`.

## 2. Retry de arranque en frío

### Helper compartido

Archivo nuevo `engine/model/cold_start_retry.dart`:

```dart
Future<String> generateWithColdRetry(
  LLMEngineClient client, {
  required String prompt,
  required double temperature,
  required int maxTokens,
  Duration threshold = const Duration(seconds: 3),
})
```

Regla: primera salida vacía Y tiempo transcurrido < threshold → UN reintento
con los mismos argumentos. Devuelve el texto final (vacío si sigue vacío).
Log honesto: `[draft] reintento por arranque en frío`.

- Excepciones `LLMEngineException` NO reintentan: fallo real ≠ frío.
- Consumidores (ambos, mismo bug de clase):
  - `engine/model/draft_writer.dart:85` (reply dinámico de reglas) — texto
    final vacío → `DraftRejected('texto vacío del modelo')` como hoy.
  - `engine/notifications/notification_draft_writer.dart:51` (borrador
    contextual A14.7) — vacío → null como hoy.
- Sin tocar dedupe, rate limiter ni governance: el matching de trigger es capa
  anterior al pipeline.

## 3. Fuera de alcance (validación física pendiente, no código)

- RATE-01: rate limiter inerte por dedupe previo — ejercitarlo en Oppo.
- Kill test en vuelo (outcomeUnknown): diseño sin blind retry.
- Latencia 72s de generación local: candidato a métrica honesta.
- Self-heal accesibilidad ColorOS: decisión aparte (banner vs Shizuku).
- Media (`EXTRA_PICTURE`): gap menor, reply por texto funciona.

## 4. Pruebas (manual, Oppo CPH2557)

1. textMatch positivo: regla `cuando X diga "hola", responde...` → mensaje
   "hola" dispara (logcat pipeline + pantalla Reglas).
2. textMatch negativo: mensaje "adiós" del mismo contacto NO dispara.
3. Sin remitente: `cuando digan "hola"` → cualquier contacto con "hola"
   dispara; otro texto no.
4. Retry frío: force-stop app (mata motor), primer WhatsApp tras arranque →
   borrador sale; logcat muestra `[draft] reintento por arranque en frío`.
5. Regresión e2e-1: reply básico de texto fijo sigue 1:1 sin loops.
