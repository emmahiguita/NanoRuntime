# NanoAI ProGuard/R8 Rules
# Keep JNI native methods â€” they're looked up by name at runtime.
# Without these rules, R8 may strip or rename native method declarations,
# causing UnsatisfiedLinkError at runtime.

# â”€â”€ NanoshellBridge JNI â”€â”€
-keep class dev.nanoai.mobile.NanoshellBridge {
    native <methods>;
    <init>();
}

# â”€â”€ Flutter Engine â”€â”€
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# â”€â”€ Kotlin coroutines (kept for reflection-based dispatch) â”€â”€
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# â”€â”€ Keep native library loading â”€â”€
-keepclasseswithmembernames class * {
    native <methods>;
}

# â”€â”€ General Android â”€â”€
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
# Flutter deferred components reference Play Core classes that are optional for
# a standalone APK. The app does not declare deferred components, so suppress
# R8 missing-class warnings instead of adding unused Play Store runtime code.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# A14.3: Shizuku API binding (dev.rikka.shizuku:api). El cliente Shizuku se
# vincula al servicio de sistema via reflection (IShizukuService). Sin estas
# reglas R8 puede eliminar/renombrar las clases del binding y romper
# pingBinder()/checkSelfPermission() (disponibilidad factual) en runtime.
-keep class rikka.shizuku.** { *; }
-dontwarn rikka.shizuku.**

# A14.3: ShizukuProvider se referencia SOLO por nombre en el AndroidManifest
# (no hay código que lo instancie). R8 lo elimina si no se mantiene
# explícitamente -> ClassNotFoundException en el arranque al instanciar el
# provider. Los providers declarados en manifest SE INSTANCIAN POR REFLECTION;
# el veredicto "código no usado" no aplica. Esta regla es la recomendada para
# ContentProviders en manifest y cubre ShizukuProvider (extends ContentProvider).
-keep public class * extends android.content.ContentProvider
# A14.4: UserService / AIDL de Shizuku. El servicio se invoca por nombre desde
# el manifesto/USER_SERVICE y el Stub por Binder: R8 no debe renombrarlos.
-keep class dev.nanoai.mobile.shizuku.** { *; }
-keepnames class * implements dev.nanoai.mobile.shizuku.IPackageAction
