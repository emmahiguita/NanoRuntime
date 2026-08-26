# A14.6 — Notification Capability Graph

> Estado: NotificationObject rico + NotificationCandidateProvider productivo +
> verificación tipada del reply. WhatsApp es una app más, no un caso especial.

## Objetivo

Tratar cada notificación Android como una CAPACIDAD genérica `reply`, no como
una integración por-app. Cualquier app que publique una notificación de
mensajería contestable (Telegram, Signal, Discord, Slack, Teams, WhatsApp, ...)
produce el mismo candidato, a partir de evidencia real del sistema.

## NotificationObject (tipado)

```
NotificationObject
 ├─ packageName, appIdentity, conversationId, conversationTitle
 ├─ sender, messageText, title, text
 ├─ isGroup, isSummary, timestamp (postTime)
 ├─ canReply, remoteInputKey, availableActions[]
 └─ evidence (RemoteInput real)
```

El nativo (`NotificationAutomationService.toMap`) extrae sender/isGroup/
conversation del **MessagingStyle** vía extras + `Message.getMessagesFromBundleArray`
(`extractMessagingStyleFromNotification` no está en la API 36 pública). Apps sin
MessagingStyle quedan con campos vacíos (honesto, no inventado).

## NotificationCandidateProvider (productivo)

```
"responde a Juan"
        ↓
NotificationCandidateProvider
        ↓
lista notificaciones → filtra canReply && key
        ↓
matchea sender/conversationTitle con el objetivo (o la más reciente)
        ↓
CandidateAction(
   semanticAction: reply,
   tool: reply_notification,
   channel: ActionChannel.notification,
   evidence: ActionEvidenceSource.notificationCapability (remoteInputKey)
)
        ↓
IntentFirewall → PreActionCritic → Policy → reply_notification
```

Registrado en `CandidateActionGenerator` (agent_dependencies) junto a los demás
providers. El `packageName`/`remoteInputKey` salen de la evidencia, nunca del LLM.

## Verificación tipada del reply (sin false success)

El `ReplyResult` nativo ya distingue códigos, que modelan la progresión:

```
reply_requested
   ├─ INVALID_TEXT / NOTIFICATION_GONE / ACTION_EXPIRED / ACTION_DENIED
   └─ REPLY_UNAVAILABLE         ← no hay acción RemoteInput (no se finge)
        └─ REMOTE_INPUT_ACCEPTED ← PendingIntent.send() sin excepción
             (verificable LOCALMENTE)
             ├─ app_processed_reply  ← potencialmente observable
             ├─ message_delivered    ← NO asumir sin evidencia
             └─ message_read         ← NO asumir sin evidencia
```

`PendingIntent.send()` demuestra que Android aceptó la acción, NO que el
destinatario la leyó. El dispatcher reporta `REMOTE_INPUT_ACCEPTED` como
"entregado a la app", y `[notificationReply:<code>]` para el resto.

## Qué abre

- "responde a Juan" / "contesta a María" → candidato grounded a conversación.
- "resume mis mensajes pendientes", "clasifica mensajes de trabajo" → mismos
  NotificationObject (sin acciones nuevas, solo consulta).
- Reglas futuras ("no respondas grupos", "redacta pero pregúntame") → condicionan
  sobre `isGroup` / `canReply`, siempre bajo governance y autorización.

## Limitaciones

- `EXTRA_CONVERSATION_ID` no es constante pública → se lee la clave literal
  "android.conversationId"; puede venir vacía en algunas apps.
- `canReply` = hay acción con RemoteInput de texto libre (no data-only). Una
  notificación `GROUP_SUMMARY` sin RemoteInput → `canReply=false` (correcto, no
  se contesta un resumen).
- La entrega/lectura del mensaje no se asume; solo `REMOTE_INPUT_ACCEPTED` es
  verificable localmente.
