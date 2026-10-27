---
name: nano-message-center-pdf-library
description: Maintain Nano Mobile's real PDF library and its access from the Message Center; use when reviewing document folders, previews, sharing, or conversation-center integration.
---

# Nano Message Center PDF Library

Keep PDF discovery, preview, and sharing grounded in real files already available to the app.

- Discover Flutter and native channel code through `codebase-memory-mcp` first, following the repository `AGENTS.md` instructions.
- Preserve the private app document store. Explain that imported/generated files are app-local; do not imply that Nano indexes public storage or WhatsApp's private files.
- Keep folder filters backed by the library's real directory list. “Todas” should aggregate those directories and retain each document's actual category.
- Render the first page from the selected PDF bytes with the PDF package already in the app. Cache thumbnails with a bounded cache and a key that changes when the file changes. Keep a readable file row when rendering fails.
- Route document taps to the existing in-app PDF reader. Keep a direct, accessible entry from the Message Center and preserve the older library entry if it is still used.
- Share a real file URI through Android's share sheet. The user still chooses the target app and recipient; do not claim silent WhatsApp delivery or bulk sending unless a verified integration provides it.
- Keep search claims precise: filename and folder search are not semantic PDF text search or model RAG. Only claim those capabilities when a real index, extraction flow, and model integration exist.
- Surface storage and channel failures in the owning view with a retry action; never print raw exception text or device paths as product copy.
- Check channel method names and registration on every Flutter engine that uses the channel. Separate a confirmed UI-engine registration from a headless-service registration and inspect recent device logs when a `MissingPluginException` appears.
- La biblioteca debe heredar ColorScheme y los ajustes de GlassSurface; no fijar isDark: true, fondos azul oscuro ni texto blanco. Si conserva su propia cabecera y superficie, abrir con NanoWindowChrome.contentOwned para evitar otro marco y otra X. Los menús de archivos, carpetas, orden y filtros deben ser flotantes y actuar solo tras elegir una opción.
- Keep implementation focused, comment component and operation entry points in Spanish, and split files when a touched source file exceeds the repository's requested 200-line limit.
- Follow the user's manual-verification preference: use formatting, static analysis, build, and installation checks; do not add or run automated tests unless the user changes that instruction.

## Entradas compartidas comprobadas (18 de octubre de 2026)

- Inicio y Nano Personal usan `NanoWorkspaceResources`: abre el mismo `BusinessDocumentLibraryDialog`, espera `BusinessFactsNotifier.ready` y acota aperturas simultáneas. No crear otra biblioteca o catálogo por pantalla.
- Para abrir Tienda directamente, pasar `initialSection: BusinessLibrarySection.store`; documentos conserva el valor predeterminado. No confundir cambiar una etiqueta con seleccionar la sección real.
- Un error de carga de archivos corresponde solo a Documentos: no debe ocultar Tienda, cuyo catálogo usa otra fuente.
- Regla habilitada no demuestra permisos ni entrega. No usar estados activos fijos, canales publicitarios o contenido multimedia de muestra como evidencia de conexión.
- Abrir una biblioteca no adjunta sus archivos al contexto de todos los contactos. Conserva selección explícita y la verificación de destinatario del Centro de Mensajes.

## Presentación verificable de Tienda

- Mantener foto, precio, nombre e inventario originales. No completar productos con imágenes, reseñas ni promociones de muestra al corregir diseño.
- Compartir una sola interpretación de disponibilidad entre tarjeta, lista y ficha: stock nulo exige consultar; cero indica agotado; uno usa singular; desactivado indica pausado.
- No deducir vídeo por palabras en la ruta ni atribuir resolución 4K sin metadatos. Mostrar errores de imagen y medios ausentes de forma honesta.
- Calcular columnas y altura de tarjetas con ancho y escala tipográfica reales. Conservar áreas táctiles de al menos 44 px y acciones existentes.
- Ficha propia con GlassSurface y cierre único debe usar contentOwned. Evitar crear otro marco o duplicar operaciones al mostrar menús.
- Evidencia de esta corrección: nanoMOBILE/flutter_app/docs/audits/store-presentation-2026-10-25/.
