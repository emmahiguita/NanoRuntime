# Nano Mobile como agente local de automatización y QA

Fecha de análisis: 25 de octubre de 2026.
Alcance: lectura de código actual y documentación oficial. No se modificó código
productivo, no se instalaron herramientas ni se ejecutaron nuevas pruebas en el teléfono.
El grafo de código devolvió Transport closed; se continuó con las fuentes locales.

## Dictamen
Es viable extender Nano para ejecutar escenarios QA directamente en Android, sin
ARTEMIS y sin llamadas a APIs comerciales. La base ya existe. No está demostrado
que el producto actual complete toda la propuesta ni que controle cualquier app.
Sin coste por llamada API no equivale a cero consumo de RAM, batería, almacenamiento,
mantenimiento o compatibilidad. Descargar modelos y preparar aplicaciones de prueba
puede requerir conectividad; su ejecución posterior puede ser local.

## Base observada en el repositorio
| Pieza | Evidencia | Alcance real observado |
|---|---|---|
| Accesibilidad | AgentAccessibilityService y XML | Árbol UI, gestos, entrada ligada al nodo, lanzamiento de paquetes |
| Capturas | takeScreenshotDetailed + NanoAtomicSnapshotter | API de accesibilidad Android 11+, captura/árbol con tiempos y errores |
| OCR | perceptionMuxProvider + MlKitOcrBackend | Lectura local de texto; no demuestra por sí sola lógica de negocio |
| Visión | MlKitVisionBackend | Etiquetado general, SemanticRole.unknown; no localizador universal de controles |
| Clasificación UI | VisualGroundingResolver | Palabras clave de IDs/descripciones/OCR; no procesa píxeles como VLM |
| Shizuku | ShizukuToolHandler + PackageActionService | Operaciones concretas de paquetes/permisos; no acceso ilimitado |
| QA físico | C14Benchmark + runC14Benchmark | Invoca coordinator real y genera métricas/JSON |
| Ruta sin LLM | C14Suite.requiresLlm=false | Permite escenarios deterministas sin modelo ni ARTEMIS |
| Verificación | GoalVerifier + GoalExpectation | Paquete, texto, checked y predicados de plataforma si se declaran |
| Export actual | _exportJson | Vista JSON copiable; no constituye aún un informe QA completo con evidencias |

Referencias y huellas de archivos: source-evidence.json. Se diferencia código
implementado de comportamiento validado en el teléfono; no se repitió una validación
física de cada pieza en este análisis.

## Carencias concretas que impiden certificar QA completo
1. Las tareas WhatsApp de C14 comprueban principalmente expectedPackage. Tener
   WhatsApp delante no demuestra contacto, texto, archivo enviado ni regreso correcto.
2. El preflight usa árbol no vacío para inferir desbloqueo. Una pantalla de bloqueo
   puede exponer nodos; debe separar KeyguardManager, PowerManager y disponibilidad UI.
3. El gate falseSuccess solo cuenta goalSuccess con plan inválido. Un plan válido
   también puede fallar el objetivo: la postcondición y su evidencia son independientes.
4. integration_test/c14_automation_benchmark_test.dart ignora FlutterError si contiene
   overflowed. Eso puede servir a un diagnóstico específico, pero no a una auditoría
   visual que pretende detectar precisamente problemas de tamaño y diseño.
5. whatsapp_e2e_automation_test.dart sustituye agenda y transporte con dobles que
   devuelven true; verifica lógica y no WhatsApp instalado.
6. La suite integra destinatarios, textos y rutas de archivos fijos y ejecuta con
   confirmed:true. Antes de exponerla como QA general necesita parámetros, archivos
   de prueba controlados y autorización del alcance. No ejecutar indiscriminadamente.
7. El benchmark genérico AutomationBenchmarkRunner usa entradas prefijadas para
   grounding y etiquetas de nivel; no es evidencia de cobertura end-to-end.
8. Persistir métricas y mostrar JSON no basta: falta cerrar un contrato QA de caso,
   precondición, dato de entrada, aserción, evidencia, resultado y reproducción.
9. Continúan pendientes los defectos de destinatario/documentos/retorno descritos en
   ../whatsapp-roundtrip-2026-10-25/AUDIT.md. Este análisis no los corrige.

## Arquitectura recomendada: extender lo existente
Flujo: caso QA → preflight → captura real → selector/acción → espera por condición →
aserción independiente → evidencia → resultado → limpieza y retorno.

- Un ejecutor con propiedad de tarea y cancelación; reutilizar canales nativos,
  executor y política existentes. Evitar otro controlador de accesibilidad paralelo.
- Casos deterministas para regresión, ejecutables sin modelo. IDs/texto/semántica
  primero; coordenadas solo con evidencia actual y contexto comprobado.
- La IA local puede proponer o explorar rutas; un caso guardado se repite con sus
  selectores y aserciones. La misma generación del plan no certifica su éxito.
- Roles de modelo explícitos: modelo de texto recibe árbol/OCR; píxeles requieren
  un VLM compatible conectado al runtime. No asignar visión por nombre o tamaño.
- Resultados: aprobado, fallido, bloqueado, no verificable, cancelado. Registrar
  esperado/observado y referencias a captura/árbol antes y después de cada paso.
- Persistencia con el almacén SQLite existente y un índice de evidencias; no agregar
  Room solo por arquitectura si no aporta una necesidad nueva. Export JSON/HTML
  desde los mismos datos; errores encontrados por reglas y sospechas de IA separados.
- Límites de pasos/tiempo y detección de bucles; no repetir envíos tras resultado
  incierto. Limpiar callbacks y tareas al cancelar, abandonar ruta o perder servicio.
- Modo local exige no recurrir silenciosamente a un proveedor remoto. Capturas y
  datos de prueba permanecen locales salvo autorización explícita de exportación.
- El contenido leído de otras apps es dato no confiable, no instrucciones que puedan
  cambiar el objetivo. Limitar apps/acciones/datos al caso autorizado.
- Si falta semántica o la pantalla está protegida, registrar bloqueo y evidencia
  disponible, sin inventar una detección o burlar restricciones de captura.

## Modalidades
1. Nano sin modelo: escenarios y validadores locales. Base de regresión más predecible.
2. Nano con modelo local: ayuda a interpretar texto y proponer exploración, sujeto a
   hardware, contexto y capacidades realmente conectadas; sin coste por llamada API.
3. Nano con Shizuku: diagnóstico/acciones de sistema que realmente admita la identidad
   shell y el fabricante, con permisos y disponibilidad comprobados. Android 11+
   permite inicio inalámbrico sin PC; normalmente debe reiniciarse tras un reboot.
4. ARTEMIS opcional: observador externo para descubrir rutas y contrastar resultados.
   Su configuración actual usa modelos remotos; no es requisito del motor propio.
5. PC opcional: preparación/compilación de tests, ejecuciones en varias versiones,
   CI y diagnósticos más profundos. Ejecutar dentro del teléfono no equivale a poder
   construir, instalar e iniciar instrumentación desde un APK normal sin privilegios.

## Otras herramientas y dónde aportan
| Opción | Uso recomendado | Requisito/límite |
|---|---|---|
| UI Automator | Flujos entre apps y sistema, aserciones y capturas | Instrumentación Android/runner; preparación e inicio autorizado |
| Maestro CLI local | Regresiones declarativas rápidas | Host Windows/macOS/Linux y dispositivo; no es un SDK autónomo para el APK |
| Appium + UiAutomator2 | Suites amplias, WebDriver, varios lenguajes y CI | Host, servidor y SDK; más infraestructura |
| Flutter integration_test + Patrol | Nano y otras apps Flutter propias; widgets y UI nativa | Código/build de pruebas; no prueba cualquier APK por inyección mágica |
| Espresso / Compose Test | Apps propias Android con validaciones internas | Instrumentación y acceso al proyecto/configuración de test |
| Perfetto / Macrobenchmark | Diagnosticar arranque, frames y trabajo del sistema | Trazas/permisos; métricas detalladas dependen del build y la plataforma |

No se recomienda introducir todas estas herramientas dentro de Nano. Elegir una
ruta por necesidad y conservar el motor local como núcleo.

## Qué verificar en SmartAttendance
Preparar una cuenta y registros QA identificables, lista de pantallas y reglas:
campos obligatorios, validación de identificación, duplicados, cámara, permisos,
ubicación, navegación, guardado, reabrir, orientación y escala de texto.
La conectividad debe probarse con un estado real controlado y restaurable; app
abierta sin red no demuestra datos guardados ni sincronización posterior correcta.
Las pruebas que registran asistencia deben usar un entorno/datos de prueba autorizados.
No se afirma cobertura de todas las pantallas hasta conocer las rutas y condiciones
que las hacen accesibles. Capturas detectan indicios; código, logs y bases internas
requieren instrumentación/acceso adicional.

## Distribución y límites de Android
La captura AccessibilityService.takeScreenshot existe desde API 30 y requiere
canTakeScreenshot. Las ventanas seguras pueden impedir la imagen. MediaProjection
es alternativa para sesiones de captura autorizadas; Android 14+ exige consentimiento
por sesión y el tipo/permiso de servicio de primer plano correspondiente.
La política actual de Google Play distingue automatización estática definida por
humanos de planificación/ejecución autónoma por accesibilidad, prohibida para un
asistente general. No prometer paridad de la edición Play con una edición QA completa.
La edición APK sigue sujeta a permisos, protecciones Android y condiciones de las apps.

## Orden de implementación recomendado
1. Corregir identidad, resultado y retorno del flujo Nano–WhatsApp; una tarea y un dueño.
2. Endurecer C14 con aserciones del objetivo, estado real de bloqueo y errores UI visibles.
3. Caso QA local persistido + capturas/árbol + export JSON/HTML reproducible.
4. Primera suite pequeña de SmartAttendance con datos de prueba controlados.
5. Añadir exploración local y extensiones Shizuku según evidencia; comparar opcionalmente
   con UI Automator/Patrol/ARTEMIS desde el entorno de desarrollo.

## Fuentes primarias consultadas
- Android AccessibilityService: https://developer.android.com/reference/android/accessibilityservice/AccessibilityService
- MediaProjection: https://developer.android.com/media/grow/media-projection
- Shizuku: https://shizuku.rikka.app/guide/setup/
- Google Play: https://support.google.com/googleplay/android-developer/answer/10964491?hl=en
- UI Automator: https://developer.android.com/training/testing/other-components/ui-automator
- Appium UiAutomator2: https://appium.github.io/appium-uiautomator2-driver/latest/getting-started/
- Maestro CLI: https://docs.maestro.dev/maestro-cli
- Flutter testing: https://docs.flutter.dev/testing/overview
- Espresso: https://developer.android.com/training/testing/espresso
- ML Kit image labeling: https://developers.google.com/ml-kit/vision/image-labeling/android
- Perfetto: https://perfetto.dev/docs/quickstart/android-tracing
