// personal_intent.dart
//
// QUÉ HACE: define las intenciones semánticas del Agente Personal de Nano.
// CÓMO: enum exhaustivo que clasifica si la consulta es social, temporal, tareas del usuario o tareas de Nano.
// POR QUÉ: evita que el LLM invente respuestas o sufra alucinaciones para datos deterministas del dispositivo.

enum PersonalIntent {
  social,
  currentTime,
  currentDate,
  userDailyPlan,
  userPendingTasks,
  nanoDailyPlan,
  nanoPendingTasks,
  calendarToday,
  conversationPending,
  generalConversation,
}
