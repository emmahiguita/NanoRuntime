package dev.nanoai.mobile.input

/**
 * QUÉ HACE: Repositorio de emojis clasificados por categorías para el teclado Nano.
 * POR QUÉ EXISTE: Provee acceso rápido a emojis estándar Unicode sin dependencias pesadas.
 * QUÉ DEVUELVE: Listas de secuencias Unicode seguras de emojis.
 */
internal object NanoEmojiData {

    data class Category(val title: String, val icon: String, val emojis: List<String>)

    val categories = listOf(
        Category(
            title = "Emociones",
            icon = "😊",
            emojis = listOf(
                "😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "😊", "😇",
                "🙂", "🙃", "😉", "😌", "😍", "🥰", "😘", "😗", "😙", "😚",
                "😋", "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🤩",
                "🥳", "😏", "😒", "😞", "😔", "😟", "😕", "🙁", "😣", "😖",
                "😫", "😩", "🥺", "😢", "😭", "😤", "😠", "😡", "🤬", "🤯",
                "😳", "🥵", "🥶", "😱", "😨", "😰", "😥", "😓", "🤗", "🤔"
            )
        ),
        Category(
            title = "Gestos",
            icon = "👍",
            emojis = listOf(
                "👍", "👎", "👏", "🙌", "👐", "🤲", "🤝", "🙏", "✍️", "💪",
                "✌️", "🤞", "🤟", "🤘", "🤙", "👈", "👉", "👆", "👇", "☝️",
                "✋", "🤚", "🖐️", "🖖", "👋", "👌", "🤌", "🤏", "✊", "👊"
            )
        ),
        Category(
            title = "Nano y Naturaleza",
            icon = "🦉",
            emojis = listOf(
                "🦉", "🦅", "🕊️", "🦜", "🦢", "🐶", "🐱", "🐭", "🐹", "🐰",
                "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵",
                "🌸", "🌹", "🌺", "🌻", "🌼", "🌷", "🌱", "🌲", "🌳", "🌴",
                "🌙", "⭐", "🌟", "✨", "⚡", "🔥", "🌈", "☀️", "🌤️", "❄️"
            )
        ),
        Category(
            title = "Objetos y Símbolos",
            icon = "💡",
            emojis = listOf(
                "💡", "📱", "💻", "⌨️", "🖥️", "📞", "📟", "✉️", "📩", "📦",
                "📝", "📄", "📅", "📊", "📈", "🔍", "🔎", "🔒", "🔓", "🔑",
                "❤️", "💙", "💚", "💛", "🧡", "💜", "🖤", "🤍", "🤎", "💔",
                "🎉", "🎊", "🏆", "🥇", "🥈", "🥉", "🚀", "🎯", "💯", "✅"
            )
        )
    )
}
