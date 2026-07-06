package com.campuslife.campuslife

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Watches for LINE notifications so bank official-account consumption
 * messages can be auto-parsed into transactions. Bank-specific field parsing
 * lives entirely in Dart ([BankNotifyService] / parsers) so this only does
 * package filtering and text extraction — everything else is decided on the
 * Flutter side, same as the screenshot+OCR import path.
 */
class BankNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val LINE_PACKAGE = "jp.naver.line.android"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName != LINE_PACKAGE) return

        val extras = sbn.notification.extras
        val title = extras.getCharSequence("android.title")?.toString() ?: return
        val text = (extras.getCharSequence("android.bigText") ?: extras.getCharSequence("android.text"))
            ?.toString() ?: return

        BankNotificationBridge.send(title, text)
    }
}
