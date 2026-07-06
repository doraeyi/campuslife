package com.campuslife.campuslife

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Hands notifications captured by [BankNotificationListenerService] over to
 * whichever Dart isolate is currently listening on the EventChannel. Only
 * covers the case where the app process is alive (foreground or recently
 * backgrounded) — there is no headless-engine fallback for when Android has
 * fully killed the process, so delivery isn't guaranteed in that case.
 */
object BankNotificationBridge {
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun attach(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun send(title: String, text: String) {
        if (eventSink == null) return
        mainHandler.post {
            eventSink?.success(mapOf("title" to title, "text" to text))
        }
    }
}
