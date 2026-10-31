package dev.nanoai.mobile.channels

import android.content.Context
import android.net.Uri
import android.provider.ContactsContract
import android.util.Log

/**
 * Resuelve y extrae el contacto individual retornado por ACTION_PICK.
 *
 * QUÉ HACE:
 * - Consulta el Uri retornado por el selector nativo del sistema operativo.
 * - Extrae el número telefónico y el nombre visible sin requerir READ_CONTACTS global.
 *
 * CÓMO FUNCIONA:
 * - Realiza una proyección mínima sobre ContactsContract.CommonDataKinds.Phone.
 *
 * POR QUÉ:
 * - Desacopla la resolución de selección de la consulta masiva de contactos (< 60 líneas).
 */
internal object PickedContactResolver {
    private const val TAG = "PickedContactResolver"

    fun resolvePickedContact(context: Context, contactUri: Uri): Map<String, Any>? {
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
            ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
        )
        return try {
            context.contentResolver.query(contactUri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIdx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                    val numIdx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                    val idIdx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.CONTACT_ID)

                    val name = if (nameIdx >= 0) cursor.getString(nameIdx) ?: "Contacto" else "Contacto"
                    val rawNum = if (numIdx >= 0) cursor.getString(numIdx) ?: "" else ""
                    val id = if (idIdx >= 0) cursor.getString(idIdx) ?: "" else ""
                    val cleanNumber = rawNum.filter(Char::isDigit)

                    mapOf(
                        "id" to id,
                        "name" to name.trim(),
                        "number" to cleanNumber,
                        "jid" to "",
                        "isBusiness" to false,
                        "isGroup" to false,
                        "packageName" to "",
                        "accountType" to "",
                        "verificationSource" to "action_pick",
                        "isWhatsAppVerified" to false,
                    )
                } else null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error resolviendo contacto de ACTION_PICK: ${e.message}")
            null
        }
    }
}
