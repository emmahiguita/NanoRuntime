# Pruebas Nano / WhatsApp — 27 de octubre de 2026

## Resultado y alcance

Dispositivo real OPPO CPH2557, Android 15, paquete `dev.nanoai.mobile`, versión
1.0.0 (versionCode 1). Se probaron la barra de Automatización y el panel Búho
interno de la versión instalada. No se cambió código de la aplicación ni temas,
permisos o cuentas. No se certifica todo Nano.

**29 pruebas de lógica aprobadas, cero fallos en esa ejecución.** Estas tres
pruebas usan dobles explícitos de agenda/canal: no demuestran envíos reales.
Salida completa: [pruebas-logica.log](pruebas-logica.log).
El primer intento de arrancar Flutter falló antes de ejecutar tests por PATH de
PowerShell; con la ruta correcta, la ejecución terminó con exit code 0.

## Casos en el teléfono

| Caso | Esperado | Observado | Resultado |
| --- | --- | --- | --- |
| + | Una superficie con Cámara, Fotos, Archivos y Complementos | Filas visibles sin doble cierre | Observado |
| Complementos | Solo WhatsApp; seleccionar prepara contexto | Logo activo y Nano sigue enfocado | Aprobado |
| Abre WhatsApp | Nano abre aplicación instalada | `com.whatsapp/.home.ui.HomeActivity` enfocada | Aprobado tras aislar interferencia |
| Mensaje autorizado | Nano resuelve el número, escribe y envía una vez | Cabecera confirmada y tap por ID `com.whatsapp:id/send` | Acción comprobada |
| Eco local | Texto nuevo del intento | Mensaje exacto visible a las 3:01 a. m. | Comprobado localmente |
| Retorno del envío | Nano vuelve por sí mismo | Log de retorno true y MainActivity enfocada | Aprobado |
| Chat por número | Nano abre el chat solicitado sin mensaje adicional | `com.whatsapp/.Conversation`, Emm; perfil con número autorizado | Aprobado |
| Búho interno | Abre/cierra su panel | Controles y editor visibles; cierre funcional | Observado |
| Archivos/cancelar | Selector real y retorno sin archivo | DocumentsUI PickActivity; Atrás retorna a Nano, editor vacío | Aprobado |

Se ejecutó **un solo envío**, autorizado expresamente en este chat:
«Prueba de Nano: apertura, envío y regreso» al número +57 320 3527283.
El perfil observado muestra Emm, @AIemmaDev y ese mismo número.
La cabecera y el eco nuevo se comprobaron después sin repetir el envío.
Ni ARTEMIS ni el operador escribieron o pulsaron Enviar dentro de WhatsApp
para sustituir a Nano.

Registro nativo del único envío:

- 03:01:30.798: destinatario confirmado en cabecera.
- 03:01:30.837: envío ejecutado por Resource ID.
- 03:01:30.837: acción pulsada, entrega no confirmada por WhatsApp.
- 03:01:31.769: regreso verificado a Nano: true.

Estas horas son las del teléfono. La diferencia entre tap y retorno corresponde
a una sola ejecución, no a un benchmark ni a una promesa de rendimiento.
El eco local no acredita entrega, recepción o lectura remota.

## Incidentes de las herramientas, separados de Nano

1. ARTEMIS Pro, traza `3f89c0c2-a027-4528-896d-30663b76e0b8`, terminó por
   errores 503/429 del proveedor y cierre del runner. No se marca como fallo
   funcional de Nano. Se leyó stderr y se ejecutó mobile_diagnose antes de continuar.
2. La inspección alternativa inició `com.mobilenext.mobilecli.DeviceServer`.
   Android mostraba Nano habilitado, pero **Bound services vacío** y
   **Ui Automation activo**. La primera apertura produjo SERVICE_OFF.
3. Tras identificar y cerrar solo ese proceso de pruebas, Nano y el helper
   Artemis volvieron a estar conectados. Se continuó con helper Artemis para
   lectura y ADB para los controles observados, sin UiAutomation supresora.
4. Solo se repitió la apertura sin mensaje después de recuperar la conexión.
   El envío no se repitió.

El primer «No completado» se conserva como evidencia de interferencia del
instrumento; no se utiliza para afirmar que la apertura de Nano esté rota.

## Pendientes encontrados en la interfaz

- **UI01 / P2:** abrir WhatsApp sin enviar nada se representa como «Entrega sin
  confirmar». El estado genérico completedUnverified se transforma en ese texto
  en `lib/features/automation/presentation/widgets/automation_compact_status.dart:25`.
  Esa etiqueta debe distinguir apertura de envío.
- **UI02 / P2:** después del envío con retorno nativo verificado, la barra muestra
  «Por verificar». La presentación está en
  `lib/features/automation/presentation/widgets/automation_input_context_controller.dart:128`.
  Se observó la discrepancia; la pérdida exacta del dato entre capas aún no se
  ha diagnosticado. No se modificó código para ocultarla.

## No ejecutado

Voz/dictado, modelo generativo, Búho externo sobre WhatsApp, Business, destinatario
por nombre o @usuario en dispositivo, envío de PDF/foto/vídeo, modos oscuro y
horizontal, escalado de fuente, medición térmica, recepción y lectura remotas.
El servicio NanoFloatingService no estaba activo en la lectura de servicios;
la burbuja interna de Flutter no prueba la funcionalidad externa.

## Evidencias

- [Menú +](02-menu-abierto.png)
- [Complementos](03-complementos.png)
- [Borrador autorizado](07-borrador-envio.jpg)
- [Resultado y Nano en primer plano](08-resultado-envio.jpg)
- [Eco local del chat autorizado](09-eco-local-chat.jpg)
- [Panel Búho interno](10-panel-buho.jpg)
- [Estado final de Nano](11-nano-final.jpg)
- [Registro de envío y retorno](envio-log-filtrado.txt)
- [Accesibilidad al terminar](accesibilidad-final.txt)
- [Resultados estructurados](RESULTADOS.json)

Las capturas del chat son evidencia local del contacto expresamente autorizado;
no se publicaron ni compartieron externamente. Nano quedó en Automatización,
con editor vacío y sin adjunto elegido. La sesión supresora de inspección quedó
cerrada; no hay tarea ARTEMIS de UI en ejecución.

## Conclusión del alcance

La versión instalada ejecutó el flujo real por número: Nano → WhatsApp instalado
→ acción de envío única → regreso automático a Nano. La inspección posterior
confirmó destinatario y mensaje nuevo. Quedan las discrepancias de estado
indicadas y los casos no ejecutados; no se declara «100 % funcional».

