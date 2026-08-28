/// Trigger (T3) — condición tipada que dispara una automatización persistente.
///
/// Puro, determinista, sin IO: la evaluación es una función pura del evento.
/// Esto es el modelo de triggers de "automatización persistente" (T3), NO la
/// ejecución interactiva de T2. El scheduler nativo (WorkManager/AlarmManager/
/// boot restore) consume este modelo; aquí solo vive la semántica.
library;

/// Condición de disparo. Sealed: el evaluador decide por tipo, sin strings.
sealed class Trigger {
  const Trigger();
}

/// Disparo por hora: "todos los días a las 8" / "a las 8:30 los lunes".
class TimeTrigger extends Trigger {
  /// 0-23.
  final int hour;

  /// 0-59.
  final int minute;

  /// 1=lun .. 7=dom. Vacío = todos los días.
  final Set<int> weekdays;

  const TimeTrigger({
    required this.hour,
    required this.minute,
    this.weekdays = const {},
  });
}

/// Disparo por notificación entrante: "cuando Juan me escriba".
class NotificationTrigger extends Trigger {
  /// null = cualquier paquete.
  final String? packageName;

  /// Substring en sender/conversationTitle. null = cualquiera.
  final String? senderMatch;

  const NotificationTrigger({this.packageName, this.senderMatch});
}

/// Disparo por conectividad: "cuando tenga wifi".
class ConnectivityTrigger extends Trigger {
  final bool wifiOnly;
  const ConnectivityTrigger({this.wifiOnly = false});
}

/// Disparo por nivel de batería: "cuando la batería baje de X%".
class BatteryTrigger extends Trigger {
  final int belowPercent;
  const BatteryTrigger(this.belowPercent);
}

/// Evento observado contra el que se evalúa un [Trigger]. Sealed por tipo.
sealed class TriggerEvent {
  const TriggerEvent();
}

/// Tick de reloj (scheduler periódico).
class TickEvent extends TriggerEvent {
  final DateTime now;
  const TickEvent(this.now);
}

/// Llegada de una notificación (listener).
class NotificationEvent extends TriggerEvent {
  final String? packageName;
  final String? sender;
  final String? conversationTitle;
  const NotificationEvent({
    this.packageName,
    this.sender,
    this.conversationTitle,
  });
}

/// Cambio de conectividad.
class ConnectivityEvent extends TriggerEvent {
  final bool wifiConnected;
  const ConnectivityEvent({required this.wifiConnected});
}

/// Cambio de nivel de batería.
class BatteryEvent extends TriggerEvent {
  final int percent;
  const BatteryEvent({required this.percent});
}

/// Función PURA: ¿este trigger dispara con este evento?
/// false = el evento no es aplicable a este trigger o no cumple la condición.
bool evaluateTrigger(Trigger trigger, TriggerEvent event) {
  if (trigger is TimeTrigger && event is TickEvent) {
    return event.now.hour == trigger.hour &&
        event.now.minute == trigger.minute &&
        (trigger.weekdays.isEmpty ||
            trigger.weekdays.contains(event.now.weekday));
  }
  if (trigger is NotificationTrigger && event is NotificationEvent) {
    final pkgOk =
        trigger.packageName == null || trigger.packageName == event.packageName;
    final match = trigger.senderMatch;
    final senderOk = match == null ||
        match.isEmpty ||
        '${event.sender ?? ''} ${event.conversationTitle ?? ''}'
            .toLowerCase()
            .contains(match.toLowerCase());
    return pkgOk && senderOk;
  }
  if (trigger is ConnectivityTrigger && event is ConnectivityEvent) {
    return !trigger.wifiOnly || event.wifiConnected;
  }
  if (trigger is BatteryTrigger && event is BatteryEvent) {
    return event.percent < trigger.belowPercent;
  }
  return false;
}

/// Regla persistente: un [Trigger] + el objetivo de automatización a ejecutar.
class ScheduledRule {
  final String id;
  final Trigger trigger;
  final String goal;
  final bool enabled;

  const ScheduledRule({
    required this.id,
    required this.trigger,
    required this.goal,
    this.enabled = true,
  });

  ScheduledRule copyWith({bool? enabled}) => ScheduledRule(
    id: id,
    trigger: trigger,
    goal: goal,
    enabled: enabled ?? this.enabled,
  );
}
