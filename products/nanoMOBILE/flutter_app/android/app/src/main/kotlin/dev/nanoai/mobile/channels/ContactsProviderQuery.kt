package dev.nanoai.mobile.channels

import android.content.Context
import android.provider.ContactsContract
import android.util.Log

/**
 * Consulta y extrae contactos de Android vía ContactsContract y ContactsProvider.
 *
 * QUÉ HACE:
 * - Consulta contactos vinculados con los MIME types oficiales de WhatsApp y WhatsApp Business.
 * - Enriquece con números telefónicos del dispositivo para la agenda completa.
 *
 * CÓMO FUNCIONA:
 * - Utiliza ContentResolver con proyecciones mínimas y seguras.
 * - Clasifica con precisión si el contacto cuenta con integración verificable de WhatsApp.
 *
 * POR QUÉ:
 * - Aísla la responsabilidad de consulta SQL/ContentProvider fuera del handler de canal (SRP < 160 líneas).
 */
internal object ContactsProviderQuery {
    private const val TAG = "ContactsProviderQuery"

    private const val WHATSAPP_MIME_PERSONAL = "vnd.android.cursor.item/vnd.com.whatsapp.profile"
    private const val WHATSAPP_MIME_BUSINESS = "vnd.android.cursor.item/vnd.com.whatsapp.w4b.profile"

    fun queryAllContacts(context: Context): List<Map<String, Any>> {
        val contacts = mutableListOf<Map<String, Any>>()
        val seenJids = mutableSetOf<String>()
        val seenNumbers = mutableSetOf<String>()

        queryWhatsAppMimeContacts(context, contacts, seenJids, seenNumbers)
        queryGeneralPhoneContacts(context, contacts, seenJids, seenNumbers)
        return contacts
    }

    private fun queryWhatsAppMimeContacts(
        context: Context,
        contacts: MutableList<Map<String, Any>>,
        seenJids: MutableSet<String>,
        seenNumbers: MutableSet<String>,
    ) {
        val projection = arrayOf(
            ContactsContract.Data._ID,
            ContactsContract.Data.RAW_CONTACT_ID,
            ContactsContract.Data.DISPLAY_NAME,
            ContactsContract.Data.DATA1,
            ContactsContract.Data.MIMETYPE,
            ContactsContract.RawContacts.ACCOUNT_TYPE,
        )
        val selection = "${ContactsContract.Data.MIMETYPE} IN (?, ?)"
        val selectionArgs = arrayOf(WHATSAPP_MIME_PERSONAL, WHATSAPP_MIME_BUSINESS)
        val sortOrder = "${ContactsContract.Data.DISPLAY_NAME} COLLATE NOCASE ASC"

        try {
            context.contentResolver.query(
                ContactsContract.Data.CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                sortOrder,
            )?.use { c ->
                val idIdx = c.getColumnIndex(ContactsContract.Data._ID)
                val rawIdIdx = c.getColumnIndex(ContactsContract.Data.RAW_CONTACT_ID)
                val nameIdx = c.getColumnIndex(ContactsContract.Data.DISPLAY_NAME)
                val data1Idx = c.getColumnIndex(ContactsContract.Data.DATA1)
                val mimeIdx = c.getColumnIndex(ContactsContract.Data.MIMETYPE)
                val accountTypeIdx = c.getColumnIndex(ContactsContract.RawContacts.ACCOUNT_TYPE)

                while (c.moveToNext()) {
                    val id = if (idIdx >= 0) c.getString(idIdx) else ""
                    val rawId = if (rawIdIdx >= 0) c.getString(rawIdIdx) else ""
                    val name = (if (nameIdx >= 0) c.getString(nameIdx) else null)?.trim() ?: "Sin nombre"
                    val data1 = (if (data1Idx >= 0) c.getString(data1Idx) else null)?.trim() ?: ""
                    val mime = if (mimeIdx >= 0) c.getString(mimeIdx) ?: "" else ""
                    val accountType = if (accountTypeIdx >= 0) c.getString(accountTypeIdx) ?: "" else ""
                    val isBusiness = mime.contains("w4b")

                    val jid = data1.takeIf {
                        it.endsWith("@s.whatsapp.net", ignoreCase = true) || it.endsWith("@g.us", ignoreCase = true)
                    }.orEmpty()
                    val cleanNumber = (jid.ifBlank { data1 }).substringBefore("@").filter(Char::isDigit)
                    val identityKey = jid.ifBlank { "$mime:$cleanNumber" }

                    if (cleanNumber.length < 7 || !seenJids.add(identityKey)) continue
                    seenNumbers.add(cleanNumber)

                    contacts.add(
                        mapOf(
                            "id" to (rawId.ifBlank { id }),
                            "name" to name,
                            "number" to cleanNumber,
                            "jid" to jid,
                            "isBusiness" to isBusiness,
                            "isGroup" to jid.endsWith("@g.us", ignoreCase = true),
                            "packageName" to if (isBusiness) "com.whatsapp.w4b" else "com.whatsapp",
                            "accountType" to accountType,
                            "verificationSource" to "contacts_provider_whatsapp_mime",
                            "isWhatsAppVerified" to true,
                        ),
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error consultando contactos de WhatsApp: ${e.message}")
        }
    }

    private fun queryGeneralPhoneContacts(
        context: Context,
        contacts: MutableList<Map<String, Any>>,
        seenJids: MutableSet<String>,
        seenNumbers: MutableSet<String>,
    ) {
        val phoneProjection = arrayOf(
            ContactsContract.CommonDataKinds.Phone._ID,
            ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
        )
        val phoneSort = "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} COLLATE NOCASE ASC"

        try {
            context.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                phoneProjection,
                null,
                null,
                phoneSort,
            )?.use { pc ->
                val pIdIdx = pc.getColumnIndex(ContactsContract.CommonDataKinds.Phone._ID)
                val pContactIdIdx = pc.getColumnIndex(ContactsContract.CommonDataKinds.Phone.CONTACT_ID)
                val pNameIdx = pc.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                val pNumIdx = pc.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)

                while (pc.moveToNext()) {
                    val rawNum = if (pNumIdx >= 0) pc.getString(pNumIdx) else null
                    val digits = rawNum?.filter { it.isDigit() } ?: ""
                    if (digits.length < 7 || digits in seenNumbers) continue

                    val contactKey = "phonebook:$digits"
                    if (!seenJids.add(contactKey)) continue

                    val pId = if (pIdIdx >= 0) pc.getString(pIdIdx) else ""
                    val pContactId = if (pContactIdIdx >= 0) pc.getString(pContactIdIdx) else ""
                    val pName = (if (pNameIdx >= 0) pc.getString(pNameIdx) else null)?.trim() ?: "Sin nombre"

                    contacts.add(
                        mapOf(
                            "id" to (pContactId.ifBlank { pId }),
                            "name" to pName,
                            "number" to digits,
                            "jid" to "",
                            "isBusiness" to false,
                            "isGroup" to false,
                            "packageName" to "",
                            "accountType" to "",
                            "verificationSource" to "phonebook",
                            "isWhatsAppVerified" to false,
                        ),
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error consultando contactos telefónicos: ${e.message}")
        }
    }
}
