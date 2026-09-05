package dev.nanoai.mobile

import android.app.Application
import android.content.Context
import dev.nanoai.mobile.automation.AutomationStoreDb
import dev.nanoai.mobile.automation.DurableInbox

/**
 * WA-PROD-01/02 — scope de Application: el runtime nativo, la cola durable
 * de eventos y el store de estado de automatización dejan de pertenecer a
 * MainActivity. Los supervisores se crean una vez por proceso y se
 * arrancan/apagan por demanda de sus requestors (UI y runtime de
 * automatización); el inbox y el store son dueños únicos de escritura.
 */
class NanoApplication : Application() {
    val runtimeScope: RuntimeScope by lazy { RuntimeScope(this) }
    val durableInbox: DurableInbox by lazy { DurableInbox(this) }
    val automationStoreDb: AutomationStoreDb by lazy { AutomationStoreDb(this) }

    companion object {
        fun from(context: Context): NanoApplication =
            context.applicationContext as NanoApplication
    }
}
