package dev.nanoai.mobile.input

/**
 * QUÉ HACE: Modelos de datos para teclas, distribuciones alfabéticas, numéricas y de símbolos.
 * POR QUÉ EXISTE: Soporta caracteres alternativos (tildes), teclado español y modos especiales.
 */
internal enum class KeyType {
    CHARACTER,
    SHIFT,
    BACKSPACE,
    ENTER,
    SPACE,
    MODE_TOGGLE,
    SECONDARY_MODE_TOGGLE,
    SWITCH_KEYBOARD,
    PASTE,
    OWL_ACTION,
    EMOJI,
}

internal enum class KeyboardMode {
    LETTERS,
    SYMBOLS,
    MORE_SYMBOLS,
    EMOJIS,
}

internal data class KeyModel(
    val primaryText: String,
    val shiftedText: String = primaryText.uppercase(),
    val type: KeyType = KeyType.CHARACTER,
    val weight: Float = 1.0f,
    val isSpecial: Boolean = false,
    val alternatives: List<String> = emptyList(),
)

internal object NanoKeyboardLayouts {
    fun getRows(mode: KeyboardMode): List<List<KeyModel>> = when (mode) {
        KeyboardMode.LETTERS -> lettersLayout
        KeyboardMode.SYMBOLS -> symbolsLayout
        KeyboardMode.MORE_SYMBOLS -> moreSymbolsLayout
        KeyboardMode.EMOJIS -> emptyList()
    }

    private val lettersLayout = listOf(
        listOf(
            KeyModel("q", alternatives = listOf("1")),
            KeyModel("w", alternatives = listOf("2")),
            KeyModel("e", alternatives = listOf("é", "è", "ë", "ê", "3")),
            KeyModel("r", alternatives = listOf("4")),
            KeyModel("t", alternatives = listOf("5")),
            KeyModel("y", alternatives = listOf("6")),
            KeyModel("u", alternatives = listOf("ú", "ü", "ù", "û", "7")),
            KeyModel("i", alternatives = listOf("í", "ì", "ï", "î", "8")),
            KeyModel("o", alternatives = listOf("ó", "ò", "ö", "ô", "9")),
            KeyModel("p", alternatives = listOf("0")),
        ),
        listOf(
            KeyModel("a", alternatives = listOf("á", "à", "ä", "â", "@")),
            KeyModel("s", alternatives = listOf("ß")),
            KeyModel("d"), KeyModel("f"), KeyModel("g"), KeyModel("h"),
            KeyModel("j"), KeyModel("k"), KeyModel("l"),
            KeyModel("ñ"),
        ),
        listOf(
            KeyModel("⇧", type = KeyType.SHIFT, weight = 1.35f, isSpecial = true),
            KeyModel("z"), KeyModel("x"),
            KeyModel("c", alternatives = listOf("ç")),
            KeyModel("v"), KeyModel("b"),
            KeyModel("n", alternatives = listOf("ñ")),
            KeyModel("m"),
            KeyModel("⌫", type = KeyType.BACKSPACE, weight = 1.35f, isSpecial = true),
        ),
        listOf(
            KeyModel("?123", type = KeyType.MODE_TOGGLE, weight = 1.25f, isSpecial = true),
            KeyModel("😊", type = KeyType.EMOJI, weight = 1.0f, isSpecial = true),
            KeyModel("Espacio", type = KeyType.SPACE, weight = 4.2f),
            KeyModel(".", alternatives = listOf(",", "…", "-", ":")),
            KeyModel("↵", type = KeyType.ENTER, weight = 1.45f, isSpecial = true),
        ),
    )

    private val symbolsLayout = listOf(
        listOf("1", "2", "3", "4", "5", "6", "7", "8", "9", "0").map { KeyModel(it) },
        listOf(
            KeyModel("@"), KeyModel("#"),
            KeyModel("$", alternatives = listOf("€", "£", "¥", "¢")),
            KeyModel("%"), KeyModel("&"), KeyModel("*"), KeyModel("-"),
            KeyModel("+"), KeyModel("("), KeyModel(")"),
        ),
        listOf(
            KeyModel("=/<", type = KeyType.SECONDARY_MODE_TOGGLE, weight = 1.35f, isSpecial = true),
            KeyModel("!"), KeyModel("\""), KeyModel("'"), KeyModel(":"),
            KeyModel(";"), KeyModel("/"),
            KeyModel("?", alternatives = listOf("¿")),
            KeyModel("⌫", type = KeyType.BACKSPACE, weight = 1.35f, isSpecial = true),
        ),
        listOf(
            KeyModel("ABC", type = KeyType.MODE_TOGGLE, weight = 1.25f, isSpecial = true),
            KeyModel("😊", type = KeyType.EMOJI, weight = 1.0f, isSpecial = true),
            KeyModel("Espacio", type = KeyType.SPACE, weight = 4.2f),
            KeyModel("¿", alternatives = listOf("?")),
            KeyModel("↵", type = KeyType.ENTER, weight = 1.45f, isSpecial = true),
        ),
    )

    private val moreSymbolsLayout = listOf(
        listOf("~", "`", "|", "•", "√", "π", "÷", "×", "¶", "∆").map { KeyModel(it) },
        listOf("£", "€", "¥", "¢", "^", "°", "=", "{", "}", "\\").map { KeyModel(it) },
        listOf(
            KeyModel("?123", type = KeyType.SECONDARY_MODE_TOGGLE, weight = 1.35f, isSpecial = true),
            KeyModel("©"), KeyModel("<"), KeyModel(">"), KeyModel("["),
            KeyModel("]"), KeyModel("¡"), KeyModel("¿"),
            KeyModel("⌫", type = KeyType.BACKSPACE, weight = 1.35f, isSpecial = true),
        ),
        listOf(
            KeyModel("ABC", type = KeyType.MODE_TOGGLE, weight = 1.25f, isSpecial = true),
            KeyModel("😊", type = KeyType.EMOJI, weight = 1.0f, isSpecial = true),
            KeyModel("Espacio", type = KeyType.SPACE, weight = 4.2f),
            KeyModel("…"),
            KeyModel("↵", type = KeyType.ENTER, weight = 1.45f, isSpecial = true),
        ),
    )
}
