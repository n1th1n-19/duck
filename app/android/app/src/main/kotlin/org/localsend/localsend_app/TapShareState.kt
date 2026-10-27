package org.localsend.localsend_app

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.os.Build
import android.service.quicksettings.TileService

/**
 * Native source of truth for "Tap to share".
 *
 * Lives outside Flutter because the HCE service and the Quick Settings tile
 * must work while no Flutter engine is running.
 */
object TapShareState {
    // Proprietary AID: F0 + ASCII "LOCALSEND". Must match res/xml/tap_share_apdu_service.xml.
    val AID: ByteArray = byteArrayOf(0xF0.toByte()) + "LOCALSEND".toByteArray(Charsets.US_ASCII)

    /// Custom command after SELECT: data = sender JSON, response = receiver identity JSON.
    const val INS_EXCHANGE: Byte = 0x01

    private const val PREFS = "tap_share"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_AUTO_ACCEPT = "auto_accept"
    private const val KEY_IDENTITY = "identity"

    /// Called on the main thread when a phone tapped us (sender fingerprint).
    var onTapped: ((String) -> Unit)? = null

    /// Called when [setEnabled] changed the value, so the Flutter toggle can follow the tile.
    var onEnabledChanged: ((Boolean) -> Unit)? = null

    @Volatile
    var lastTappedFingerprint: String? = null
        private set

    @Volatile
    var lastTappedAt: Long = 0
        private set

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isNfcAvailable(context: Context): Boolean =
        context.packageManager.hasSystemFeature(PackageManager.FEATURE_NFC_HOST_CARD_EMULATION) &&
            NfcAdapter.getDefaultAdapter(context) != null

    fun isNfcOn(context: Context): Boolean = NfcAdapter.getDefaultAdapter(context)?.isEnabled == true

    fun isEnabled(context: Context): Boolean = prefs(context).getBoolean(KEY_ENABLED, true)

    fun setEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_ENABLED, enabled).apply()

        // Disabling the component makes the phone stop answering taps even with the app closed.
        context.packageManager.setComponentEnabledSetting(
            ComponentName(context, TapShareHceService::class.java),
            if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            TileService.requestListeningState(context, ComponentName(context, TapShareTileService::class.java))
        }
        onEnabledChanged?.invoke(enabled)
    }

    fun isAutoAccept(context: Context): Boolean = prefs(context).getBoolean(KEY_AUTO_ACCEPT, true)

    fun setAutoAccept(context: Context, autoAccept: Boolean) {
        prefs(context).edit().putBoolean(KEY_AUTO_ACCEPT, autoAccept).apply()
    }

    /// Receiver identity JSON as sent over NFC. Null while the server is not running.
    fun getIdentity(context: Context): String? = prefs(context).getString(KEY_IDENTITY, null)

    fun setIdentity(context: Context, json: String?) {
        prefs(context).edit().putString(KEY_IDENTITY, json).apply()
    }

    fun recordTap(fingerprint: String) {
        lastTappedFingerprint = fingerprint
        lastTappedAt = System.currentTimeMillis()
    }
}
