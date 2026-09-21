package dev.nanoai.mobile.channels

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.provider.ContactsContract
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class ContactsChannelHandler(
    private val activity: Activity,
    private val ioScope: CoroutineScope,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.nanoai/contacts"
        const val REQ_CODE_CONTACTS = 1005

        private const val WHATSAPP_MIME_PERSONAL = "vnd.android.cursor.item/vnd.com.whatsapp.profile"
        private const val WHATSAPP_MIME_BUSINESS = "vnd.android.cursor.item/vnd.com.whatsapp.w4b.profile"
    }

    private var pendingPermissionResult: MethodChannel.Result? = null

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode == REQ_CODE_CONTACTS) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
            return true
        }
        return false
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasContactsPermission" -> {
                val has = ContextCompat.checkSelfPermission(
                    activity,
                    Manifest.permission.READ_CONTACTS,
                ) == PackageManager.PERMISSION_GRANTED
                result.success(has)
            }
            "requestContactsPermission" -> {
                val has = ContextCompat.checkSelfPermission(
                    activity,
                    Manifest.permission.READ_CONTACTS,
                ) == PackageManager.PERMISSION_GRANTED
                if (has) {
                    result.success(true)
                } else {
                    pendingPermissionResult = result
                    ActivityCompat.requestPermissions(
                        activity,
                        arrayOf(Manifest.permission.READ_CONTACTS),
                        REQ_CODE_CONTACTS,
                    )
                }
            }
            "getWhatsAppContacts" -> {
                val has = ContextCompat.checkSelfPermission(
                    activity,
                    Manifest.permission.READ_CONTACTS,
                ) == PackageManager.PERMISSION_GRANTED
                if (!has) {
                    result.error("permission_denied", "Permiso READ_CONTACTS no concedido", null)
                    return
                }
                ioScope.launch {
                    val contacts = queryWhatsAppContacts()
                    withContext(Dispatchers.Main) {
                        result.success(contacts)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun queryWhatsAppContacts(): List<Map<String, Any>> {
        val contacts = mutableListOf<Map<String, Any>>()
        val seenJids = mutableSetOf<String>()

        val projection = arrayOf(
            ContactsContract.Data._ID,
            ContactsContract.Data.RAW_CONTACT_ID,
            ContactsContract.Data.DISPLAY_NAME,
            ContactsContract.Data.DATA1,
            ContactsContract.Data.MIMETYPE,
        )

        val selection = "${ContactsContract.Data.MIMETYPE} IN (?, ?)"
        val selectionArgs = arrayOf(WHATSAPP_MIME_PERSONAL, WHATSAPP_MIME_BUSINESS)
        val sortOrder = "${ContactsContract.Data.DISPLAY_NAME} COLLATE NOCASE ASC"

        try {
            val cursor = activity.contentResolver.query(
                ContactsContract.Data.CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                sortOrder,
            )

            cursor?.use { c ->
                val idIdx = c.getColumnIndex(ContactsContract.Data._ID)
                val rawIdIdx = c.getColumnIndex(ContactsContract.Data.RAW_CONTACT_ID)
                val nameIdx = c.getColumnIndex(ContactsContract.Data.DISPLAY_NAME)
                val data1Idx = c.getColumnIndex(ContactsContract.Data.DATA1)
                val mimeIdx = c.getColumnIndex(ContactsContract.Data.MIMETYPE)

                while (c.moveToNext()) {
                    val id = if (idIdx >= 0) c.getString(idIdx) else ""
                    val rawId = if (rawIdIdx >= 0) c.getString(rawIdIdx) else ""
                    val name = (if (nameIdx >= 0) c.getString(nameIdx) else null)?.trim() ?: "Sin nombre"
                    val data1 = (if (data1Idx >= 0) c.getString(data1Idx) else null)?.trim() ?: ""
                    val mime = if (mimeIdx >= 0) c.getString(mimeIdx) ?: "" else ""
                    val isBusiness = mime.contains("w4b")

                    val jid = if (data1.contains("@s.whatsapp.net") || data1.contains("@g.us")) {
                        data1
                    } else {
                        val digits = data1.filter { it.isDigit() }
                        if (digits.isNotBlank()) "$digits@s.whatsapp.net" else if (data1.isNotBlank()) "$data1@s.whatsapp.net" else ""
                    }

                    if (jid.isBlank() || !seenJids.add(jid)) {
                        continue
                    }

                    val cleanNumber = jid.substringBefore("@")

                    contacts.add(
                        mapOf(
                            "id" to (rawId.ifBlank { id }),
                            "name" to name,
                            "number" to cleanNumber,
                            "jid" to jid,
                            "isBusiness" to isBusiness,
                        ),
                    )
                }
            }
        } catch (e: Exception) {
            // Log honesto
            android.util.Log.e("ContactsChannel", "Error consultando contactos de WhatsApp: ${e.message}")
        }

        // 2. Consulta de contactos telefónicos generales del dispositivo (garantiza conocer todos los contactos agregados)
        try {
            val phoneProjection = arrayOf(
                ContactsContract.CommonDataKinds.Phone._ID,
                ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER,
            )
            val phoneSort = "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} COLLATE NOCASE ASC"
            activity.contentResolver.query(
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
                    if (digits.length < 7) continue

                    val jid = "$digits@s.whatsapp.net"
                    if (!seenJids.add(jid)) continue

                    val pId = if (pIdIdx >= 0) pc.getString(pIdIdx) else ""
                    val pContactId = if (pContactIdIdx >= 0) pc.getString(pContactIdIdx) else ""
                    val pName = (if (pNameIdx >= 0) pc.getString(pNameIdx) else null)?.trim() ?: "Sin nombre"

                    contacts.add(
                        mapOf(
                            "id" to (pContactId.ifBlank { pId }),
                            "name" to pName,
                            "number" to digits,
                            "jid" to jid,
                            "isBusiness" to false,
                        )
                    )
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("ContactsChannel", "Error consultando contactos telefónicos: ${e.message}")
        }

        return contacts
    }
}

