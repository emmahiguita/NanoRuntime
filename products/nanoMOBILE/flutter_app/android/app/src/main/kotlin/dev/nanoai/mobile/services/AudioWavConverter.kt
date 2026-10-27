package dev.nanoai.mobile.services

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * AudioWavConverter
 * 
 * QUÉ HACE:
 * Decodifica audios nativos de Android (.opus de WhatsApp, .m4a, .aac, .ogg) a WAV PCM
 * 16-bit lineal sin dependencias externas usando los decodificadores del sistema (MediaCodec).
 * 
 * POR QUÉ:
 * whisper.cpp (miniaudio) requiere formatos PCM sin comprimir o decodificados (WAV).
 * Las notas de voz de WhatsApp llegan en formato Ogg Opus (.opus) que los teléfonos
 * Android decodifican por hardware o códec nativo c2.android.opus.decoder.
 */
object AudioWavConverter {
    private const val TAG = "AudioWavConverter"

    fun convertToWav(inputPath: String, outputPath: String): Boolean {
        val cleanIn = inputPath.replaceFirst("file://", "")
        val inFile = File(cleanIn)
        if (!inFile.exists() || inFile.length() == 0L) {
            Log.e(TAG, "Archivo de entrada no existe o está vacío: $inputPath")
            return false
        }

        val cleanOut = outputPath.replaceFirst("file://", "")
        val outFile = File(cleanOut)
        outFile.parentFile?.mkdirs()
        if (outFile.exists()) outFile.delete()

        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        var fos: FileOutputStream? = null

        try {
            extractor.setDataSource(inFile.absolutePath)
            var audioTrackIndex = -1
            var format: MediaFormat? = null

            for (i in 0 until extractor.trackCount) {
                val f = extractor.getTrackFormat(i)
                val mime = f.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    format = f
                    break
                }
            }

            if (audioTrackIndex < 0 || format == null) {
                Log.e(TAG, "No se encontró pista de audio en $inputPath")
                return false
            }

            extractor.selectTrack(audioTrackIndex)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: "audio/opus"
            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            fos = FileOutputStream(outFile)
            // Reservar 44 bytes para cabecera WAV que se escribirá al finalizar
            fos.write(ByteArray(44))

            var sampleRate = if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            } else 48000
            var channels = if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            } else 1

            val bufferInfo = MediaCodec.BufferInfo()
            var isEos = false
            var totalPcmBytes = 0L
            val kTimeoutUs = 10000L

            while (!isEos) {
                val inIndex = codec.dequeueInputBuffer(kTimeoutUs)
                if (inIndex >= 0) {
                    val inBuffer = codec.getInputBuffer(inIndex)
                    if (inBuffer != null) {
                        inBuffer.clear()
                        val sampleSize = extractor.readSampleData(inBuffer, 0)
                        if (sampleSize < 0) {
                            codec.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        } else {
                            val presentationTimeUs = extractor.sampleTime
                            codec.queueInputBuffer(inIndex, 0, sampleSize, presentationTimeUs, 0)
                            extractor.advance()
                        }
                    }
                }

                var outIndex = codec.dequeueOutputBuffer(bufferInfo, kTimeoutUs)
                while (outIndex >= 0) {
                    val outBuffer = codec.getOutputBuffer(outIndex)
                    if (outBuffer != null && bufferInfo.size > 0) {
                        outBuffer.position(bufferInfo.offset)
                        outBuffer.limit(bufferInfo.offset + bufferInfo.size)
                        val chunk = ByteArray(bufferInfo.size)
                        outBuffer.get(chunk)
                        fos.write(chunk)
                        totalPcmBytes += bufferInfo.size
                    }

                    codec.releaseOutputBuffer(outIndex, false)

                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        isEos = true
                        break
                    }
                    outIndex = codec.dequeueOutputBuffer(bufferInfo, 0)
                }

                if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val newFormat = codec.outputFormat
                    if (newFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                        sampleRate = newFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    }
                    if (newFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                        channels = newFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    }
                }
            }

            fos.flush()
            fos.close()
            fos = null

            // Escribir cabecera WAV canónica al inicio del archivo
            writeWavHeader(outFile, totalPcmBytes, sampleRate, channels)
            Log.i(TAG, "Audio decodificado exitosamente a WAV: ${outFile.absolutePath} ($totalPcmBytes bytes, ${sampleRate}Hz, ch=$channels)")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Fallo al convertir audio a WAV: $e", e)
            return false
        } finally {
            try { fos?.close() } catch (_: Exception) {}
            try { codec?.stop(); codec?.release() } catch (_: Exception) {}
            try { extractor.release() } catch (_: Exception) {}
        }
    }

    private fun writeWavHeader(file: File, pcmBytes: Long, sampleRate: Int, channels: Int) {
        val totalDataLen = pcmBytes + 36
        val byteRate = sampleRate * channels * 2
        val blockAlign = channels * 2

        val raf = RandomAccessFile(file, "rw")
        raf.seek(0)
        val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        header.put("RIFF".toByteArray())
        header.putInt(totalDataLen.toInt())
        header.put("WAVE".toByteArray())
        header.put("fmt ".toByteArray())
        header.putInt(16) // Subchunk1Size (16 para PCM lineal)
        header.putShort(1.toShort()) // AudioFormat 1 = PCM
        header.putShort(channels.toShort())
        header.putInt(sampleRate)
        header.putInt(byteRate)
        header.putShort(blockAlign.toShort())
        header.putShort(16.toShort()) // BitsPerSample = 16
        header.put("data".toByteArray())
        header.putInt(pcmBytes.toInt())

        raf.write(header.array())
        raf.close()
    }
}
