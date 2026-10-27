import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/personal_agent/application/personal_intent_router.dart';
import 'package:nanoai/features/automation/personal_agent/domain/personal_intent.dart';

void main() {
  group('PersonalIntentRouter Tests', () {
    test('Identifica preguntas de hora deterministas', () {
      expect(PersonalIntentRouter.route('¿Qué hora es?'), PersonalIntent.currentTime);
      expect(PersonalIntentRouter.route('que hora es'), PersonalIntent.currentTime);
      expect(PersonalIntentRouter.route('hora?'), PersonalIntent.currentTime);
      expect(PersonalIntentRouter.route('dime la hora'), PersonalIntent.currentTime);
      expect(PersonalIntentRouter.route('¿Qué horas son?'), PersonalIntent.currentTime);
    });

    test('Identifica preguntas de fecha deterministas', () {
      expect(PersonalIntentRouter.route('¿Qué fecha es hoy?'), PersonalIntent.currentDate);
      expect(PersonalIntentRouter.route('hoy que dia es'), PersonalIntent.currentDate);
      expect(PersonalIntentRouter.route('en que fecha estamos'), PersonalIntent.currentDate);
    });

    test('Identifica tareas y rol de Nano', () {
      expect(PersonalIntentRouter.route('¿Qué harás hoy?'), PersonalIntent.nanoDailyPlan);
      expect(PersonalIntentRouter.route('que vas a hacer hoy'), PersonalIntent.nanoDailyPlan);
      expect(PersonalIntentRouter.route('Tú eres quien va a estar atento'), PersonalIntent.nanoDailyPlan);
      expect(PersonalIntentRouter.route('quien va a estar atento con las conversaciones'), PersonalIntent.nanoDailyPlan);
    });

    test('Identifica tareas y planes del usuario', () {
      expect(PersonalIntentRouter.route('¿Qué tengo que hacer hoy?'), PersonalIntent.userDailyPlan);
      expect(PersonalIntentRouter.route('que tengo pendiente'), PersonalIntent.userDailyPlan);
      expect(PersonalIntentRouter.route('cuales son mis tareas'), PersonalIntent.userDailyPlan);
      expect(PersonalIntentRouter.route('que falta por hacer'), PersonalIntent.userDailyPlan);
    });

    test('Identifica saludos sociales simples', () {
      expect(PersonalIntentRouter.route('Hola'), PersonalIntent.social);
      expect(PersonalIntentRouter.route('Holaa'), PersonalIntent.social);
      expect(PersonalIntentRouter.route('buenos dias'), PersonalIntent.social);
    });
  });
}
