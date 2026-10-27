package dev.nanoai.mobile

import android.content.Context
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * QUÉ: reserva el motor compartido de UI/audio sin ejecutar Dart prematuramente.
 * CÓMO: publica primero el motor sin plugins y luego registra los plugins al
 * abrir la Activity. FlutterActivity configura canales y ruta antes de main().
 * POR QUÉ: AudioServicePlugin conecta su servicio durante el registro; si no
 * encuentra un motor cacheado crea otro y ejecuta main sin los canales de Nano.
 */
internal object NanoUiFlutterEngine {
    @Synchronized
    fun reserve(context: Context): FlutterEngine {
        val cache = FlutterEngineCache.getInstance()
        val key = AudioServicePlugin.getFlutterEngineId()
        cache.get(key)?.let { return it }
        // false desactiva el registro automático, no la funcionalidad de audio.
        return FlutterEngine(context.applicationContext, null, false).also {
            cache.put(key, it)
        }
    }

    @Synchronized
    fun obtain(context: Context): FlutterEngine {
        val engine = reserve(context)
        if (!engine.plugins.has(AudioServicePlugin::class.java)) {
            GeneratedPluginRegistrant.registerWith(engine)
        }
        return engine
    }
}
