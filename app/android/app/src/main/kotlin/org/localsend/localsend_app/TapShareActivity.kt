package org.localsend.localsend_app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.util.Log
import android.widget.Button
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject

private const val TAG = "TapShare"

/**
 * Share target: "Hold near another phone". Sends the shared items to the tapped phone
 * without opening the app. "Open Duck" hands the share to [MainActivity] as before.
 *
 * Stays open until closed, so further phones can be tapped and the content URI grants
 * of the share (which live with this activity) stay valid during the transfer.
 */
class TapShareActivity : Activity() {
    private lateinit var reader: TapShareReader
    private lateinit var status: TextView
    private lateinit var title: TextView
    private lateinit var ripple: TapRippleView

    /// The share's content URI grants live with this activity, so it must stay while sending.
    private var sending = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val ownFingerprint = TapShareState.getIdentity(this)?.let { JSONObject(it).optString("f").ifEmpty { null } }
        val items = sharedUris().size + if (sharedText() != null) 1 else 0
        if (!TapShareState.isEnabled(this) || !TapShareState.isNfcOn(this) || ownFingerprint == null || items == 0) {
            // Tap share unavailable: the regular share flow in the app.
            openApp()
            return
        }

        setContentView(R.layout.tap_share_sheet)
        status = findViewById(R.id.status)
        title = findViewById(R.id.title)
        ripple = findViewById(R.id.ripple)
        status.text = getString(R.string.tap_share_sheet_files, items)
        findViewById<Button>(R.id.close).setOnClickListener { finish() }
        findViewById<Button>(R.id.open_app).setOnClickListener { openApp() }
        findViewById<android.view.View>(R.id.scrim).setOnClickListener { finish() }

        TapShareState.onSendResult = { alias, ok ->
            runOnUiThread {
                sending = false
                TapShareFeedback.vibrate(this, if (ok) TapShareFeedback.Kind.SUCCESS else TapShareFeedback.Kind.FAILURE)
                ripple.visibility = android.view.View.INVISIBLE
                title.setText(if (ok) R.string.tap_share_sheet_title_sent else R.string.tap_share_sheet_title_failed)
                title.setTextColor(getColor(if (ok) R.color.tap_share_accent else R.color.tap_share_error))
                status.text = getString(if (ok) R.string.tap_share_sheet_sent else R.string.tap_share_sheet_failed, alias)
            }
        }

        reader = TapShareReader(this, ::onRead)
        reader.setSender(ownFingerprint)
        // Boot the engine now, so it is ready by the time the phones touch.
        LocalSendApplication.obtainEngine(this, headless = true)
    }

    override fun onResume() {
        super.onResume()
        if (::reader.isInitialized) {
            reader.apply()
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && ::reader.isInitialized) {
            reader.rearm()
        }
    }

    /// singleTask: a new share replaces the items of the open sheet instead of stacking sheets.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (!::status.isInitialized) {
            return
        }
        val items = sharedUris().size + if (sharedText() != null) 1 else 0
        ripple.visibility = android.view.View.VISIBLE
        title.setText(R.string.tap_share_sheet_title)
        title.setTextColor(status.currentTextColor)
        status.text = getString(R.string.tap_share_sheet_files, items)
    }

    override fun onPause() {
        super.onPause()
        if (::reader.isInitialized) {
            reader.pause()
        }
    }

    /// Left without sending: close, so no hidden sheet keeps NFC in reader mode.
    override fun onStop() {
        super.onStop()
        if (!sending && !isChangingConfigurations) {
            finish()
        }
    }

    override fun onDestroy() {
        TapShareState.onSendResult = null
        super.onDestroy()
    }

    private fun onRead(identity: String) {
        val alias = JSONObject(identity).optString("a")
        TapShareFeedback.vibrate(this, TapShareFeedback.Kind.TAP)
        sending = true
        // A further phone after a finished send: back to the waiting look.
        ripple.visibility = android.view.View.VISIBLE
        title.setText(R.string.tap_share_sheet_title_sending)
        title.setTextColor(status.currentTextColor)
        status.text = getString(R.string.tap_share_sheet_sending, alias)

        val files = JSONArray()
        for (uri in sharedUris()) {
            files.put(describe(uri) ?: continue)
        }
        TapShareState.pendingSend = JSONObject()
            .put("identity", identity)
            .put("files", files)
            .put("text", sharedText())
            .toString()
        LocalSendApplication.obtainEngine(this, headless = true)
        TapShareChannel.notifySendPending()
    }

    private fun openApp() {
        startActivity(
            Intent(intent)
                .setClass(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        )
        finish()
    }

    @Suppress("DEPRECATION")
    private fun sharedUris(): List<Uri> = when (intent.action) {
        Intent.ACTION_SEND -> listOfNotNull(
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            else intent.getParcelableExtra(Intent.EXTRA_STREAM)
        )

        Intent.ACTION_SEND_MULTIPLE ->
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            else intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)) ?: emptyList()

        else -> emptyList()
    }

    /// Shared text (e.g. a link), unless it only describes attached files.
    private fun sharedText(): String? =
        if (intent.action == Intent.ACTION_SEND && sharedUris().isEmpty()) intent.getStringExtra(Intent.EXTRA_TEXT)?.ifBlank { null } else null

    private fun describe(uri: Uri): JSONObject? = try {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { cursor ->
            if (!cursor.moveToFirst()) return null
            JSONObject()
                .put("uri", uri.toString())
                .put("name", cursor.getString(0) ?: uri.lastPathSegment ?: "file")
                .put("size", if (cursor.isNull(1)) 0 else cursor.getLong(1))
        }
    } catch (e: Exception) {
        Log.w(TAG, "Cannot read $uri", e)
        null
    }
}
