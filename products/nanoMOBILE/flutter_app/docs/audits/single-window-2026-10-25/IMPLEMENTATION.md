# Un solo marco para la conversación flotante

La captura del usuario mostraba dos botones X y dos superficies: el presentador general añadía su marco y cierre encima del panel de conversación, que conservaba el antiguo fondo y cabecera de una hoja inferior.

Se definió explícitamente quién posee la presentación. NanoWindowChrome.managed mantiene el comportamiento de los selectores simples. ConversationDetailSheet declara contentOwned: el presentador conserva ruta, barrera, área segura y espacio del teclado, pero no dibuja otro marco ni cierre. El chat usa una única GlassSurface y conserva la X de su cabecera, etiquetada «Cerrar conversación».

Se retiraron el fondo propio del antiguo panel, sus bordes/sombras, su desenfoque completo duplicado y el relleno redundante para el teclado. El historial, la asignación Bot/Humano, el compositor y el ciclo de vida de los controladores no cambian. La cabecera y la barra Bot/Humano se separaron en archivos de responsabilidad propia, todos por debajo de 200 líneas.

Análisis estático focalizado sin incidencias. No se escribieron ni ejecutaron tests automáticos. La comparación visual inicial se basó en la captura aportada; no se navegó por conversaciones del teléfono para comprobar el cambio.

Compilación fullSideloadDebug satisfactoria e instalación confirmada con Success, conservando datos. La huella del APK instalado está en delivery-receipt.json.
