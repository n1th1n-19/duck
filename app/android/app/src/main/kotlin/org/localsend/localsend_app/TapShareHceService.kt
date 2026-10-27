package org.localsend.localsend_app

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONObject

private const val TAG = "TapShare"

private val SW_OK = byteArrayOf(0x90.toByte(), 0x00)
private val SW_NOT_FOUND = byteArrayOf(0x6A, 0x82.toByte())
private val SW_INS_NOT_SUPPORTED = byteArrayOf(0x6D, 0x00)
private val SW_WRONG_DATA = byteArrayOf(0x6A, 0x80.toByte())

/**
 * Receiver side of "Tap to share": emulates an ISO-DEP card answering with this device's identity.
 *
 * Android binds this service on tap, spawning the app process if needed.
 * The phone acting as sender runs NFC reader mode (see [TapShareReader]), which suppresses this service there.
 */
class TapShareHceService : HostApduService() {
    override fun processCommandApdu(apdu: ByteArray, extras: Bundle?): ByteArray {
        if (apdu.size < 4) {
            return SW_WRONG_DATA
        }

        // SELECT by AID; the system only routes it here when the AID matches.
        if (apdu[1] == 0xA4.toByte()) {
            return if (TapShareState.getIdentity(this) != null) SW_OK else SW_NOT_FOUND
        }

        if (apdu[1] != TapShareState.INS_EXCHANGE) {
            return SW_INS_NOT_SUPPORTED
        }

        val identity = TapShareState.getIdentity(this) ?: return SW_NOT_FOUND
        val senderFingerprint = try {
            val lc = apdu[4].toInt() and 0xFF
            JSONObject(String(apdu, 5, lc, Charsets.UTF_8)).getString("f")
        } catch (e: Exception) {
            Log.w(TAG, "Invalid exchange command", e)
            return SW_WRONG_DATA
        }

        Log.d(TAG, "Tapped by $senderFingerprint")
        TapShareState.recordTap(senderFingerprint)
        Handler(Looper.getMainLooper()).post { TapShareState.onTapped?.invoke(senderFingerprint) }

        return identity.toByteArray(Charsets.UTF_8) + SW_OK
    }

    override fun onDeactivated(reason: Int) {}
}
