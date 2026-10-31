---
name: nano-internal-browser
description: Usa el navegador integrado de Antigravity App para visualizar páginas y aplicaciones web junto al chat; y, cuando el usuario pide pruebas automáticas, usa las herramientas de navegador realmente disponibles. Actívala al pedir abrir navegador dentro de Antigravity, previsualizar localhost, inspeccionar interfaces web, depurar formularios, revisar documentación o tomar capturas. Distingue App, CLI e IDE y nunca promete ventanas o herramientas no disponibles.
---

# Nano Internal Browser — navegación visual y pruebas verificadas

## Objetivo

Prioriza que las páginas y la aplicación web del proyecto se vean **dentro de Antigravity App**, en su navegador integrado, junto a la conversación. Usa la automatización oficial de navegador únicamente cuando sea compatible con la superficie y herramientas actuales. NO confundas el navegador visual integrado con el subagente `/browser` que controla Google Chrome.

## Identificar la superficie antes de actuar

1. **Antigravity App (versión con built-in browser):** tiene un navegador incorporado en un panel lateral. Puede abrirse pulsando un enlace web mostrado en la respuesta, `Ctrl+T` (Windows/Linux) o `Cmd+T` (macOS), o `+` en el panel lateral > **Browser**. El usuario puede introducir una URL en la barra. Para `localhost` usar `http://localhost:PUERTO`, no asumir HTTPS.
2. **Antigravity App o CLI, con `/browser` habilitado:** para interacción automatizada con páginas, solicitar al subagente `/browser` una tarea concreta y un criterio de finalización. Este subagente usa Google Chrome y DevTools; **no es el mismo panel de navegador integrado**.
3. **Antigravity IDE clásico:** consultar sus controles y configuración de **Browser Tools** y aprovechar la integración de navegador que exponga. El comando `/browser` de la App/CLI **no está disponible** en el IDE. No afirmar que una skill pueda añadir a ese IDE la interfaz incrustada de la App.
4. **Sin navegador disponible:** comunicar la limitación verificable, proporcionar la URL exacta y los pasos para abrirla en el producto adecuado. No inventar botones, comandos, MCP ni herramientas.

## Procedimiento cuando el usuario pide «abre el navegador dentro de Antigravity»

1. Detectar una URL explícita del usuario o, para una app web local, identificar el puerto **real** de su servidor a partir de configuración, logs o proceso en ejecución. No inventar `3000` o `8080`.
2. Si hay servidor, arrancarlo solo con el comando que ya use el proyecto y comprobar que sirve la página. No instalar paquetes o cambiar configuración por intuición.
3. En la **Antigravity App**, proporcionar un enlace HTTP(S) clicable a la URL; pedir al usuario que haga clic **sin mantener Ctrl/Cmd** para abrirlo en el navegador lateral. También puede abrir `+ > Browser` o `Ctrl+T` y escribir la URL. No afirmar que ya apareció una pestaña sin evidencia.
4. Mantener el chat y el navegador visibles en paralelo. Para compartir contexto con el agente, el usuario puede seleccionar texto en el navegador y utilizar **Quote** (`Ctrl+L` en Windows/Linux) o **Comment**.
5. Si el usuario pide que **el agente navegue solo**, y está en App/CLI con `/browser` habilitado, sugerir o invocar el flujo oficial `/browser` indicando URL, acciones concretas y criterio de éxito. Aclarar que se abrirá/controlará Chrome mediante un contexto de navegador aparte, no necesariamente la pestaña integrada.
6. No abrir el navegador externo por defecto cuando el objetivo sea previsualizar en el panel integrado. Tampoco desactivar las protecciones del navegador para forzar acceso.

## Procedimiento para probar una interfaz web

- Abrir la página exacta y verificar que carga; registrar URL, estado y evidencia.
- Cuando se dispone de automatización del navegador, comprobar interacciones de forma real: clics, búsqueda, navegación, formularios, estados vacíos, errores de consola y peticiones de red.
- Para interfaces móviles **web**, probar un viewport de ~390 px de ancho si la herramienta permite redimensionarlo; no atribuir esto a una prueba nativa de Android.
- Revisar responsive, solapamientos, legibilidad, contraste, foco, navegación por teclado y estados de carga/error.
- Capturar pantallas o grabaciones solo cuando la herramienta realmente lo permita; enlazar resultados existentes, no inventar capturas.
- Diferenciar claramente: **cargó**, **interacción observada**, **solicitud enviada**, **respuesta del servidor**, **funcionalidad verificada**.
- Para Flutter Android nativo o Kotlin (sin build web), no fingir que una página localhost equivale a la app instalada: usar emulador/dispositivo y las herramientas específicas disponibles.

## Seguridad y límites

- No enviar formularios, borrar datos, comprar, publicar, desplegar ni cambiar cuentas sin autorización apropiada.
- No introducir contraseñas ni tokens en logs, capturas o prompts.
- No desactivar allowlists/denylists ni las opciones de aprobación del navegador.
- No depender de scripts externos para simular que se abrió un panel integrado.
- No instalar herramientas MCP para una función que el producto ya posee; considerar alternativas solo si el usuario las pide y existe una necesidad real.

## Formato de respuesta esperado

Informar siempre: superficie detectada (App, IDE, CLI o no verificada), URL real, cómo abrirla en la propia interfaz, qué se inspeccionó efectivamente, evidencia disponible y limitaciones restantes.

## Documentación oficial

- Navegador integrado de Antigravity App: https://antigravity.google/docs/features
- Comando `/browser` (App/CLI): https://antigravity.google/docs/commands/browser
- Navegador de Antigravity IDE: https://antigravity.google/docs/ide/browser
- Ubicaciones y formato de skills: https://antigravity.google/docs/skills
