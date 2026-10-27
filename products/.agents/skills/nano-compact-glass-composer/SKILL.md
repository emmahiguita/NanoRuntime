---
name: nano-compact-glass-composer
description: "Preserve or reuse Nano's approved compact glass composer: anchored plus menu, attachments, component selection and contextual tool actions. Use when designing or correcting this composer or adapting the same pattern to another Nano screen."
---

# Nano: compositor compacto de cristal

Diseño aprobado por el usuario el 26 de octubre de 2026. Reutiliza este patrón
al trabajar sobre la barra de escritura y sus menús. Mantén el diseño existente
fuera de ese alcance; la skill no autoriza funciones, pruebas ni acciones nuevas.

## Jerarquía del diseño

```text
Barra: + · componente activo, si existe · editor · voz/enviar/detener

+
├─ Cámara
├─ Fotos
├─ Archivos
└─ Complementos → WhatsApp

Icono WhatsApp activo → funciones existentes del componente
```

- El + siempre abre adjuntos y Complementos, incluso con una herramienta activa.
- WhatsApp es una opción dentro de Complementos, no el contenido principal del +.
- Seleccionar WhatsApp activa su contexto y muestra su icono en el editor.
  Volver a seleccionarlo en Complementos lo desactiva y retira el icono.
  Ninguna de esas selecciones abre apps, busca contactos ni envía mensajes.
- El icono del componente abre sus funciones. Conserva separados `onAdd` y
  `onOptions`; no dupliques los proveedores de adjuntos dentro de esas funciones.
- El catálogo actual solo contiene WhatsApp. Muestra otras integraciones solo
  cuando formen parte del encargo y tengan una conexión real implementada.
- El historial permanece fuera de la barra. No añadas otro editor o tarjetas
  de instrucciones para duplicar lo que ya se puede escribir.

## Material y métricas aprobadas

| Elemento | Regla del patrón |
| --- | --- |
| Superficie | Una sola GlassSurface, translúcida y con texto opaco. |
| Presentación | Menú anclado al botón; submenú dentro de la misma ruta. |
| Ancho | Máximo 280 dp, limitado al espacio disponible. |
| Filas | Objetivo táctil mínimo de 48 dp; altura ampliable por el texto. |
| Iconos del menú | 18 dp, uno por función; logo WhatsApp de 20 dp. |
| Iconos del editor | Mantener las métricas existentes de la barra. |
| Tipografía | bodyMedium del tema; títulos cortos, legibles y sin recorte forzado. |
| Color | Paleta del tema; sin textos multicolores ni estados decorativos falsos. |
| Formulario | Campo denso y acción compacta alineada al final. |

No imites el cristal con otra placa opaca ni superpongas marcos, sombras o
cierres. Conserva un único regreso en el submenú. Respeta área segura, teclado,
escala tipográfica y espacio real también en horizontal; usa scroll cuando el
contenido no quepa. No reduzcas el área táctil para conseguir un aspecto pequeño.

## Movimiento y ciclo de vida

- Reutiliza `showNanoAnchoredPopover`: entrada finita de 190 ms y adaptación de
  tamaño de 180 ms. Mantén la respuesta breve sin añadir animaciones repetitivas.
- Respeta `disableAnimations` con duración cero. No crees timers o relojes
  ambientales para un menú. Cuando haya vistas salientes, desactiva sus gestos
  y semántica durante la transición.
- Una apertura tiene un único propietario; bloquea doble apertura y doble cierre.
  Libera formularios y bloqueos al cancelar, fallar o desmontar.
- `Semantics(scopesRoute: true)` requiere `explicitChildNodes: true`; conserva
  el nombre accesible. Omitirlo impedía montar este menú.

## Interacción real y adjuntos

- Cámara, Fotos y Archivos invocan sus proveedores nativos existentes. Elegir un
  archivo lo prepara en el editor; no selecciona WhatsApp automáticamente.
- Muestra el nombre del adjunto y una acción para quitarlo, nunca su ruta privada.
  Cancelar el selector conserva la selección anterior.
- Quitar o reemplazar el archivo revoca el borrador generado con su ruta; utiliza
  la misma normalización que Ejecutar. No dejes una referencia que pueda enviarlo
  después de retirarlo de la interfaz.
- El destino se conserva literalmente. En formularios usa identidad delimitada
  con JSON antes del parser libre para nombres con dos puntos o paréntesis.
- Preparar no ejecuta. Reutiliza el coordinador, permisos, confirmaciones y
  verificación de destinatario. No ignores un adjunto al enviar solo texto.
- Enviar adjunto solo aparece entre las funciones WhatsApp cuando hay uno
  preparado. No expongas capacidades QA o multimodales por inferirlas del diseño.

## Aplicación y revisión

1. Localiza los consumidores reales antes de editar. Reutiliza los componentes
   compartidos y conserva sus callbacks; no copies el compositor a otro árbol.
2. Aplica el cambio mínimo. Mantén archivos modificados menores de 200 líneas,
   con comentarios encima de funciones y componentes sobre responsabilidad y límites.
3. Revisa jerarquía, acciones conectadas, foco, cancelación y contraste. Comprueba
   formato y análisis estático según el alcance autorizado.
4. Respeta las restricciones del usuario sobre pruebas y teléfono. Separar en la
   entrega lo editado, compilado, instalado y observado evita inventar cobertura.

## Implementación de referencia

Las rutas siguientes parten de esta carpeta. Lee solo la responsabilidad afectada:

- [Presentador de cristal y posición](../../../nanoMOBILE/flutter_app/lib/core/widgets/nano_anchored_popover.dart).
- [Menú + y Complementos](../../../nanoMOBILE/flutter_app/lib/features/automation/presentation/widgets/automation_input_menu.dart).
- [Conexión con el editor](../../../nanoMOBILE/flutter_app/lib/features/automation/presentation/widgets/automation_dashboard_input.dart).
- [Acciones de WhatsApp](../../../nanoMOBILE/flutter_app/lib/features/automation/presentation/widgets/whatsapp_automation_menu.dart).
- [Diseño, límites y archivos](../../../nanoMOBILE/flutter_app/docs/audits/automation-whatsapp-popover/COMPOSER_HIERARCHY.md).

Para corregir temas o el motor de cristal compartido, complementa este patrón
con `nano-glass-floating-windows`; no dupliques allí sus reglas de transparencia.
