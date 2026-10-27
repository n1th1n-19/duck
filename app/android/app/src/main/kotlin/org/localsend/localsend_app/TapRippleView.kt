package org.localsend.localsend_app

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.provider.Settings
import android.util.AttributeSet
import android.view.View
import android.view.animation.LinearInterpolator

/**
 * Rings that keep spreading from the center while waiting for a tap, like iOS AirDrop.
 * Flat color, no gradients. Static when the system has animations turned off.
 */
class TapRippleView @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = context.getColor(R.color.tap_share_accent)
    }
    private var progress = 0f
    private val animator = ValueAnimator.ofFloat(0f, 1f).apply {
        duration = 2_000
        repeatCount = ValueAnimator.INFINITE
        interpolator = LinearInterpolator()
        addUpdateListener {
            progress = it.animatedValue as Float
            invalidate()
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        val animationsOn = Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) != 0f
        if (animationsOn) {
            animator.start()
        } else {
            progress = 0.5f
        }
    }

    override fun onDetachedFromWindow() {
        animator.cancel()
        super.onDetachedFromWindow()
    }

    override fun onDraw(canvas: Canvas) {
        val cx = width / 2f
        val cy = height / 2f
        val maxRadius = minOf(width, height) / 2f
        val stroke = maxRadius * 0.06f
        paint.strokeWidth = stroke
        for (i in 0 until RINGS) {
            val t = (progress + i.toFloat() / RINGS) % 1f
            paint.alpha = ((1f - t) * 255).toInt()
            canvas.drawCircle(cx, cy, stroke + (maxRadius - stroke) * t, paint)
        }
    }

    private companion object {
        const val RINGS = 3
    }
}
