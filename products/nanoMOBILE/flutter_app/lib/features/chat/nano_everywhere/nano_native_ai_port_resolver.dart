import 'dart:io';
import 'nano_ai_models.dart';
import 'nano_android_native_ai_port.dart';
import 'nano_ios_native_ai_port.dart';

/// Fábrica para resolver la implementación de [NanoNativeAiPort] según la plataforma.
///
/// QUÉ HACE: Aísla la selección de puertos de IA nativos desacoplando la UI.
/// CÓMO SE CONECTA: Evalúa `Platform.isIOS` e inyecta la implementación respectiva.
/// POR QUÉ: Evita comprobaciones de plataforma dispersas y acoplamiento directo a Android.
abstract final class NanoNativeAiPortResolver {
  /// Devuelve el puerto nativo correspondiente a la plataforma en ejecución.
  static NanoNativeAiPort create() {
    if (Platform.isIOS) {
      return const NanoIosNativeAiPort();
    }
    return const NanoAndroidNativeAiPort();
  }
}
