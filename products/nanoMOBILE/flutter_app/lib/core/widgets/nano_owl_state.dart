// nano_owl_state.dart — Estados y cuadros secuenciales del Búho Nano.
// QUÉ: Enum semántico de 10 estados y definición de secuencias multi-frame (sprites).
// CÓMO: Listas inmutables de paths a los frames reales en assets/owl/.
// POR QUÉ: Elimina animaciones "trucadas" (escalado estático), habilitando
//          reproducción cuadro a cuadro real para sueño, vuelo y parpadeo biológico.

/// 10 Estados semánticos de la mascota Nano Owl.
enum NanoOwlState {
  /// 1. IDLE: Calma con parpadeo y micro-respiración.
  idle,
  /// 2. PARPADEO: Secuencia biológica multi-frame de 5 cuadros.
  blink,
  /// 3. ESCUCHANDO: Aura cian pulsante y atención activa.
  listening,
  /// 4. PENSANDO: Resplandor cósmico orbital.
  thinking,
  /// 5. RESPONDIENDO: Proyección holográfica activa.
  responding,
  /// 6. ÉXITO: Confirmación alegre con destellos.
  success,
  /// 7. ERROR: Postura inquisitiva con inclinación.
  error,
  /// 8. DORMIDO: Animación real multi-frame (6 cuadros) de respiración profunda.
  sleep,
  /// 9. DESPERTAR: Guiño y reactivación.
  wake,
  /// 10. VOLANDO: Animación real multi-frame (7 cuadros) de aleteo fluido continuo.
  fly,
}

/// Rutas canónicas a los cuadros de animación del búho.
class NanoOwlFrames {
  const NanoOwlFrames._();

  // Poses estáticas individuales
  static const String idle = 'assets/owl/states/owl_idle.png';
  static const String listening = 'assets/owl/states/owl_listening.png';
  static const String thinking = 'assets/owl/states/owl_thinking.png';
  static const String responding = 'assets/owl/states/owl_responding.png';
  static const String success = 'assets/owl/states/owl_success.png';
  static const String error = 'assets/owl/states/owl_error.png';
  static const String wake = 'assets/owl/states/owl_wake.png';
  static const String welcome = 'assets/owl/welcome.png';
  static const String drowsy = 'assets/owl/drowsy.png';

  // Secuencia de sueño real: 6 cuadros de respiración plácida
  static const List<String> sleepFrames = [
    'assets/owl/sleep/owl_sleep_01.png',
    'assets/owl/sleep/owl_sleep_02.png',
    'assets/owl/sleep/owl_sleep_03.png',
    'assets/owl/sleep/owl_sleep_04.png',
    'assets/owl/sleep/owl_sleep_05.png',
    'assets/owl/sleep/owl_sleep_06.png',
  ];

  // Secuencia de vuelo real: 7 cuadros de aleteo rítmico
  static const List<String> flyFrames = [
    'assets/owl/fly/owl_fly_01.png',
    'assets/owl/fly/owl_fly_02.png',
    'assets/owl/fly/owl_fly_03.png',
    'assets/owl/fly/owl_fly_04.png',
    'assets/owl/fly/owl_fly_05.png',
    'assets/owl/fly/owl_fly_06.png',
    'assets/owl/fly/owl_fly_07.png',
  ];

  // Secuencia de parpadeo biológico: 5 cuadros fisiológicos
  static const List<String> blinkFrames = [
    'assets/owl/blink/owl_blink_01.png',
    'assets/owl/blink/owl_blink_02.png',
    'assets/owl/blink/owl_blink_03.png',
    'assets/owl/blink/owl_blink_04.png',
    'assets/owl/blink/owl_blink_05.png',
  ];

  // Secuencia de despegue
  static const List<String> takeoffFrames = [
    'assets/owl/takeoff/owl_takeoff_01.png',
    'assets/owl/takeoff/owl_takeoff_02.png',
  ];

  /// Colección completa para pre-carga en GPU y evitar parpadeos blancos.
  static const List<String> allPrecacheAssets = [
    idle, listening, thinking, responding, success, error, wake, welcome, drowsy,
    ...sleepFrames,
    ...flyFrames,
    ...blinkFrames,
    ...takeoffFrames,
  ];
}
