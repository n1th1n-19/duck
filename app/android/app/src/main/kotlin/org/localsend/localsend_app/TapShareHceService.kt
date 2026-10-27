package org.localsend.localsend_app

import android.app.KeyguardManager
import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.net.Inet4Address
import java.net.NetworkInterface

private const val TAG = "TapShare"

private val SW_OK = byteArrayOf(0x90.toByte(), 0x00)
private val SW_NOT_FOUND = byteArrayOf(0x6A, 0x82.toByte())
private val SW_INS_NOT_SUPPORTED = byteArrayOf(0x6D, 0x00)
private val SW_WRONG_DATA = byteArrayOf(0x6A, 0x80.toByte())

// Must match TapShareIdentity in Dart: the response has to fit into one short APDU.
private const val MAX_IPS = 3
private const val MAX_IDENTITY_BYTES = 240

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

        val identity = TapShareState.getIdentity(this)?.let(::withCurrentIps) ?: return SW_NOT_FOUND
        val senderFingerprint = try {
            val lc = apdu[4].toInt() and 0xFF
            JSONObject(String(apdu, 5, lc, Charsets.UTF_8)).getString("f")
        } catch (e: Exception) {
            Log.w(TAG, "Invalid exchange command", e)
            return SW_WRONG_DATA
        }

        val unlocked = !(getSystemService(KEYGUARD_SERVICE) as KeyguardManager).isKeyguardLocked
        Log.d(TAG, "Tapped by $senderFingerprint (unlocked: $unlocked)")
        TapShareState.recordTap(senderFingerprint, unlocked)
        Handler(Looper.getMainLooper()).post {
            TapShareState.onTapped?.invoke(senderFingerprint)
            // App closed or in the background: boot the server and keep the process awake for the upload.
            if (!MainActivity.isVisible) {
                TapShareWakeService.start(this)
            }
        }

        return identity.toByteArray(Charsets.UTF_8) + SW_OK
    }

    override fun onDeactivated(reason: Int) {}

    /// The stored identity was written by Dart, possibly long ago; the addresses may have changed since.
    private fun withCurrentIps(identity: String): String {
        val ips = localIps()
        if (ips.isEmpty()) {
            return identity
        }
        val json = JSONObject(identity)
        for (count in minOf(ips.size, MAX_IPS) downTo 1) {
            json.put("i", JSONArray(ips.take(count)))
            val encoded = json.toString()
            if (encoded.toByteArray(Charsets.UTF_8).size <= MAX_IDENTITY_BYTES) {
                return encoded
            }
        }
        return identity
    }

    /// Local network IPv4 addresses, Wi-Fi first.
    private fun localIps(): List<String> = try {
        NetworkInterface.getNetworkInterfaces().toList()
            .filter { it.isUp && !it.isLoopback }
            .sortedBy { if (it.name.startsWith("wlan")) 0 else 1 }
            .flatMap { it.inetAddresses.toList() }
            .filterIsInstance<Inet4Address>()
            .filter { it.isSiteLocalAddress || it.isLinkLocalAddress }
            .mapNotNull { it.hostAddress }
            .distinct()
    } catch (e: Exception) {
        Log.w(TAG, "Reading local addresses failed", e)
        emptyList()
    }
}
