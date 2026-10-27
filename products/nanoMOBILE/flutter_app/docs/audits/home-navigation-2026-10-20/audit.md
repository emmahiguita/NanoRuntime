# Cabecera de Inicio y navegación compacta

## Evidencia inicial

Inspección de la pantalla real de Nano en OPPO CPH2557, orientación horizontal,
y trazado de los callbacks de `AgentHeaderWidget` y del propietario del dock.
Captura anterior: `before-landscape.jpg`.

Hallazgos confirmados:

1. La marca usaba `auto_mode_rounded`: parecía otro control pero era decorativa.
2. La conversación de voz usaba un bocadillo con cámara, aunque no iniciaba vídeo.
3. El robot abría herramientas técnicas: su significado visual era ambiguo.
4. Un `Center` dentro del selector de autonomía lo estiraba al ancho disponible.
5. La navegación tenía 22 px de tirador, 60 px de destinos y 6 px de carcasa:
   aproximadamente 88 px lógicos antes de márgenes. El parámetro compacto del
   destino no reducía su geometría.
6. Al contraerse quedaban tres puntos sin nombre ni señal del destino actual.
7. El temporizador empezaba al presionar, por lo que podía contraer controles
   mientras el usuario mantenía el dedo.

## Conexión real de los controles

| Control | Conexión conservada | Corrección visual |
| --- | --- | --- |
| Nivel de autonomía | Diálogo de selección y SettingsNotifier | Selector compacto con flecha |
| Salida de voz | AutomationVoiceHandler y ajuste voiceEnabled | Glifo Nano de voz y estado de silencio |
| Conversación | AutomationVoiceController.activateConversation | Micrófono y texto iniciar/detener |
| Herramientas | AutomationScreen._openDev | Símbolo propio de herramientas/código |
| Marca | Sin callback; identidad decorativa | Búho Nano existente, semántica de imagen |

No se encontraron callbacks vacíos en estos tres botones. La auditoría no
certifica reconocimiento de voz, inferencia ni envío de mensajes: se revisa su
conexión y presentación, sin ejecutar órdenes sobre otras aplicaciones.

## Correcciones

- Cabecera dividida en identidad y botones con responsabilidades separadas.
- Iconos propios reutilizados; sin generar otra familia visual ni añadir acciones.
- Se eliminan tres desenfoques individuales de los botones de cabecera.
- Selector de autonomía con ancho intrínseco; no cambia políticas ni modo guardado.
- Navegación abierta de 272 px de ancho y una sola fila de aproximadamente 54 px
  de alto con texto estándar; conserva los cuatro destinos y la entrada contextual.
- En paneles estrechos el acceso a escritura pasa debajo para no comprimir destinos.
- Estado reducido: icono, nombre del destino y flecha; altura visual mínima de 36 px
  con área táctil de 48 px. Mismo componente en el lateral y en el centro.
- Contracción automática tras cinco segundos; no cierra el editor al escribir.
- El temporizador se suspende al mantener el dedo y se rearma al soltar.
- Transiciones acotadas, colores del tema y respeto por reducir movimiento.
- Voz/conversación animan escala, opacidad y cambio de símbolo durante 180 ms,
  siguiendo sus booleanos reales. No se simula reproducción con pulsos perpetuos.
- Los controles salientes del AnimatedSwitcher quedan sin puntero ni semántica
  mientras se desvanecen; no siguen recibiendo toques como componentes ocultos.
- Se mantiene la jerarquía Column → Row → Expanded del editor al abrir el teclado.

## Límites y verificación

Los once archivos Dart modificados tienen comentarios y menos de 200 líneas.
Formato y análisis estático enfocado completados sin incidencias.
No se escriben ni ejecutan pruebas automatizadas.
Las comprobaciones posteriores de compilación, instalación y observación manual
se registran en `validation.md`.
