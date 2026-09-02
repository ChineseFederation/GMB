package org.citizen.sdk.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.util.TypedValue
import android.view.View
import java.nio.CharBuffer

/** Draws recovery characters without constructing an immutable String. */
internal class CitizenSdkRecoveryContent(context: Context) : View(context), AutoCloseable {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xff111111.toInt()
        textSize = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_SP,
            18f,
            resources.displayMetrics,
        )
    }
    private var characters = CharArray(0)

    init {
        importantForAutofill = IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
        setPadding(32, 32, 32, 32)
    }

    @JvmSynthetic
    fun replace(source: CharBuffer) {
        characters.fill('\u0000')
        val copy = source.asReadOnlyBuffer()
        characters = CharArray(copy.remaining())
        copy.get(characters)
        requestLayout()
        invalidate()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val lines = (characters.count { it == ' ' } + 3) / 4
        val wanted = paddingTop + paddingBottom + (lines.coerceAtLeast(1) * paint.fontSpacing).toInt()
        setMeasuredDimension(MeasureSpec.getSize(widthMeasureSpec), resolveSize(wanted, heightMeasureSpec))
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (characters.isEmpty()) return
        val wordsPerLine = 4
        var word = 0
        var start = 0
        var baseline = paddingTop - paint.ascent()
        for (index in 0..characters.size) {
            if (index == characters.size || characters[index] == ' ') {
                val prefix = charArrayOf(
                    ('0'.code + ((word + 1) / 10)).toChar(),
                    ('0'.code + ((word + 1) % 10)).toChar(),
                    '.',
                    ' ',
                )
                val column = word % wordsPerLine
                val columnWidth = (width - paddingLeft - paddingRight).toFloat() / wordsPerLine
                val x = paddingLeft + column * columnWidth
                canvas.drawText(prefix, 0, prefix.size, x, baseline, paint)
                canvas.drawText(characters, start, index - start, x + paint.measureText(prefix, 0, prefix.size), baseline, paint)
                word += 1
                if (word % wordsPerLine == 0) baseline += paint.fontSpacing
                start = index + 1
            }
        }
    }

    override fun close() {
        characters.fill('\u0000')
        characters = CharArray(0)
        invalidate()
    }
}
