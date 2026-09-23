/**
 * @file owl_config.js
 * @description Configuración centralizada de assets, físicas y tiempos del avatar de Nano AI.
 * 
 * Qué hace: Define rutas reales de assets, constantes físicas y temporizadores del búho.
 * Cómo funciona: Exporta constantes inmutables consumidas por la máquina de estados y el motor de físicas.
 * Por qué: Desacopla la configuración de la lógica (Principio Abierto/Cerrado de SOLID).
 */

export const OWL_ASSETS = Object.freeze({
  // Reposo neutral (pie firme, ojos galaxia abiertos)
  idle: 'assets/Animaciones/saludando/96e4a721-fac9-4158-be23-5ec04c2f10c8.png',
  
  // Parpadeo natural (ojos cerrados alineados pixel a pixel)
  blink: 'assets/Animaciones/dormido/owl_blink.png',
  
  // Saludo amigable (ala derecha alzada, expresión alegre)
  wave: 'assets/Animaciones/saludando/ChatGPT Image 21 sept 2026, 05_25_11 p.m..png',
  
  // Curiosidad (ladeo de cabeza atento)
  curious: 'assets/Animaciones/saludando/ChatGPT Image 21 sept 2026, 05_25_07 p.m..png',
  
  // Vuelo / Planeo frontal majestuoso
  flying: 'assets/Animaciones/BUHO VUELO FRONTAL/ChatGPT Image 30 ago 2026, 03_35_11 p.m. (2) (1).png',
  
  // Dormido pacífico (con zzz cósmicas en pose acurrucada)
  sleep: 'assets/Animaciones/dormido/owl_sleep.png',
  
  // Escuchando / Escribiendo en el composer
  listening: 'assets/Animaciones/Pregunta y cuando da respuesta/ChatGPT Image 21 sept 2026, 05_24_54 p.m..png',
  
  // Pensando / Razonando (DeepThink R1 con interrogación estelar)
  thinking: 'assets/Animaciones/Pregunta y cuando da respuesta/ChatGPT Image 21 sept 2026, 05_25_19 p.m..png',
  
  // Respondiendo / Generación en tiempo real
  responding: 'assets/Animaciones/Pregunta y cuando da respuesta/ChatGPT Image 21 sept 2026, 05_25_25 p.m..png',
  
  // Éxito / Tarea finalizada con destellos
  success: 'assets/Animaciones/Pregunta y cuando da respuesta/ChatGPT Image 21 sept 2026, 05_25_26p.m..png',
});

export const OWL_PHYSICS_CONFIG = Object.freeze({
  springK: 28,          // Rigidez del resorte angular
  damper: 7.5,          // Amortiguación de oscilación
  mouseLerp: 0.075,     // Factor de interpolación del ratón
  maxYaw: 14,           // Grados máx. de rotación horizontal (Y)
  maxPitch: 8,          // Grados máx. de rotación vertical (X)
  breathSpeed: 1.6,     // Frecuencia respiratoria en reposo (Hz)
  breathAmp: 0.024,     // Amplitud de squash & stretch respiratorio
  sleepBreathSpeed: 0.85, // Respiración lenta en sueño profundo
  sleepBreathAmp: 0.038,
});

export const OWL_TIMERS_CONFIG = Object.freeze({
  sleepInactivityMs: 120000, // 2 minutos para reposo automático
  waveDurationMs: 3000,      // Duración del gesto de saludo
  curiousDurationMs: 2500,   // Duración de la mirada curiosa
  blinkMinMs: 3500,          // Intervalo mínimo entre parpadeos
  blinkMaxMs: 7000,          // Intervalo máximo entre parpadeos
  blinkDurationMs: 150,      // Duración del cierre palpebral
});
