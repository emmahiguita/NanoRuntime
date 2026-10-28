# FINAL ARCHITECTURE REPORT — Nano Mobile

Fecha: 2026-10-16. Dispositivo de referencia: CPH2557 (MT6833, 8 GB, Mali-G57 MC2).

## 1. Arquitectura actual (diagrama real)

```
                    Flutter (UI + automatización)
   chat manual ──┐                        ┌── notificación WhatsApp
                 ▼                        ▼
   ChatSendUseCase            NotificationEventRouter → RuleDispatcher
        │                              │ → ConversationReplyFlow
        ▼                              ▼
   ChatContextBuilder        RuntimeNotificationDraftWriter
        │                              │ (persona, historial canónico, calidad)
        └──────────────┬───────────────┘
                       ▼
              RoutedLlmEngineClient  (backend por catálogo: gguf | litertlm | mnn)
                       │
        ┌──────────────┼──────────────────┐
        ▼              ▼                  ▼
  GGUF HTTP       LiteRT (JNI)        MNN (JNI)
  nanortime       Engine+Conversation  Llm + jinja + KV reuse
  (proceso aparte)  + presupuesto KV   (CPU, Omni 3B)
        ▲
  Whisper.cpp STT (mismo servidor)
                       ▼
              QualityGate (ConversationReplyQuality + DecisionGuards)
                       ▼
              canonical_messages (SQLite) → envío WhatsApp
```

## 2. Runtime real ejecutándose hoy

- **LiteRT-LM**: automatización (qwen3_0.6b, CPU tras política por tamaño). Funciona: carga 3.5 s, decode hasta 15.1 tok/s, presupuesto de contexto activo, fallback GPU→CPU.
- **MNN**: chat manual opcional (Omni 3B texto). Tras fixes: KV reuse + delta prefill + plantilla nativa. Sigue siendo lento en primer turno en este SoC por tamaño del modelo, no por el runtime.
- **GGUF/llama.cpp**: sin uso reciente para chat; INFRAESTRUCTURA VIVA porque Whisper STT la usa. No borrar.
- **ML Kit**: clasificadores de apoyo (no LLM).

## 3. MNN

- Queda: opción de chat (calidad 3B), libs en APK, supervisión propia.
- Funcionaba bien: calidad de respuesta; empaquetado verificado; simplicidad de una sola sesión.
- Vale la pena rescatar: NADA adicional que no se haya rescatado ya (KV reuse, plantilla nativa). El resto lo cubre LiteRT mejor.

## 4. LiteRT-LM

- Funciona: engine lifecycle, Conversation con KV, cancelación, presupuesto, métricas, GPU/CPU.
- Mal integrado (histórico, ya corregido): sin fallback GPU→CPU; presupuesto en bytes; térmica que lo bloqueaba por completo.
- Debe convertirse en estándar: sí — para automatización y paquetes ≤1.5B en este hardware.

## 5. Bugs

Ver `09_BUGS.md`. Resumen: 8 corregidos en sesión (B1–B6, B8), 4 abiertos (B7 persona vacía, B9 costo de regeneración, B10 consolidar térmica, B11 warm-idle), 2 sin verificar (B12 Gemma, B13 calidad en chat manual).

## 6. Latencia

Ver `07_LATENCY_AUDIT.md`. Causas: cold start por warm-idle corto, regeneración por calidad con modelo débil, GPU lenta para modelos chicos (ya resuelto), MNN sin KV (ya resuelto), térmica falsa (ya resuelto).

## 7. Memoria

Ver `06_MEMORY_AUDIT.md`. Sin fugas demostradas. Riesgo real: Gemma 2.6 GB en este RAM; 1.5B q8 condicional. KV estático sin snapshots (coste = full prefill al volver a conversación, no fuga).

## 8. Concurrencia

Ver `05_CONCURRENCY_AUDIT.md`. Single-flight efectivo (LocalModelGate + mutex por motor), cancelación por requestId, unload seguro. Sin doble generación demostrada.

## 9. Conversación

Ver `08_CONVERSATION_AUDIT.md`. Roles estructurados hasta nativo en LiteRT y MNN; historial canónico único; plantilla nativa; calidad antes de persistir (orden correcto verificado). Persona vacía en contactos nuevos = raíz del eco (abierto).

## 10. DECISIÓN

**B — LiteRT-LM principal + fallback específico justificado.**

Evidencia:
- LiteRT es el único runtime con: Conversation/KV nativo, presupuesto por paquete, GPU+CPU con fallback, métricas reales, y mediciones funcionales en este dispositivo (carga 3.5 s, 15.1 tok/s).
- El defecto de calidad observado (eco/degeneración) proviene del modelo 0.6B q4 + persona vacía, no del runtime (el mismo runtime entregó un draft aceptado y enviado a las 14:44).
- MNN conserva UNA ventaja real: calidad del Omni 3B para chat manual. Se mantiene como opción de chat (fallback específico), no para automatización en MT6833.
- GGUF no se elimina porque Whisper STT depende del servidor. El chat GGUF queda LEGACY hasta confirmar que nadie lo usa (test de uso) — entonces evaluar retirar solo la ruta chat-GGUF, no el servidor.

Próximo paso único (no arquitectura): colocar Qwen2.5-1.5B ekv4096 (descargado, SHA verificado) como modelo de automatización y ejecutar la batería diferencial de `03_GEMMA_QWEN_DIFFERENTIAL.md`. Si 1.5B pasa calidad con persona vacía, se cierra B7 sin tocar guardas.

## Criterio de éxito (del encargo)

- Gemma funciona en este dispositivo: UNVERIFIED (probable OOM).
- Qwen funciona: PARCIAL (0.6B rápido pero débil; 1.5B pendiente de prueba).
- Persona siempre presente: NO (B7 abierto).
- Roles nunca se mezclan: sin reproducción esta sesión; HYPOTHESIS cerrada por fixes de template/KV.
- Outputs defectuosos no contaminan historial: VERIFICADO en código y logs.
- Sin respuestas duplicadas / doble inferencia: VERIFICADO (single-flight + requestId).
- 100 turnos continuos: PENDIENTE (test manual requerido).
- Background == foreground: misma infraestructura; PENDIENTE test comparativo.
- Modelo caliente: PARCIAL (warm-idle 90 s, B11).
- RAM estable: sin fuga demostrada; falta test largo.
- Contexto gestionado: SÍ (budget + descarte de turnos).
- TTFT medible y consistente: SÍ (4.4–12.5 s según backend/modelo).
- Sin crashes nativos: ninguno en sesión.
