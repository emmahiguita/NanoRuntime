# Manual profesional de Nano Negocios para WhatsApp Business

## 1. Propósito y alcance

Nano Negocios atiende conversaciones de `com.whatsapp.w4b` en el dispositivo Android mediante notificaciones y `RemoteInput`. La inferencia y los datos del negocio permanecen locales.

Las plantillas descritas aquí son contratos internos `BusinessProfile`. No son plantillas de mensajes aprobadas por Meta y no se sincronizan con WhatsApp Business Platform.

## 2. Arquitectura operativa

```text
WhatsApp Business
  → NotificationListenerService
  → deduplicación y agrupación del turno
  → clasificación de intención
  → hechos reales + BusinessProfile
  → decisión, bloqueo o entrega a humano
  → borrador o respuesta RemoteInput
```

Responsabilidades:

- `BusinessFacts`: nombre, catálogo, horarios, entrega, pagos y ubicación.
- `BusinessProfile`: política versionada, FAQ, diálogos, reglas y límites.
- `BusinessConversationResolver`: respuestas deterministas basadas en hechos.
- motor local: redacta solo cuando la ruta determinista no resuelve el turno.
- `RuleRegistry`: activa WhatsApp Business únicamente por consentimiento del dueño.

## 3. Plantillas incluidas

| Plantilla | Identificador | Sector |
|---|---|---|
| Barbería | `barbershop.es-co.v1` | Barbería |
| Tienda / Comercio | `retail.es.v1` | Comercio |
| Restaurante | `restaurant.es.v1` | Restaurante |
| Taller | `workshop.es.v1` | Taller |
| Hotel | `hotel.es.v1` | Hotel |
| Consultorio | `clinic-appointments.es.v1` | Salud |
| Inmobiliaria | `realestate.es.v1` | Inmobiliaria |
| E-commerce | `ecommerce.es.v1` | Comercio electrónico |
| Soporte | `support.es.v1` | Soporte |
| Personalizado | `custom.v1` | Personalizado |

Aplicar una plantilla cambia la política y el tono. No reemplaza productos, precios, horarios, cuentas, stock ni direcciones ya guardadas.

## 4. Contrato editable

El esquema vigente es `nano.business.v1`.

| Campo | Uso | Regla |
|---|---|---|
| `templateId` | origen del perfil | no editable desde el formulario |
| `sector` | dominio comercial | no editable desde el formulario |
| `locale` | idioma y región | obligatorio |
| `timezone` | interpretación horaria | obligatorio |
| `currency` | moneda de importes | obligatorio, se guarda en mayúsculas |
| `intents` | intenciones permitidas | lista separada por comas |
| `tools` | capacidades declaradas | no ejecuta herramientas no registradas |
| `blockedAutomation` | acciones que exigen humano | lista separada por comas |
| `faq` | respuestas verificadas | una entrada por línea |
| `dialogues` | slots y pasos esperados | una entrada por línea |
| `rules` | condición y acción | una entrada por línea |
| `handoffMessage` | respuesta al escalar | texto editable |
| `handoffConfidence` | umbral de escalamiento | número entre 0 y 1 |
| `autoReply` | autoriza envío automático del perfil | desactivado conserva el borrador para revisión |
| `maxToolSteps` | límite operativo | entero entre 1 y 8 |
| `approvalAmount` | monto que exige aprobación | entero mayor o igual a 0 |
| `revision` | revisión local | aumenta al guardar |

La revisión identifica el estado activo. La versión actual no conserva un historial automático para restaurar revisiones anteriores.

## 5. Formatos del editor

### FAQ

```text
patrón uno ; patrón alternativo => respuesta confirmada por el negocio
```

Cada línea debe contener exactamente un separador `=>`. La respuesta nunca debe incluir información no confirmada.

### Diálogos

```text
id | INTENT | slot_a, slot_b | paso_a, paso_b
```

Los cuatro bloques son obligatorios. Los slots y pasos se separan por comas.

### Reglas

```text
id | condición | acción | prioridad
```

Los cuatro bloques son obligatorios. La prioridad se normaliza a mayúsculas.

## 6. Configuración inicial

1. Instala e inicia sesión en WhatsApp Business.
2. Descarga y selecciona un modelo GGUF local.
3. Concede acceso a notificaciones a Nano AI.
4. Concede la exención de optimización de batería.
5. Activa el procesamiento en segundo plano.
6. Abre **Nano Negocios → Canales** y activa WhatsApp Business.
7. Selecciona una plantilla y completa los datos reales del negocio.
8. Empieza en modo **Sugerencias** y revisa los borradores manualmente.
9. Activa respuesta automática solo después de validar tono y hechos.

## 7. Criterios de preparación

Antes de operar, verifica:

- listener de notificaciones autorizado y conectado;
- exención de batería concedida;
- procesamiento en segundo plano activo;
- modelo local disponible;
- regla de `com.whatsapp.w4b` activa;
- nombre, horario, ubicación y políticas revisados;
- catálogo sin productos inactivos ni datos desactualizados;
- FAQ sin promesas, diagnósticos o confirmaciones no autorizadas;
- mensaje de entrega a humano configurado;
- modo Sugerencias validado manualmente.

## 8. Seguridad y control humano

- No guardes tokens, contraseñas, CVV ni claves bancarias en FAQ o reglas.
- Una instrucción de pago no equivale a pago confirmado.
- Consultas clínicas, compromisos, cambios de precio y acciones bloqueadas deben escalarse.
- Desactiva el canal si la persistencia de reglas presenta errores.
- El dueño puede retirar el consentimiento apagando WhatsApp Business en **Canales**.

## 9. Diagnóstico

Si no llegan mensajes:

1. confirma que WhatsApp Business muestra el contenido en la notificación;
2. revisa el acceso a notificaciones;
3. revisa batería e inicio automático del fabricante;
4. confirma que la regla de WhatsApp Business está activa;
5. confirma que existe un modelo local utilizable.

Si la respuesta se retiene, revisa la bandeja de borradores: puede faltar un hecho, existir una acción bloqueada o requerirse intervención humana.

## 10. Diferencia con la plataforma de Meta

Esta edición local no implementa WABA, Cloud API, webhooks, plantillas aprobadas, Embedded Signup ni WhatsApp Flows. Para esos casos se necesita un backend separado, credenciales de Meta y los controles de seguridad exigidos por la plataforma.

Referencias oficiales:

- https://www.postman.com/meta/whatsapp-business-platform/overview
- https://www.postman.com/meta/whatsapp-business-platform/folder/lczy75a/templates

## 11. Compilación de distribución

El APK `debug` sirve para desarrollo e instalación interna; no debe publicarse como versión productiva. La compilación `release` exige una clave externa y nunca debe guardar contraseñas en el repositorio.

Variables requeridas por `android/app/build.gradle.kts`:

- `NANOAI_KEYSTORE`: ruta absoluta del almacén de claves;
- `NANOAI_KEYSTORE_PASS`: contraseña del almacén;
- `NANOAI_KEY_ALIAS`: alias de firma;
- `NANOAI_KEY_PASS`: contraseña de la clave.

Comando de compilación:

```text
flutter build apk --release --flavor fullSideload --no-pub --target-platform android-arm64
```

Si falta la firma, Gradle bloquea el release en lugar de producir un paquete falsamente productivo.
