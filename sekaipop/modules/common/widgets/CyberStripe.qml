import QtQuick

// Reusable Cyberpunk 2077 / Anna Kuzminska HUD graphic primitive:
//   mode === "stripes" (default): diagonal 45° //////// parallelogram ticks,
//     supporting an optional `progress` (0..1) where filled ticks use `color`
//     (or `altColor` near the tip) and unfilled ticks use `trackColor`.
//   mode === "chevrons": angled >>>> or <<<< HUD chevron cluster.
//   mode === "grid": sparse '+' technical reticle calibration grid.
Canvas {
    id: root

    property string mode: "stripes"          // "stripes" | "chevrons" | "grid"
    property real progress: 1.0              // 0..1 for progress bars; 1.0 for full decorative strip
    property color color: "#00f0ff"
    property color altColor: "#fcee0a"
    property color trackColor: Qt.rgba(1, 0.165, 0.333, 0.24)
    property real barWidth: 5
    property real gap: 4
    property real slant: 0.65                // horizontal shear per px of height
    property bool reverse: false             // flip slant or chevron direction
    property int gridStep: 28                // spacing for '+' grid mode
    property real crossSize: 3               // half-arm length of '+' marks

    onModeChanged: requestPaint()
    onProgressChanged: requestPaint()
    onColorChanged: requestPaint()
    onAltColorChanged: requestPaint()
    onTrackColorChanged: requestPaint()
    onBarWidthChanged: requestPaint()
    onGapChanged: requestPaint()
    onSlantChanged: requestPaint()
    onReverseChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        if (width <= 0 || height <= 0)
            return

        if (root.mode === "grid") {
            ctx.strokeStyle = root.color
            ctx.lineWidth = 1
            const step = Math.max(12, root.gridStep)
            const arm = root.crossSize
            for (let gx = step * 0.5; gx < width; gx += step) {
                for (let gy = step * 0.5; gy < height; gy += step) {
                    const cx = Math.round(gx) + 0.5
                    const cy = Math.round(gy) + 0.5
                    ctx.beginPath()
                    ctx.moveTo(cx - arm, cy)
                    ctx.lineTo(cx + arm, cy)
                    ctx.moveTo(cx, cy - arm)
                    ctx.lineTo(cx, cy + arm)
                    ctx.stroke()
                }
            }
            return
        }

        if (root.mode === "chevrons") {
            const h = height
            const cy = h * 0.5
            const halfH = Math.max(2, h * 0.42)
            const cw = Math.max(3, halfH * 0.75)
            const step = cw + root.gap
            const count = Math.max(1, Math.floor((width - cw) / step))
            ctx.lineWidth = Math.max(1.5, root.barWidth * 0.38)
            ctx.lineCap = "square"
            ctx.lineJoin = "miter"
            for (let i = 0; i < count; i++) {
                const frac = count > 1 ? i / (count - 1) : 1
                ctx.strokeStyle = (i === count - 1 && root.altColor.a > 0) ? root.altColor : root.color
                const x0 = root.reverse ? (width - cw - i * step) : (i * step + 1)
                ctx.beginPath()
                if (root.reverse) {
                    ctx.moveTo(x0 + cw, cy - halfH)
                    ctx.lineTo(x0, cy)
                    ctx.lineTo(x0 + cw, cy + halfH)
                } else {
                    ctx.moveTo(x0, cy - halfH)
                    ctx.lineTo(x0 + cw, cy)
                    ctx.lineTo(x0, cy + halfH)
                }
                ctx.stroke()
            }
            return
        }

        // Default: "stripes" (diagonal //////// HUD ticks)
        const h = height
        const dx = (root.reverse ? -1 : 1) * h * root.slant
        const step = Math.max(2, root.barWidth + root.gap)
        const startX = dx > 0 ? 0 : -dx
        const availW = width - Math.abs(dx)
        const totalTicks = Math.max(1, Math.floor((availW + root.gap) / step))
        const p = Math.max(0, Math.min(1, root.progress))
        const litTicks = Math.round(totalTicks * p)

        for (let i = 0; i < totalTicks; i++) {
            const x = startX + i * step
            const isLit = i < litTicks
            const isTip = isLit && (i === litTicks - 1) && p < 0.99 && p > 0.01
            ctx.fillStyle = isTip ? root.altColor : (isLit ? root.color : root.trackColor)
            ctx.beginPath()
            ctx.moveTo(x + (dx > 0 ? dx : 0), 0)
            ctx.lineTo(x + (dx > 0 ? dx : 0) + root.barWidth, 0)
            ctx.lineTo(x + (dx > 0 ? 0 : -dx) + root.barWidth, h)
            ctx.lineTo(x + (dx > 0 ? 0 : -dx), h)
            ctx.closePath()
            ctx.fill()
        }
    }
}
