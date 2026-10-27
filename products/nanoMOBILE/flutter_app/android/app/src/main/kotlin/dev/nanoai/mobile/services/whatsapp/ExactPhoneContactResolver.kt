package dev.nanoai.mobile.services.whatsapp

import android.content.Context
import android.provider.ContactsContract
import java.text.Normalizer

/** Resuelve solo un número inequívoco. LIKE limita la consulta, pero la igualdad
 * normalizada y la deduplicación final deciden; nunca se utiliza el primer cursor.
 * No acredita registro en WhatsApp: eso se verifica en su interfaz antes del clic. */
internal object ExactPhoneContactResolver {
    fun resolve(context: Context, query: String): String? {
        val clean = query.trim()
        if (clean.matches(Regex("[+0-9 ().-]+"))) {
            return clean.filter(Char::isDigit).takeIf { it.length in 7..15 }
        }
        if (clean.isEmpty()) return null
        return try {
            val phones = linkedSetOf<String>()
            context.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER,
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME),
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ?",
                arrayOf("%$clean%"), null,
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    if (normalize(cursor.getString(1).orEmpty()) != normalize(clean)) continue
                    cursor.getString(0)?.filter(Char::isDigit)
                        ?.takeIf { it.length in 7..15 }?.let(phones::add)
                }
            }
            phones.singleOrNull()
        } catch (_: SecurityException) { null }
    }

    private fun normalize(value: String): String = Normalizer
        .normalize(value.trim().lowercase(), Normalizer.Form.NFD)
        .replace(Regex("\\p{M}+"), "").replace(Regex("\\s+"), " ")
}
