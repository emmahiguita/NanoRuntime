package dev.nanoai.mobile.input

import android.os.Build
import android.view.KeyEvent
import android.view.inputmethod.InputConnection

/**
 * QUÉ HACE: Operaciones seguras y atómicas sobre [InputConnection] del editor activo.
 * POR QUÉ EXISTE: Previene corrupción de emojis (surrogate pairs UTF-16) y maneja palabras.
 * QUÉ RECIBE: El [InputConnection] activo del IME y cadenas de texto.
 * QUÉ DEVUELVE: Resultados booleanos o texto extraído sin fugas de memoria.
 * QUÉ PUEDE FALLAR: Si el editor anfitrión desconecta la sesión, retorna seguro sin colapsar.
 */
internal object NanoInputConnectionHelper {

    /**
     * Borrado seguro de caracteres Unicode y emojis compuestos.
     * En API 24+ usa deleteSurroundingTextInCodePoints; en versiones previas
     * detecta pares sustitutos (surrogates) para no romper secuencias de 32 bits.
     */
    fun safeDelete(connection: InputConnection?): Boolean {
        if (connection == null) return false

        // Si hay texto seleccionado, el borrado lo reemplaza por cadena vacía.
        val selected = connection.getSelectedText(0)
        if (!selected.isNullOrEmpty()) {
            return connection.commitText("", 1)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val deleted = connection.deleteSurroundingTextInCodePoints(1, 0)
            if (deleted) return true
        }

        // Inspeccionar el carácter previo antes de borrar para detectar surrogate pairs
        val before = connection.getTextBeforeCursor(2, 0)
        val charsToDelete = if (!before.isNullOrEmpty() && before.length >= 2 &&
            Character.isSurrogatePair(before[before.length - 2], before[before.length - 1])
        ) {
            2
        } else {
            1
        }

        val deleted = connection.deleteSurroundingText(charsToDelete, 0)
        return if (!deleted) {
            connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_DEL)) &&
                connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_DEL))
        } else {
            true
        }
    }

    /**
     * Extrae la última palabra que se está escribiendo antes del cursor para predicción.
     */
    fun getWordBeforeCursor(connection: InputConnection?): String {
        if (connection == null) return ""
        val text = connection.getTextBeforeCursor(40, 0)?.toString() ?: return ""
        if (text.isEmpty() || text.last().isWhitespace()) return ""

        val lastSpaceIndex = text.lastIndexOfAny(charArrayOf(' ', '\n', '\t', ',', '.', ';', ':', '!', '?', '(', ')', '"', '\''))
        return if (lastSpaceIndex >= 0) {
            text.substring(lastSpaceIndex + 1)
        } else {
            text
        }
    }

    /**
     * Reemplaza la palabra actual bajo el cursor por la sugerencia seleccionada.
     */
    fun replaceCurrentWord(connection: InputConnection?, suggestion: String): Boolean {
        if (connection == null || suggestion.isEmpty()) return false
        val currentWord = getWordBeforeCursor(connection)
        connection.beginBatchEdit()
        try {
            if (currentWord.isNotEmpty()) {
                connection.deleteSurroundingText(currentWord.length, 0)
            }
            connection.commitText("$suggestion ", 1)
        } finally {
            connection.endBatchEdit()
        }
        return true
    }

    /**
     * Desplaza el cursor n posiciones a izquierda (< 0) o derecha (> 0).
     */
    fun moveCursor(connection: InputConnection?, offset: Int): Boolean {
        if (connection == null || offset == 0) return false
        val key = if (offset < 0) KeyEvent.KEYCODE_DPAD_LEFT else KeyEvent.KEYCODE_DPAD_RIGHT
        val count = kotlin.math.abs(offset)
        for (i in 0 until count) {
            connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, key))
            connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_UP, key))
        }
        return true
    }
}
