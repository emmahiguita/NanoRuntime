package dev.nanoai.mobile.services

import android.app.Activity
import android.app.Instrumentation
import android.app.Notification
import android.app.PendingIntent
import android.app.RemoteInput
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * Instrumentación E2E local del transporte RemoteInput. La acción termina en
 * un receiver efímero del APK bajo prueba; nunca abre WhatsApp ni usa un
 * contacto real.
 */
class RemoteInputFixtureInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        start()
    }

    override fun onStart() {
        val output = Bundle()
        try {
            runFixture(targetContext)
            output.putString("stream", "RemoteInput fixture: PASS\n")
            finish(Activity.RESULT_OK, output)
        } catch (error: Throwable) {
            output.putString(
                "stream",
                "RemoteInput fixture: FAIL ${error.message}\n",
            )
            finish(Activity.RESULT_CANCELED, output)
        }
    }

    private fun runFixture(context: Context) {
        val actionName = "${context.packageName}.REMOTE_INPUT_FIXTURE.${UUID.randomUUID()}"
        val resultKey = "fixture_reply"
        val expectedText = "respuesta local segura"
        val receivedText = AtomicReference<String>()
        val delivered = CountDownLatch(1)
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val results = intent?.let(RemoteInput::getResultsFromIntent)
                receivedText.set(results?.getCharSequence(resultKey)?.toString())
                delivered.countDown()
            }
        }

        registerFixtureReceiver(context, receiver, IntentFilter(actionName))
        try {
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE
                } else {
                    0
                }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                7301,
                Intent(actionName).setPackage(context.packageName),
                flags,
            )
            val remoteInput = RemoteInput.Builder(resultKey)
                .setAllowFreeFormInput(true)
                .build()
            val action = Notification.Action.Builder(
                0,
                "Responder fixture",
                pendingIntent,
            ).addRemoteInput(remoteInput).build()
            val fixtureNotification = Notification.Builder(context, "fixture-only")
                .setSmallIcon(android.R.drawable.stat_notify_chat)
                .setContentTitle("Fixture local")
                .addAction(action)
                .build()

            val result = RemoteInputReplySender.send(
                context,
                fixtureNotification.actions.single(),
                expectedText,
            )

            check(result.ok) { "dispatch=${result.code}" }
            check(result.code == "REMOTE_INPUT_ACCEPTED") { result.code }
            check(delivered.await(3, TimeUnit.SECONDS)) { "receiver timeout" }
            check(receivedText.get() == expectedText) {
                "texto recibido=${receivedText.get()}"
            }
        } finally {
            context.unregisterReceiver(receiver)
        }
    }

    private fun registerFixtureReceiver(
        context: Context,
        receiver: BroadcastReceiver,
        filter: IntentFilter,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            context.registerReceiver(receiver, filter)
        }
    }
}
