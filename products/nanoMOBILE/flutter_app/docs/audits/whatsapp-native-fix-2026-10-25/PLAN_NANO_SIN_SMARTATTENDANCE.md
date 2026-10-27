# Revisión del plan: únicamente Nano Mobile

Fecha: 25 de octubre de 2026. Se contrasta el texto aportado con el código de Nano y las comprobaciones físicas de WhatsApp de esta intervención. El documento aportado es una propuesta, no evidencia de implementación.

## Corrección de alcance

**SmartAttendance Bridge: NO APLICA.** Un puente privado entre dos apps sería una integración opcional para inspeccionar el estado interno de otra aplicación propia. Su ausencia no es un defecto de Nano ni impide abrir WhatsApp instalado, buscar un contacto, preparar contenido, ejecutar un envío o volver a Nano.

Quedan fuera del plan de Nano:

- `com.nano.permission.QA_BRIDGE` para SmartAttendance.
- Dependencias con `smartattendance_app`, flavors QA de ese proyecto y endpoints IPC de asistencia.
- Aserciones `attendance.count`, `sync.pendingCount`, registro de asistencia y fixtures de esa otra app.
- Las suites SA-* y su aprobación como requisito para liberar Nano.

No se ha añadido ese permiso, puente o dependencia como parte de esta intervención. El proyecto hermano no se modifica ni se elimina. Podría ser un objetivo de pruebas en un encargo separado, igual que cualquier otra app autorizada; eso no lo convierte en parte del producto Nano.

## Lo que el documento confunde

| Afirmación o propuesta | Contraste real | Decisión |
|---|---|---|
| C14 debe ser el coordinador único | `C14Benchmark` construye y llama a `AutomationCoordinator.execute`; es un harness de benchmark | Conservar al coordinador real, no convertir C14 en un segundo motor |
| JKeyword al 100 % | El propio texto introduce ese nombre como propuesta; no aparece una implementación JKeyword en la búsqueda de código de Nano | Opcional: adaptar un contrato a ToolCall/NanoFlow existentes antes de crear otro lenguaje |
| Falta toda verificación de objetivos | `GoalVerifier` ya devuelve `unverified` sin expectativa y comprueba paquete, texto, ausencia, checked y predicados | Fortalecer criterios y casos débiles; no sustituirlo por intuición |
| No hay persistencia de ejecución | `ActionLedger` es memoria acotada, pero ya existe `SharedPreferencesExecutionJournal` | Reutilizar y conectar lo existente; separar journal de ejecución de historial QA con artefactos |
| Árbol de carpetas e interfaces propuesto | El texto aclara que sus nombres deben ajustarse al repositorio | No tratar nombres propuestos como componentes ausentes obligatorios |
| Bridge con SmartAttendance como gate | Integración de una aplicación distinta | Eliminar ese gate del alcance de Nano |
| Arquitectura keyword-driven garantiza distribución por Play | Es una propuesta de arquitectura; no demuestra aprobación de distribución | Evaluación de distribución aparte, sin prometer aceptación por el nombre del motor |

## Qué falta realmente en Nano

### Prioridad 1: hacer que C14 certifique el objetivo correcto

Las tareas WhatsApp de `lib/features/automation/benchmark/c14_benchmark.dart` todavía usan varias expectativas de solo `expectedPackage: com.whatsapp`, incluso en tareas de búsqueda, mensaje y archivo. Eso no acredita contacto, contenido, adjunto ni regreso.

Deben comprobar la identidad elegida, contenido preparado, acción única, evidencia posterior y retorno esperado. Las cuentas, mensajes y archivos de aceptación deben ser configurables: la suite actual contiene nombres/números/rutas fijas.

El hecho de que el flujo local de WhatsApp se haya corregido y probado no transforma automáticamente esas aserciones de C14 en verificaciones completas.

### Prioridad 2: corregir el preflight real del dispositivo

`c14_runner.dart` asigna `deviceUnlocked` y `screenInteractive` a la misma función `_screenInteractive(runtimeApi)` basada en árbol accesible. Eso necesita separarse en señales reales de bloqueo e interacción del sistema, en vez de asumir que tener nodos acredita ambas condiciones.

### Prioridad 3: dejar de ocultar errores visuales

Se mantiene la supresión `if (details.toString().contains('overflowed')) return;` en tres archivos de `integration_test`: C14, engine device y automation T2. Una comprobación visual no debe esconder esos desbordamientos. Hay que registrar el error y aplicar la política explícita de la suite.

### Prioridad 4: historial QA reproducible dentro de Nano

Falta demostrar un contrato integrado y persistente que relacione escenario/versionado, paso, expectativa, observación, resultado y artefactos. El journal existente no equivale por sí solo a un visor de evidencias o a un reporte QA completo.

Los JSON/HTML de esta auditoría son artefactos generados durante el trabajo en el PC. **No se presentan como un módulo de exportación ya incorporado al APK.**

### Prioridad 5: ampliar la aceptación física de lo que se vaya declarando compatible

Ya se probó apertura por nombre y número desde Automatización; apertura por usuario al perfil exacto; mensaje y PDF con retorno; Auto de la burbuja y vuelta a la app. Los envíos de texto/PDF se ejercitaron mediante la entrada de producción de Nano al mismo handler, sin pulsar Enviar mediante ADB.

Falta certificar las combinaciones no ejecutadas: envío por usuario con clave, grupos, otros formatos, permisos denegados, cancelación en varios momentos, recreación del proceso, orientación y condiciones de red. No es correcto convertir el caso de Emm en «cualquier contacto y cualquier app al 100 %».

### Prioridad 6: contrato determinista antes de más infraestructura

Si se quiere un módulo QA general, primero hay que decidir qué operaciones y aserciones soporta, qué estados devuelve y cómo conserva evidencia. Se puede expresar con contratos versionados sobre los motores actuales. Añadir el nombre JKeyword no resuelve verificación, cancelación o persistencia por sí solo.

La IA local puede ayudar a proponer pasos; no debe ser la prueba de que el resultado ocurrió. Shizuku es una capacidad adicional, no una dependencia obligatoria del recorrido WhatsApp ya probado.

## Arquitectura ajustada al código existente

Usuario o escenario validado → AutomationCoordinator → dispatcher/ejecutores actuales → accesibilidad/intents → verificadores → journal y evidencias.

C14 invoca y mide esa ruta. La UI observa/controla. Un eventual formato de escenarios se compila a las operaciones existentes; no debe competir por el teléfono con otro runner.

## Criterio de aceptación propio de Nano

1. Una ejecución propietaria y cancelación que detenga acciones pendientes.
2. Identidad exacta y resultado observado; acción aceptada no implica objetivo logrado.
3. Esperas y reintentos acotados; ningún reenvío automático tras un resultado incierto.
4. Evidencias por paso y estados distintos para fallo, bloqueo, cancelación y no verificable.
5. Historial y exportación consistentes, ligados al mismo contrato persistente.
6. Recorridos físicos repetibles para las capacidades que Nano anuncie.

**Ninguno de estos criterios depende de SmartAttendance.**

## Fuentes locales revisadas

- `lib/features/automation/benchmark/c14_benchmark.dart`
- `lib/features/automation/benchmark/c14_runner.dart`
- `lib/features/automation/benchmark/c14_preflight.dart`
- `lib/features/automation/application/automation_coordinator.dart`
- `lib/features/automation/engine/execution/goal_verifier.dart`
- `lib/features/automation/engine/orchestration/execution_journal.dart`
- `lib/features/automation/ledger/action_ledger.dart`
- `integration_test/c14_automation_benchmark_test.dart`
- `integration_test/nano_mobile_engine_device_test.dart`
- `integration_test/automation_t2_device_test.dart`
- Evidencias físicas y matriz: `results.json`, `INFORME.md` en esta carpeta.
