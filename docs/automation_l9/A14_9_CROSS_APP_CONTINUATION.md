# A14.9 — Cross-App Continuation (base: data flow entre dominios)

> Estado: fundación de extracción de DATOS OBSERVADOS → acción de otro dominio
> (Notification → Linux write). Determinista, sin LLM.

## Objetivo

Permitir que una misma intención atraviese varias apps/capas:

```
"Lee el último mensaje de Juan y guarda el enlace que envió en un archivo"
→ Notification (messageText) → extraer URL → Linux writeFile → FileExists verify
```

```
"Abre el enlace que me mandaron y dime qué dice"
→ Notification → extraer URL → browser (requiere tool open_url, siguiente paso)
```

## Qué se implementó

1. `ObservedDataExtractor` — extrae URLs/emails de un texto observado
   (determinista, sin LLM). El dato es OBSERVACIÓN, nunca instrucción.

2. `NotificationDataCandidateProvider` — ante "guarda el enlace / link":
   - lista notificaciones, localiza el target (o la más reciente),
   - extrae la URL del `interpretableText`,
   - genera `linux.writeFile(path, content=url)` con `FileExists(path)`
     como postcondición (verificación real de escritura).

## Seguridad

- El texto de la notificación es DATO NO CONFIABLE: se extrae un valor
  estructurado, nunca se convierte en comando ni expande la intención.
- El path de destino es un default fijo (`/root/nano_observed_link.txt`) porque
  el usuario no dio destino; no acepta path del LLM.
- El envío/escritura sigue gobernado (risk + policy).

## Limitaciones / siguiente paso

- "abre el enlace" (URL arbitraria) requiere un tool `open_url` (intent VIEW)
  que aún no existe; el `open_system` es para destinos allowlisted. Es el
  siguiente paso natural.
- El target de conversación se resuelve por sender/conversationTitle (igual que
  A14.6); no hay extractor de "cuál mensaje" si hay varios URLs.
- La orquestación multi-app completa (planner que descompone y encadena pasos
  cross-domain con data flow) es el trabajo de A14.9 en curso; esta fase aporta
  la pieza fundacional de data flow.

## Secuencia

```
A14.5 → A14.5.4 → A14.6 → A14.7 → A14.8 → A14.9 (base)
```

Todos commiteados, 484 verdes, build instalado.
