package org.localsend.localsend_app

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.provider.Settings
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

/**
 * Quick Settings toggle for "Tap to share".
 * Runs in the main process (unlike [QuickTileService]) so it shares [TapShareState] with the HCE service.
 */
@RequiresApi(Build.VERSION_CODES.N)
class TapShareTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }

    override fun onClick() {
        super.onClick()
        if (!TapShareState.isNfcOn(this)) {
            openNfcSettings()
            return
        }
        TapShareState.setEnabled(this, !TapShareState.isEnabled(this))
        updateTile()
    }

    private fun updateTile() {
        val tile = qsTile ?: return
        tile.icon = Icon.createWithResource(this, R.drawable.ic_tap_share)
        tile.label = "Tap to share"
        val nfcOn = TapShareState.isNfcOn(this)
        tile.state = when {
            !TapShareState.isNfcAvailable(this) -> Tile.STATE_UNAVAILABLE
            nfcOn && TapShareState.isEnabled(this) -> Tile.STATE_ACTIVE
            else -> Tile.STATE_INACTIVE
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = if (nfcOn) null else "Turn on NFC"
        }
        tile.updateTile()
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    private fun openNfcSettings() {
        val intent = Intent(Settings.ACTION_NFC_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE))
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
