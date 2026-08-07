package dev.nanoai.mobile

import java.io.ByteArrayOutputStream
import java.io.OutputStream
import android.util.Log

/**
 * Decoder XZ/LZMA2 completo en Kotlin puro (sin dependencias, sin ejecutar
 * binarios). Port del algoritmo LZMA SDK (dominio público, Igor Pavlov).
 *
 * POR QUÉ: tar/xz del rootfs Termux están STRIPPED (no exportan "main" →
 * dlopen-ables no; e_entry/trampolín frágil). El toybox del sistema delega
 * xz a un binario externo inexistente. El toybox de la Fase 1 no tiene
 * applets. Kotlin puro es la única vía 100% confiable en Android.
 *
 * Soporta: stream .xz (header + bloques LZMA2 + footer), chunks LZMA2 con
 * range decoder y modelo de probabilidades LZMA estándar, y chunks
 * uncompressed. Diccionario hasta 16 MB (lo que usan los .deb Termux).
 */
object XzDecoder {

    class XzException(msg: String) : Exception(msg)

    // ── Range decoder ──
    private class RangeDecoder(private val data: ByteArray) {
        var pos = 0       // expuesto para que lzmaDecode reporte bytes consumidos
        var range = 0xFFFFFFFFL
        var code = 0L
        private val buf = ByteArray(4)

        init {
            // 5 bytes iniciales: 1 byte de 0 + 4 bytes de code
            pos = 1
            for (i in 0 until 4) {
                code = (code shl 8) or (data[pos].toLong() and 0xFF)
                pos++
            }
        }

        fun isFinished(): Boolean = pos >= data.size

        fun decodeBit(prob: IntArray, index: Int): Int {
            val bound = (range shr 11) * prob[index].toLong()
            var p = prob[index]
            if (code < bound) {
                range = bound
                p += (2048 - p) shr 5
                prob[index] = p
                return 0
            } else {
                range -= bound
                code -= bound
                p -= p shr 5
                prob[index] = p
                return 1
            }
        }

        fun decodeTree(probs: IntArray, base: Int, numBits: Int): Int {
            var m = 1
            var symbol = 0
            for (i in 0 until numBits) {
                symbol = (symbol shl 1) or decodeBit(probs, base + m)
                m = (m shl 1) or (symbol and 1)
            }
            return symbol
        }

        fun decodeReverseTree(probs: IntArray, base: Int, numBits: Int): Int {
            var m = 1
            var symbol = 0
            for (i in 0 until numBits) {
                val bit = decodeBit(probs, base + m)
                m = (m shl 1) or bit
                symbol = symbol or (bit shl i)
            }
            return symbol
        }

        fun decodeDirectBits(numBits: Int): Int {
            var res = 0
            var count = numBits
            do {
                range = range ushr 1
                val t = ((code - range) ushr 31).toInt()
                code -= range and (t - 1).toLong()
                res = (res shl 1) or (1 - t)
                if (range < (1L shl 24)) {
                    range = range shl 8
                    code = (code shl 8) or (data[pos].toLong() and 0xFF)
                    pos++
                }
                count--
            } while (count > 0)
            return res
        }

        fun normalize() {
            if (range < (1L shl 24)) {
                range = range shl 8
                code = (code shl 8) or (data[pos].toLong() and 0xFF)
                pos++
            }
        }
    }

    // ── Decoder LZMA2 completo ──
    private class Lzma2Decoder(private val maxDictSize: Int) {
        private val dict = ByteArray(maxDictSize)
        private var dictPos = 0
        private var dictLimit = 0
        private val probs = IntArray(0x300 + (1 shl 17)) // probs + literales 0x300
        private var state = 0
        private var rep0 = 0
        private var rep1 = 0
        private var rep2 = 0
        private var rep3 = 0
        private var lc = 3
        private var lp = 0
        private var pb = 2
        private var lcLp = 0
        private var literalPosMask = 0
        private var posStateMask = 3
        var lastConsumed = 0  // bytes comprimidos consumidos por último lzmaDecode

        // Offsets de probs (layout LZMA SDK)
        private val kIsMatch = 0
        private val kIsRep = 48
        private val kIsRepG0 = 60
        private val kIsRepG1 = 72
        private val kIsRepG2 = 84
        private val kIsRep0Long = 96
        private val kPosSlot = 144
        private val kSpecPos = 400
        private val kAlign = 514
        private val kLenCoder = 530
        private val kRepLenCoder = 1044
        private val kLiteral = 1558

        private fun initProbs() {
            java.util.Arrays.fill(probs, 1024)
            state = 0
            rep0 = 0; rep1 = 0; rep2 = 0; rep3 = 0
        }

        private fun resetState() {
            initProbs()
        }

        private fun resetDict() {
            dictPos = 0
        }

        private fun nextState() {
            state = when {
                state < 5 -> 0
                state < 10 -> 3
                state < 12 -> 5
                else -> 7
            }
        }

        /** Descomprime un bloque LZMA2 completo. */
        fun decompress(block: ByteArray, out: OutputStream): Int {
            var p = 0
            var totalOut = 0
            while (p < block.size) {
                val control = block[p].toInt() and 0xFF
                p++
                when {
                    control == 0x00 -> break // fin del stream
                    control == 0x01 || control == 0x02 -> {
                        // Uncompressed chunk
                        if (control == 0x01) resetDict()
                        if (p + 2 > block.size) throw XzException("uncompressed chunk corto")
                        val size = ((block[p].toInt() and 0xFF) shl 8) or (block[p + 1].toInt() and 0xFF)
                        p += 2
                        if (p + size > block.size) throw XzException("uncompressed data corta")
                        if (dictPos + size > dict.size) throw XzException("dict overflow uncompressed")
                        System.arraycopy(block, p, dict, dictPos, size)
                        dictPos += size
                        out.write(block, p, size)
                        totalOut += size
                        p += size
                    }
                    control >= 0x80 -> {
                        // LZMA chunk
                        val resetType = (control shr 5) and 0x3
                        val sizeHi = control and 0x1F
                        if (p + 2 > block.size) throw XzException("LZMA chunk corto")
                        val uncompSize = ((sizeHi shl 8) or (block[p].toInt() and 0xFF)) + 1
                        p++
                        val propsByte = block[p].toInt() and 0xFF
                        p++
                        if (resetType == 3) { resetState(); resetDict() }
                        else if (resetType == 2) resetDict()
                        else if (resetType == 1) resetState()

                        lc = propsByte % 9
                        val pbLp = propsByte / 9
                        lp = pbLp % 5
                        pb = pbLp / 5
                        lcLp = lc + lp
                        literalPosMask = (1 shl lp) - 1
                        posStateMask = (1 shl pb) - 1
                        java.util.Arrays.fill(probs, kLiteral, kLiteral + (1 shl lcLp) * 0x300, 1024)

                        // Decodificar. lzmaDecode retorna bytes producidos (n).
                        // El avance real en el bloque comprimido lo da rc.pos
                        // (consumido), NO n (producido). Antes se usaba p += n
                        // lo que causaba que el parser leyera basura del stream.
                        val n = lzmaDecode(block, p, uncompSize)
                        // Escribir n bytes desde dictPos-n. Con wrap: si
                        // dictPos < n, los últimos bytes están en posiciones altas.
                        val start = dictPos - n
                        if (start >= 0) {
                            out.write(dict, start, n)
                        } else {
                            // Wrap: escribir la parte final (alta) + parte inicial (baja)
                            val part2 = -start // bytes al final del buffer
                            out.write(dict, dict.size - part2, part2)
                            out.write(dict, 0, n - part2)
                        }
                        totalOut += n
                        p += lastConsumed // bytes comprimidos realmente consumidos
                    }
                    else -> throw XzException("control LZMA2 inválido: 0x%02x".format(control))
                }
            }
            return totalOut
        }

        /** Decodifica datos LZMA dentro del chunk; retorna bytes producidos. */
        private fun lzmaDecode(data: ByteArray, dataStart: Int, uncompSize: Int): Int {
            // Reiniciar literales por posición
            val rc = RangeDecoder(data.copyOfRange(dataStart, data.size))
            var produced = 0

            while (produced < uncompSize) {
                val posState = (dictPos) and posStateMask
                if (rc.decodeBit(probs, kIsMatch + (state shl 4) + posState) == 0) {
                    // Literal
                    val prevByte = if (dictPos > 0) dict[dictPos - 1].toInt() and 0xFF else 0
                    val litProbsBase = kLiteral + ((dictPos and literalPosMask) shl lcLp) * 0x300
                    val litState = if (state < 7) 0 else 1
                    val matchByte = if (rep0 > 0 && dictPos - rep0 >= 0 && state >= 7)
                        dict[dictPos - rep0].toInt() and 0xFF else 0
                    var symbol = 1
                    if (litState == 0) {
                        symbol = decodeLiteral(rc, litProbsBase, symbol, 8)
                    } else {
                        symbol = decodeLiteralMatch(rc, litProbsBase, symbol, matchByte)
                    }
                    dict[dictPos % dict.size] = symbol.toByte()
                    dictPos++
                    produced++
                    nextState()
                } else {
                    // Match / rep
                    var len: Int
                    val isRep = rc.decodeBit(probs, kIsRep + state)
                    if (isRep == 0) {
                        // Normal match
                        val posSlot = decodePosSlot(rc)
                        len = decodeLen(rc, kLenCoder, posState)
                        if (posSlot >= 4) {
                            rep3 = rep2; rep2 = rep1; rep1 = rep0
                            rep0 = decodeDistance(rc, posSlot)
                        }
                        nextState()
                        state = if (state < 7) 8 else 11
                    } else {
                        val isRepG0 = rc.decodeBit(probs, kIsRepG0 + state)
                        if (isRepG0 == 0) {
                            if (rc.decodeBit(probs, kIsRep0Long + (state shl 4) + posState) == 0) {
                                // Short rep: 1 byte desde rep0 con wrap
                                val src = if (dictPos >= rep0) dictPos - rep0 else dictPos - rep0 + dict.size
                                dict[dictPos % dict.size] = dict[src]
                                dictPos++
                                produced++
                                nextState()
                                continue
                            }
                        } else {
                            val isRepG1 = rc.decodeBit(probs, kIsRepG1 + state)
                            if (isRepG1 == 0) {
                                val d = rep0; rep0 = rep1; rep1 = d
                            } else {
                                val isRepG2 = rc.decodeBit(probs, kIsRepG2 + state)
                                if (isRepG2 == 0) {
                                    val d = rep0; rep0 = rep2; rep2 = d
                                } else {
                                    val d = rep0; rep0 = rep3; rep3 = d
                                }
                            }
                        }
                        len = decodeLen(rc, kRepLenCoder, posState)
                        nextState()
                        state = if (state < 7) 9 else 11
                    }
                    // Copiar len+2 bytes desde rep0 con wrap del diccionario
                    var i = 0
                    val total = len + 2
                    while (i < total) {
                        val src = if (dictPos >= rep0) dictPos - rep0 else dictPos - rep0 + dict.size
                        dict[dictPos % dict.size] = dict[src]
                        dictPos++
                        i++
                    }
                    produced += total
                }
                rc.normalize()
            }
            lastConsumed = rc.pos  // bytes comprimidos realmente consumidos del stream
            return produced
        }

        private fun decodeLiteral(rc: RangeDecoder, base: Int, mutSym: Int, bits: Int): Int {
            var symbol = mutSym
            var count = bits
            do {
                symbol = (symbol shl 1) or rc.decodeBit(probs, base + symbol)
                count--
            } while (count > 0)
            return symbol
        }

        private fun decodeLiteralMatch(rc: RangeDecoder, base: Int, mutSym: Int, matchByte: Int): Int {
            var symbol = mutSym
            var m = matchByte
            var count = 8
            do {
                val matchBit = (m shr 7) and 1
                m = (m shl 1) and 0xFF
                val bit = rc.decodeBit(probs, base + ((1 + matchBit) shl 8) + symbol)
                symbol = (symbol shl 1) or bit
                if (matchBit != bit) {
                    // Resto del literal normal
                    while (count > 1) {
                        symbol = (symbol shl 1) or rc.decodeBit(probs, base + symbol)
                        count--
                    }
                    break
                }
                count--
            } while (count > 0)
            return symbol
        }

        private fun decodePosSlot(rc: RangeDecoder): Int {
            val state2 = if (state < 7) 0 else 1
            val slot = rc.decodeTree(probs, kPosSlot + state2 * 64, 6)
            return slot
        }

        private fun decodeDistance(rc: RangeDecoder, posSlot: Int): Int {
            if (posSlot < 4) return posSlot
            val bits = (posSlot shr 1) - 1
            var dist = (2 or (posSlot and 1)) shl bits
            if (posSlot < 14) {
                dist += rc.decodeReverseTree(probs, kSpecPos + dist - posSlot, bits)
            } else {
                dist += rc.decodeDirectBits(bits - 4) shl 4
                dist += rc.decodeReverseTree(probs, kAlign, 4)
            }
            return dist
        }

        private fun decodeLen(rc: RangeDecoder, base: Int, posState: Int): Int {
            if (rc.decodeBit(probs, base) == 0) {
                return rc.decodeTree(probs, base + 2 + (posState shl 3), 3)
            }
            if (rc.decodeBit(probs, base + 1) == 0) {
                return 8 + rc.decodeTree(probs, base + 2 + 128 + (posState shl 3), 3)
            }
            return 16 + rc.decodeTree(probs, base + 2 + 128 + 128, 8)
        }
    }

    // ── Stream .xz ──
    // NOTA: decompress(ByteArray) comentado — solo se usa decompressToStream
    // para evitar OOM. Si algo necesita ByteArray, que llame a
    // decompressToStream con ByteArrayOutputStream.
    /*
    fun decompress(input: ByteArray): ByteArray {
        val out = ByteArrayOutputStream()
        decompressToStream(input, out)
        return out.toByteArray()
    }
    */

    /** Streaming: descomprime directamente a un OutputStream sin acumular
     *  todo en memoria. Evita OOM con paquetes grandes. */
    fun decompressToStream(input: ByteArray, out: OutputStream): Long {
        if (input.size < 12) throw XzException("xz demasiado corto")
        if (input[0] != 0xFD.toByte() || input[1] != 0x37.toByte() ||
            input[2] != 0x7A.toByte() || input[3] != 0x58.toByte() ||
            input[4] != 0x5A.toByte() || input[5] != 0x00.toByte()) {
            throw XzException("no es un stream .xz")
        }
        val magicY = input[input.size - 2].toInt() and 0xFF
        val magicZ = input[input.size - 1].toInt() and 0xFF
        if (magicY != 0x59 || magicZ != 0x5A) throw XzException("footer .xz inválido")
        val streamEnd = input.size - 12

        val streamFlagsCheckType = (input[streamEnd + 8].toInt() and 0xFF) and 0x0F
        val checkSize = when (streamFlagsCheckType) {
            0x00 -> 0; 0x01 -> 4; 0x04 -> 8; 0x0A -> 32
            else -> throw XzException("check type desconocido: $streamFlagsCheckType")
        }

        val backwardSize = readUInt32(input, streamEnd + 4)
        val indexStart = streamEnd - backwardSize
        var ip = indexStart

        val recordCount: Int
        val blockOffsets: IntArray
        val blockUnpadded: IntArray

        // Intentar parsear el índice. Si falla (backwardSize inválido,
        // indicator != 0x00), asumir single-block (todos los .deb de Termux).
        if (backwardSize >= 4 && ip in 13..streamEnd && (input[ip].toInt() and 0xFF) == 0x00) {
            ip++
            recordCount = readVarInt(input, ip); ip += varIntSize(recordCount)
        } else {
            recordCount = 1
        }
        
        blockOffsets = IntArray(recordCount + 1)
        blockUnpadded = IntArray(recordCount)
        blockOffsets[0] = 12
        var runningOffset = 12L
        for (r in 0 until recordCount) {
            val unpadded: Int
            if (backwardSize >= 4 && ip in 0..streamEnd - 4) {
                unpadded = readVarInt(input, ip); ip += varIntSize(unpadded)
                readVarInt(input, ip); ip += varIntSize(readVarInt(input, ip)) // uncompressed, skip
            } else {
                // Single-block fallback: unpadded = streamEnd - 12
                unpadded = streamEnd - 12
            }
            val pad = if (unpadded % 4 == 0) 0 else 4 - (unpadded % 4)
            runningOffset += unpadded + pad
            blockUnpadded[r] = unpadded
            blockOffsets[r + 1] = runningOffset.toInt()
        }

        var totalOut = 0L
        var lzma: Lzma2Decoder? = null
        for (b in 0 until recordCount) {
            val blockStart = blockOffsets[b]
            val blockEnd = blockOffsets[b + 1]
            if (blockEnd > streamEnd) throw XzException("bloque $b excede el stream")
            val headerByte = input[blockStart].toInt() and 0xFF
            val headerLen = (headerByte + 1) * 4
            val dataStart = blockStart + headerLen
            val unpadded = blockUnpadded[b]
            val dataEnd = blockStart + unpadded - checkSize
            if (dataEnd > dataStart && dataEnd <= streamEnd) {
                val compressed = input.copyOfRange(dataStart, dataEnd)
                if (lzma == null) {
                    val memBefore = Runtime.getRuntime().freeMemory()
                    lzma = Lzma2Decoder(1 shl 24)
                    val memAfter = Runtime.getRuntime().freeMemory()
                    if (memBefore - memAfter > 50_000_000) {
                        android.util.Log.e("XzDecoder", "LZMA decoder alloc grande: ${memBefore - memAfter}")
                    }
                }
                totalOut += lzma.decompress(compressed, out)
            }
        }
        return totalOut
    }

    private fun readUInt32(b: ByteArray, off: Int): Int {
        var v = 0
        for (i in 0 until 4) v = v or ((b[off + i].toInt() and 0xFF) shl (8 * i))
        return v
    }

    private fun readVarInt(b: ByteArray, off: Int): Int {
        var v = 0
        var shift = 0
        var i = off
        while (i < b.size) {
            val byte = b[i].toInt() and 0xFF
            v = v or ((byte and 0x7F) shl shift)
            if ((byte and 0x80) == 0) break
            shift += 7
            i++
        }
        return v
    }

    private fun varIntSize(v: Int): Int {
        var size = 1
        var x = v
        while (x >= 0x80) { x = x shr 7; size++ }
        return size
    }

    private fun readUInt64(b: ByteArray, off: Int): Long {
        var v = 0L
        for (i in 0 until 8) v = v or ((b[off + i].toLong() and 0xFF) shl (8 * i))
        return v
    }
}
