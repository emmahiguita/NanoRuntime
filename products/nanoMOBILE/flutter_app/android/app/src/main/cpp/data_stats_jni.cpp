/*
 * QUÉ: calcula estadísticas descriptivas reales para Data Studio.
 * CÓMO: recibe double[] por JNI y usa Welford para media/desviación estable.
 * POR QUÉ: mantiene el cálculo pesado fuera del hilo Dart sin añadir un SDK JVM.
 */
#include <jni.h>
#include <cmath>
#include <limits>

extern "C" JNIEXPORT jdoubleArray JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_dataStatistics(
    JNIEnv* env, jclass, jdoubleArray input) {
  if (input == nullptr) return nullptr;
  const jsize length = env->GetArrayLength(input);
  jdouble* values = env->GetDoubleArrayElements(input, nullptr);
  if (values == nullptr) return nullptr;

  double count = 0.0;
  double sum = 0.0;
  double mean = 0.0;
  double m2 = 0.0;
  double minimum = std::numeric_limits<double>::infinity();
  double maximum = -std::numeric_limits<double>::infinity();

  for (jsize i = 0; i < length; ++i) {
    const double value = values[i];
    if (!std::isfinite(value)) continue;
    count += 1.0;
    sum += value;
    if (value < minimum) minimum = value;
    if (value > maximum) maximum = value;
    const double delta = value - mean;
    mean += delta / count;
    m2 += delta * (value - mean);
  }
  env->ReleaseDoubleArrayElements(input, values, JNI_ABORT);

  if (count == 0.0) minimum = maximum = mean = 0.0;
  const double deviation = count > 1.0 ? std::sqrt(m2 / (count - 1.0)) : 0.0;
  const jdouble output[6] = {count, sum, minimum, maximum, mean, deviation};
  jdoubleArray result = env->NewDoubleArray(6);
  if (result != nullptr) env->SetDoubleArrayRegion(result, 0, 6, output);
  return result;
}
