package dev.nanoai.mobile.channels

import android.Manifest
import android.app.Activity
import android.content.Intent
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

/**
 * Canal de comunicación con Flutter para gestión de contactos e intenciones de WhatsApp.
 *
 * QUÉ HACE:
 * - Valida y solicita permisos de contactos (READ_CONTACTS).
 * - Despacha la consulta completa de contactos hacia ContactsProviderQuery.
 * - Soporta el modo ACTION_PICK para seleccionar contactos individuales sin permiso global.
 * - Detecta si WhatsApp Personal o WhatsApp Business están instalados en el sistema.
 *
 * CÓMO FUNCIONA:
 * - Implementa MethodChannel.MethodCallHandler sobre "com.nanoai/contacts".
 * - Resuelve asíncronamente en Dispatchers.IO las consultas de cursor.
 *
 * POR QUÉ:
 * - Cumple el principio SOLID de responsabilidad única (SRP < 150 líneas).
 */
class ContactsChannelHandler(
    private val activity: Activity,
    private val ioScope: CoroutineScope,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.nanoai/contacts"
        const val REQ_CODE_CONTACTS = 1005
        const val REQ_CODE_PICK_CONTACT = 1006

        private const val PKG_WHATSAPP_PERSONAL = "com.whatsapp"
        private const val PKG_WHATSAPP_BUSINESS = "com.whatsapp.w4b"
    }

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingPickResult: MethodChannel.Result? = null

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

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQ_CODE_PICK_CONTACT) {
            val result = pendingPickResult
            pendingPickResult = null
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                result?.success(null)
                return true
            }
            val uri = data.data!!
            ioScope.launch {
                val contactMap = PickedContactResolver.resolvePickedContact(activity, uri)
                withContext(Dispatchers.Main) {
                    result?.success(contactMap)
                }
            }
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
                    val contacts = ContactsProviderQuery.queryAllContacts(activity)
                    withContext(Dispatchers.Main) {
                        result.success(contacts)
                    }
                }
            }
            "pickSingleContact" -> {
                pendingPickResult = result
                try {
                    val pickIntent = Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI)
                    activity.startActivityForResult(pickIntent, REQ_CODE_PICK_CONTACT)
                } catch (e: Exception) {
                    pendingPickResult = null
                    result.error("pick_error", "No se pudo abrir el selector del sistema: ${e.message}", null)
                }
            }
            "getInstalledWhatsAppPackages" -> {
                val pm = activity.packageManager
                val installed = mutableMapOf<String, Boolean>()
                installed["personal"] = isPackageInstalled(pm, PKG_WHATSAPP_PERSONAL)
                installed["business"] = isPackageInstalled(pm, PKG_WHATSAPP_BUSINESS)
                result.success(installed)
            }
            "showQuickContact" -> {
                val contactId = call.argument<String>("contactId").orEmpty()
                if (contactId.isNotBlank()) {
                    try {
                        val uri = android.net.Uri.withAppendedPath(ContactsContract.Contacts.CONTENT_URI, contactId)
                        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        activity.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("quick_contact_error", e.message, null)
                    }
                } else {
                    result.success(false)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun isPackageInstalled(pm: PackageManager, packageName: String): Boolean {
        return try {
            pm.getPackageInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }
}
