pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: stroke

    function pathOf(pts) {
        const segs = []
        let total = 0
        for (let i = 0; i < pts.length - 1; i++) {
            const dx = pts[i + 1].x - pts[i].x
            const dy = pts[i + 1].y - pts[i].y
            const len = Math.hypot(dx, dy)
            segs.push({ a: pts[i], b: pts[i + 1], len: len })
            total += len
        }
        return { segs: segs, total: total, pts: pts }
    }

    function pointAt(path, t) {
        const pts = path.pts
        let remain = path.total * Math.max(0, Math.min(1, t))
        for (let i = 0; i < path.segs.length; i++) {
            const s = path.segs[i]
            if (remain <= s.len) {
                const u = s.len > 0 ? remain / s.len : 0
                return { x: s.a.x + (s.b.x - s.a.x) * u, y: s.a.y + (s.b.y - s.a.y) * u }
            }
            remain -= s.len
        }
        return pts[pts.length - 1]
    }

    function strokePartial(ctx, path, width, color, alpha, t) {
        ctx.strokeStyle = color
        ctx.globalAlpha = alpha
        ctx.lineWidth = width
        ctx.lineCap = "round"
        ctx.lineJoin = "miter"
        ctx.miterLimit = 8
        ctx.beginPath()
        let remain = path.total * t
        let started = false
        for (let i = 0; i < path.segs.length; i++) {
            const s = path.segs[i]
            if (remain <= 0)
                break
            if (!started) {
                ctx.moveTo(s.a.x, s.a.y)
                started = true
            }
            if (remain >= s.len) {
                ctx.lineTo(s.b.x, s.b.y)
                remain -= s.len
            } else {
                const u = remain / s.len
                ctx.lineTo(s.a.x + (s.b.x - s.a.x) * u, s.a.y + (s.b.y - s.a.y) * u)
                remain = 0
            }
        }
        ctx.stroke()
        ctx.globalAlpha = 1
    }

    function draw(ctx, pts, t, color) {
        const path = stroke.pathOf(pts)
        if (path.total < 1)
            return false
        stroke.strokePartial(ctx, path, 5.2, color, 0.14, t)
        stroke.strokePartial(ctx, path, 2.15, color, 0.96, t)
        const head = stroke.pointAt(path, t)
        ctx.fillStyle = color
        ctx.globalAlpha = 0.96
        ctx.save()
        ctx.translate(head.x, head.y)
        ctx.rotate(Math.PI / 4)
        ctx.fillRect(-2.6, -2.6, 5.2, 5.2)
        ctx.restore()
        ctx.globalAlpha = 1
        return true
    }
}
