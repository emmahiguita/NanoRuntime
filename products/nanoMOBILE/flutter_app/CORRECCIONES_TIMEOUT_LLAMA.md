# Correcciones Implementadas para Timeout del Motor Llama.cpp

## Problema Identificado
El motor nanortime (binario Llama.cpp) no respondía, causando timeout en el health check y sin emisión de tokens. El proceso se spawneaba correctamente pero el endpoint HTTP `/health` en `127.0.0.1:8080` no respondía dentro del tiempo permitido.

## Correcciones Implementadas

### 1. EngineSupervisor.kt - Diagnóstico y Logging Mejorado

#### Verificación de Puerto Disponible
- **Nuevo método `isPortAvailable(port: Int)`**: Verifica si el puerto está libre antes de intentar spawnear el proceso.
- **Beneficio**: Evita colisiones de puerto y proporciona diagnóstico temprano.

#### Lectura de Logs de Error del Proceso
- **Nuevo método `readEngineErrorLogs(pid: Int)`**: Lee logs de stderr del proceso nanortime desde el archivo temporal.
- **Beneficio**: Proporciona información diagnóstica sobre por qué el motor falla al iniciar.

#### Health Check Más Robusto
- **Mejora en `probeHealth()`**: 
  - Logging detallado de errores (ConnectException, SocketTimeoutException)
  - Verificación del formato de respuesta JSON
  - Timeout aumentado y mejorado manejo de excepciones
- **Beneficio**: Mejor diagnóstico de fallas de comunicación HTTP.

#### Configuración de Entorno Validada
- **Verificación de directorios**: Comprueba que `nativeLibDir` y `nanoUsrLib` existan antes de iniciar.
- **Creación automática de directorios**: Crea `tmp` y `home` si no existen.
- **Logging de rutas**: Registra las rutas utilizadas para diagnóstico.
- **Beneficio**: Evita fallos por rutas inexistentes.

#### Modo Fallback para Diagnóstico
- **Implementación de `startInternal()`**: Soporta modo fallback con bandera `fallbackMode`.
- **Argumento `--verbose`**: En modo fallback, usa `--verbose` en lugar de `--quiet` para más logging.
- **Reintento automático**: Si el health check falla, intenta en modo diagnóstico.
- **Beneficio**: Permite obtener más información cuando el modo normal falla.

### 2. LLMEngineClient.dart - Manejo de Timeouts Mejorado

#### Health Check Mejorado
- **Intentos aumentados**: De 3 a 5 intentos con backoff exponencial.
- **Timeout aumentado**: De 3 a 5 segundos por intento.
- **Validación de respuesta**: Verifica que el JSON contenga `"status":"ok"`.
- **Logging detallado**: Registra cada intento y el resultado.
- **Beneficio**: Más tolerancia a fallos transitorios durante el arranque.

#### Generate (Modo No-Stream)
- **Intentos aumentados**: De 2 a 3 intentos.
- **Backoff progresivo**: 1s, 2s entre reintentos (en lugar de 500ms).
- **Logging detallado**: Registra cada intento y resultados.
- **Manejo de excepciones**: Captura `FormatException` para errores de JSON.
- **Beneficio**: Mejor tolerancia a fallos de red y timeouts.

#### GenerateStream (Modo Streaming)
- **Protección contra controller cerrado**: Verifica `controller.isClosed` antes de agregar tokens.
- **Contador de tokens**: Registra progreso cada 10 tokens.
- **Logging mejorado**: Registra establecimiento de conexión, progreso y limpieza.
- **Manejo de excepciones**: Logging detallado de errores y timeouts.
- **Limpieza de recursos**: Asegura que el controller se cierre solo si no está cerrado.
- **Beneficio**: Mejor estabilidad en streaming y diagnóstico de problemas.

#### Timeout Global Aumentado
- **De 60 a 120 segundos**: Da más tiempo al motor para generar respuestas largas.
- **Beneficio**: Evita timeouts prematuros en inferencias complejas.

## Beneficios de las Correcciones

1. **Diagnóstico Mejorado**: Los logs ahora proporcionan información detallada sobre:
   - Estado de puertos
   - Existencia de directorios y librerías
   - Errores específicos del proceso nanortime
   - Progreso de health checks y conexiones

2. **Tolerancia a Fallos**: 
   - Más reintentos con backoff progresivo
   - Timeouts más realistas
   - Modo fallback para diagnóstico

3. **Estabilidad**:
   - Verificación de precondiciones antes de iniciar
   - Protección contra recursos ya cerrados
   - Limpieza adecuada de recursos

4. **Mantenibilidad**:
   - Logging estructurado y consistente
   - Métodos reutilizables para diagnóstico
   - Separación clara entre modo normal y diagnóstico

## Pruebas Recomendadas

1. **Arranque del motor**: Verificar que el motor inicie correctamente y responda a health checks.
2. **Inferencia simple**: Probar generación de texto corto.
3. **Inferencia larga**: Probar generación de texto largo para verificar el timeout aumentado.
4. **Streaming**: Verificar que el streaming funcione correctamente con los nuevos guards.
5. **Modo fallback**: Simular fallos para verificar que el modo diagnóstico proporcione información útil.

## Archivos Modificados

1. `android/app/src/main/kotlin/dev/nanoai/mobile/EngineSupervisor.kt`
2. `lib/core/services/llm_engine_client.dart`

## Próximos Pasos Sugeridos

1. **Monitoreo en producción**: Revisar los logs mejorados para identificar patrones de fallo.
2. **Ajuste de timeouts**: Basado en datos reales, ajustar los timeouts para optimizar la experiencia.
3. **Modelos de prueba**: Implementar modelos de prueba específicos para diagnóstico automatizado.
4. **Alertas tempranas**: Implementar alertas basadas en los nuevos logs para problemas recurrentes.