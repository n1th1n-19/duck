package org.localsend.localsend_app

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Vibration for tap to share. Native because the phones may run without any UI,
 * where Flutter's HapticFeedback has no view to act on.
 */
object TapShareFeedback {
    enum class Kind { TAP, SUCCESS, FAILURE }

    fun vibrate(context: Context, kind: Kind) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Vibrator::class.java)
        }
        if (!vibrator.hasVibrator()) {
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            vibrator.vibrate(
                when (kind) {
                    Kind.TAP -> VibrationEffect.createPredefined(VibrationEffect.EFFECT_HEAVY_CLICK)
                    Kind.SUCCESS -> VibrationEffect.createPredefined(VibrationEffect.EFFECT_DOUBLE_CLICK)
                    Kind.FAILURE -> VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE)
                }
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(if (kind == Kind.FAILURE) 400L else 60L)
        }
    }
}
