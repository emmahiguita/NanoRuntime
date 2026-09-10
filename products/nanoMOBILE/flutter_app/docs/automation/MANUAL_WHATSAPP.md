# Manual Oficial de Automatización con WhatsApp — Nano AI

> **Versión del módulo**: 1.0 (Producción / Headless + UI)  
> **Compatibilidad**: Android 11+ (Validado en Oppo ColorOS 14 / Android 14)  
> **Aplicaciones soportadas**: WhatsApp (`com.whatsapp`) y WhatsApp Business (`com.whatsapp.w4b`)

---

## 1. Arquitectura y Principios de Diseño

Nano AI utiliza una arquitectura nativa de mensajería sin servidores intermedios, sin APIs de nube y sin violar los términos de servicio de WhatsApp:

```
[Notificación WhatsApp] 
         │ (Android NotificationListenerService)
         ▼
[Nano Native Sensor] ──> [EventDedupeStore (SQLite)] ──> [BurstTurnGate (Agrupador)]
                                                              │
                                                              ▼
                                                     [TurnComplexityClassifier]
                                                              │
               ┌──────────────────────────────────────────────┴──────────────────────────────┐
               ▼                                                                            ▼
     [PragmaticFastPath]                                                            [Local LLM Engine]
  (Saludos/Agradecimientos)                                                        (GGUF Local In-Device)
               │                                                                            │
               └──────────────────────────────┬─────────────────────────────────────────────┘
                                              ▼
                               [ConversationDecisionEngine]
                                 (FACTS → DECISION → SEND)
                                              │
                    ┌─────────────────────────┴─────────────────────────┐
                    ▼                                                   ▼
            [Calidad/Seguridad OK]                             [Modo Sugerencias / Hold]
                    │                                                   │
                    ▼                                                   ▼
        [RemoteInput Reply Transport]                          [PendingReplyStore]
       (Envío oficial Android headless)                     (Aprobación en Bandeja UI)
```

### Invariantes Clave
1. **0% Fugas a la nube**: La inferencia corre 100% en el procesador del dispositivo móvil (GGUF local).
2. **Opt-in explícito**: WhatsApp no se activa automáticamente; requiere consentimiento informado del dueño.
3. **Deduplicación estricta**: Cero respuestas dobles o bucles infinitos por autoreenvíos ("Tú: ...").
4. **Respeto al control humano**: Si el dueño toma la conversación o el modo es *Sugerencias*, Nano prepara el borrador y espera aprobación en la pantalla de mensajes.

---

## 2. Requisitos Previos del Dispositivo

Antes de iniciar la automatización, asegúrate de contar con:
- Dispositivo Android con Android 11 o superior.
- WhatsApp o WhatsApp Business instalado y con sesión iniciada.
- Modelo de lenguaje local descargado en Nano AI (ej. Qwen 2.5 1.5B Instruct o Llama 3.2 1B/3B GGUF).
- **Importante**: Las notificaciones de WhatsApp deben estar habilitadas con vista previa de mensaje (no ocultar contenido en pantalla de bloqueo).

---

## 3. Guía de Configuración Paso a Paso

### Paso 1: Descargar o Seleccionar el Modelo Local
1. Abre Nano AI y ve a la pestaña **Modelos** (`/models`).
2. Descarga un modelo optimizado para tu dispositivo (recomendado: `Qwen2.5-1.5B-Instruct-Q4_K_M.gguf` para respuesta rápida en CPU/Vulkan).
3. Asegúrate de que el modelo quede seleccionado como el modelo activo del sistema.

### Paso 2: Abrir la Guía de Activación de WhatsApp
1. Dirígete a la sección **Automatización** (`/automation`).
2. Toca en **Ajustes de automatización** y selecciona **Guía de activación y permisos** (o navega directamente a `/automation/whatsapp-onboarding`).
3. Verás la lista de 5 prerrequisitos esenciales.

### Paso 3: Conceder Acceso a Notificaciones
1. En el checklist, pulsa **Conceder** en el ítem **1. Acceso a notificaciones**.
2. Android abrirá la pantalla del sistema de *Acceso a notificaciones*.
3. Busca **Nano AI** y activa el interruptor. Confirma el diálogo de seguridad de Android.
4. Al regresar a Nano AI, el ítem se marcará como `✓ OK`.

### Paso 4: Conceder Exención de Batería
1. Pulsa **Conceder** en el ítem **2. Exención de batería**.
2. Acepta el diálogo del sistema *"¿Permitir que Nano AI funcione siempre en segundo plano?"*.
3. Esto garantiza que el sistema operativo no congele el listener cuando el teléfono entre en modo de suspensión (*Doze mode*).

### Paso 5: Activar Procesamiento en Segundo Plano
1. Pulsa **Activar** en el ítem **3. Segundo plano (Background)**.
2. Esto habilita el servicio en primer plano (`Foreground Service`) que mantiene despierto el receptor de mensajes aún cuando la interfaz de Nano AI esté cerrada.

### Paso 6: Habilitar WhatsApp o WhatsApp Business
1. En el checklist, pulsa **Activar** en **5. Regla de WhatsApp activa**.
2. O bien, ve a **Ajustes de automatización → Aplicaciones de WhatsApp** y activa los toggles correspondientes:
   - `[x] WhatsApp (com.whatsapp)`
   - `[x] WhatsApp Business (com.whatsapp.w4b)`

---

## 4. Modos de Autonomía de Conversación

En **Ajustes de automatización → Autonomía de WhatsApp**, puedes alternar entre tres niveles de control:

| Modo | Comportamiento | Casos de Uso Recomendados |
| :--- | :--- | :--- |
| **Sugerencias** *(Inbox)* | Nano genera el borrador contextual pero **NO envía nada**. Los mensajes se guardan en la bandeja de *Mensajes y notificaciones* para ser editados o enviados manualmente. | Primeros días de uso, atención a clientes críticos o validación de tono. |
| **Auto Seguro** *(Recomendado)* | Nano responde automáticamente saludos, agradecimientos y preguntas con datos verificados del negocio. Si una pregunta involucra compromisos o hechos desconocidos, retiene la respuesta. | Negocios con horarios definidos y atención híbrida bot/humano. |
| **Totalmente Autónomo** | Nano responde con máxima agilidad todas las preguntas que entren a WhatsApp de acuerdo con la persona configurada. | Automatización 24/7 de preguntas frecuentes y primer contacto. |

---

## 5. Bandeja de Borradores Pendientes (Modo Sugerencias)

Cuando el modo está en **Sugerencias** o el motor retiene una respuesta:
1. Abre la pantalla **Mensajes y notificaciones** (`/automation/messages`).
2. En la parte superior verás la tarjeta **Respuestas pendientes de aprobación**.
3. Cada tarjeta muestra:
   - Aplicación (`WhatsApp` o `WhatsApp Business`).
   - Contacto o remitente.
   - Mensaje entrante original.
   - Borrador propuesto por Nano AI.
4. Acciones disponibles:
   - **[Descartar]**: Elimina el borrador propuesto sin responder.
   - **[Editar]**: Abre un editor emergente para ajustar el texto antes del envío.
   - **[Enviar]**: Envía la respuesta inmediatamente a través de la API oficial de RemoteInput de Android.

---

## 6. Personalización del Agente y Datos del Negocio

Para que las respuestas de WhatsApp sean coherentes y fieles a tu identidad:
1. Ve a **Ajustes de automatización → Persona del dueño**:
   - Ingresa tu nombre (ej. *Emmanuel*).
   - Define el estilo de habla o tono deseado (ej. *amable, directo, informal*).
2. Ve a **Ajustes de automatización → Datos del negocio**:
   - Agrega tu catálogo de productos o servicios con nombres y precios.
   - Define la política de precios y horarios de atención.
   - El clasificador `TurnComplexityClassifier` usará estos hechos para resolver consultas comerciales sin alucinaciones.

---

## 7. Preguntas Frecuentes y Solución de Problemas

#### ¿Por qué Nano no responde cuando la pantalla está apagada?
- Verifica que la **Exención de optimización de batería** esté concedida.
- En dispositivos Oppo/ColorOS, Xiaomi/MIUI o Samsung, activa adicionalmente el permiso de **Inicio automático (Auto-start)** para Nano AI en los ajustes de Aplicaciones de Android.

#### ¿WhatsApp puede bloquear mi número por usar Nano AI?
- **No**. A diferencia de bots que usan librerías no oficiales o emulan WebSockets, Nano AI utiliza las APIs oficiales del sistema operativo Android (`NotificationListenerService` y `RemoteInput.Action`). Para WhatsApp, la acción es idéntica a cuando tú pulsas "Responder" desde la barra de notificaciones.

#### ¿Qué sucede si respondo manualmente desde WhatsApp?
- Nano detecta el evento de entrada y marca la conversación bajo **control humano**. Mientras estés activo en la conversación, Nano no interferirá con respuestas automáticas.

#### ¿Cómo desactivar temporalmente las respuestas automáticas?
- Cambia el modo a **Sugerencias** o desmarca los toggles de WhatsApp en **Ajustes de automatización → Aplicaciones de WhatsApp**.
