package org.localsend.localsend_app

import android.app.Activity
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONObject

private const val TAG = "TapShare"
private const val DEDUPE_MS = 3000L

/**
 * Sender side of "Tap to share": NFC reader mode that reads the identity of a phone running [TapShareHceService].
 */
class TapShareReader(
    private val activity: Activity,
    private val onRead: (String) -> Unit,
) {
    private var senderJson: String? = null
    private var lastFingerprint: String? = null
    private var lastReadAt = 0L

    /// [senderFingerprint] null disables reading.
    fun setSender(senderFingerprint: String?) {
        senderJson = senderFingerprint?.let { JSONObject().put("v", 1).put("f", it).toString() }
        apply()
    }

    /// Reader mode only works while the activity is resumed, so call this from onResume as well.
    fun apply() {
        val adapter = NfcAdapter.getDefaultAdapter(activity) ?: return
        try {
            if (senderJson != null) {
                adapter.enableReaderMode(
                    activity,
                    ::onTag,
                    NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK or NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS,
                    null,
                )
            } else {
                adapter.disableReaderMode(activity)
            }
        } catch (e: IllegalStateException) {
            // Activity not resumed; onResume calls apply() again.
        }
    }

    fun pause() {
        try {
            NfcAdapter.getDefaultAdapter(activity)?.disableReaderMode(activity)
        } catch (_: IllegalStateException) {
        }
    }

    // Runs on a binder thread.
    private fun onTag(tag: Tag) {
        val sender = senderJson ?: return
        val isoDep = IsoDep.get(tag) ?: return
        try {
            isoDep.connect()
            isoDep.timeout = 2000

            val aid = TapShareState.AID
            val select = byteArrayOf(0x00, 0xA4.toByte(), 0x04, 0x00, aid.size.toByte()) + aid + byteArrayOf(0x00)
            if (!isOk(isoDep.transceive(select))) {
                Log.d(TAG, "Peer has no LocalSend identity (server not running?)")
                return
            }

            val data = sender.toByteArray(Charsets.UTF_8)
            val exchange = byteArrayOf(0x80.toByte(), TapShareState.INS_EXCHANGE, 0x00, 0x00, data.size.toByte()) + data + byteArrayOf(0x00)
            val response = isoDep.transceive(exchange)
            if (!isOk(response)) {
                Log.d(TAG, "Exchange failed")
                return
            }

            val identity = String(response, 0, response.size - 2, Charsets.UTF_8)
            val fingerprint = JSONObject(identity).getString("f")
            val now = System.currentTimeMillis()
            if (fingerprint == lastFingerprint && now - lastReadAt < DEDUPE_MS) {
                return
            }
            lastFingerprint = fingerprint
            lastReadAt = now

            Log.d(TAG, "Read identity of $fingerprint")
            Handler(Looper.getMainLooper()).post { onRead(identity) }
        } catch (e: Exception) {
            Log.w(TAG, "Tap read failed", e)
        } finally {
            try {
                isoDep.close()
            } catch (_: Exception) {
            }
        }
    }

    private fun isOk(response: ByteArray): Boolean =
        response.size >= 2 && response[response.size - 2] == 0x90.toByte() && response[response.size - 1] == 0x00.toByte()
}
