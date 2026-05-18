import SwiftUI
import CoreGraphics

/// Minimal SVG path-data → CGPath. Supports M m L l H h V v C c S s Q q T t A a Z z
/// (absolute/relative, implicit repeats, elliptical arcs). Enough for the
/// Bootstrap-icon glyphs ported from the PWA.
enum SVGPath {
    /// Command-aware scanner.
    static func scan(_ d: String) -> CGPath {
        let path = CGMutablePath()
        let scalars = Array(d)
        var idx = 0
        var cur = CGPoint.zero
        var startPt = CGPoint.zero
        var prevCubicCtrl: CGPoint?
        var prevQuadCtrl: CGPoint?
        var cmd: Character = " "

        func skipSep() {
            while idx < scalars.count, scalars[idx] == " " || scalars[idx] == "," || scalars[idx] == "\n" || scalars[idx] == "\t" || scalars[idx] == "\r" { idx += 1 }
        }
        func readNumber() -> CGFloat {
            skipSep()
            var s = ""
            if idx < scalars.count, scalars[idx] == "-" || scalars[idx] == "+" { s.append(scalars[idx]); idx += 1 }
            while idx < scalars.count {
                let c = scalars[idx]
                if c.isNumber || c == "." { s.append(c); idx += 1 }
                else if (c == "e" || c == "E") { s.append(c); idx += 1; if idx < scalars.count, scalars[idx] == "-" || scalars[idx] == "+" { s.append(scalars[idx]); idx += 1 } }
                else if c == "-" && !s.isEmpty { break }     // start of next number
                else { break }
            }
            return CGFloat(Double(s) ?? 0)
        }
        func readFlag() -> Bool { skipSep(); let c = scalars[idx]; idx += 1; return c == "1" }
        func peekIsCommand() -> Bool {
            skipSep()
            guard idx < scalars.count else { return false }
            return scalars[idx].isLetter
        }

        while idx < scalars.count {
            skipSep()
            guard idx < scalars.count else { break }
            if scalars[idx].isLetter { cmd = scalars[idx]; idx += 1 }

            switch cmd {
            case "M", "m":
                var x = readNumber(); var y = readNumber()
                if cmd == "m" { x += cur.x; y += cur.y }
                cur = CGPoint(x: x, y: y); startPt = cur
                path.move(to: cur)
                cmd = (cmd == "m") ? "l" : "L"
                while !peekIsCommand() && idx < scalars.count {
                    var lx = readNumber(); var ly = readNumber()
                    if cmd == "l" { lx += cur.x; ly += cur.y }
                    cur = CGPoint(x: lx, y: ly); path.addLine(to: cur)
                }
            case "L", "l":
                while !peekIsCommand() && idx < scalars.count {
                    var x = readNumber(); var y = readNumber()
                    if cmd == "l" { x += cur.x; y += cur.y }
                    cur = CGPoint(x: x, y: y); path.addLine(to: cur)
                }
            case "H", "h":
                while !peekIsCommand() && idx < scalars.count {
                    var x = readNumber(); if cmd == "h" { x += cur.x }
                    cur = CGPoint(x: x, y: cur.y); path.addLine(to: cur)
                }
            case "V", "v":
                while !peekIsCommand() && idx < scalars.count {
                    var y = readNumber(); if cmd == "v" { y += cur.y }
                    cur = CGPoint(x: cur.x, y: y); path.addLine(to: cur)
                }
            case "C", "c":
                while !peekIsCommand() && idx < scalars.count {
                    var c1 = CGPoint(x: readNumber(), y: readNumber())
                    var c2 = CGPoint(x: readNumber(), y: readNumber())
                    var e  = CGPoint(x: readNumber(), y: readNumber())
                    if cmd == "c" { c1 = add(c1, cur); c2 = add(c2, cur); e = add(e, cur) }
                    path.addCurve(to: e, control1: c1, control2: c2)
                    prevCubicCtrl = c2; cur = e
                }
            case "S", "s":
                while !peekIsCommand() && idx < scalars.count {
                    var c2 = CGPoint(x: readNumber(), y: readNumber())
                    var e  = CGPoint(x: readNumber(), y: readNumber())
                    if cmd == "s" { c2 = add(c2, cur); e = add(e, cur) }
                    let c1 = prevCubicCtrl.map { CGPoint(x: 2*cur.x - $0.x, y: 2*cur.y - $0.y) } ?? cur
                    path.addCurve(to: e, control1: c1, control2: c2)
                    prevCubicCtrl = c2; cur = e
                }
            case "Q", "q":
                while !peekIsCommand() && idx < scalars.count {
                    var c = CGPoint(x: readNumber(), y: readNumber())
                    var e = CGPoint(x: readNumber(), y: readNumber())
                    if cmd == "q" { c = add(c, cur); e = add(e, cur) }
                    path.addQuadCurve(to: e, control: c)
                    prevQuadCtrl = c; cur = e
                }
            case "T", "t":
                while !peekIsCommand() && idx < scalars.count {
                    var e = CGPoint(x: readNumber(), y: readNumber())
                    if cmd == "t" { e = add(e, cur) }
                    let c = prevQuadCtrl.map { CGPoint(x: 2*cur.x - $0.x, y: 2*cur.y - $0.y) } ?? cur
                    path.addQuadCurve(to: e, control: c)
                    prevQuadCtrl = c; cur = e
                }
            case "A", "a":
                while !peekIsCommand() && idx < scalars.count {
                    let rx = readNumber(), ry = readNumber(), rot = readNumber()
                    let large = readFlag(), sweep = readFlag()
                    var e = CGPoint(x: readNumber(), y: readNumber())
                    if cmd == "a" { e = add(e, cur) }
                    addArc(path, from: cur, to: e, rx: rx, ry: ry, xRot: rot, largeArc: large, sweep: sweep)
                    cur = e
                }
            case "Z", "z":
                path.closeSubpath(); cur = startPt
            default:
                idx += 1
            }
        }
        return path
    }

    private static func add(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }

    /// Endpoint-parameterised elliptical arc → center param → cubic beziers.
    private static func addArc(_ path: CGMutablePath, from p0: CGPoint, to p1: CGPoint,
                               rx rxIn: CGFloat, ry ryIn: CGFloat, xRot: CGFloat,
                               largeArc: Bool, sweep: Bool) {
        if p0 == p1 { return }
        var rx = abs(rxIn), ry = abs(ryIn)
        if rx < 1e-6 || ry < 1e-6 { path.addLine(to: p1); return }
        let phi = xRot * .pi / 180
        let cosP = cos(phi), sinP = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1p = cosP*dx + sinP*dy
        let y1p = -sinP*dx + cosP*dy
        var lambda = (x1p*x1p)/(rx*rx) + (y1p*y1p)/(ry*ry)
        if lambda > 1 { let s = sqrt(lambda); rx *= s; ry *= s; lambda = 1 }
        let sign: CGFloat = (largeArc != sweep) ? 1 : -1
        let num = max(0, rx*rx*ry*ry - rx*rx*y1p*y1p - ry*ry*x1p*x1p)
        let den = rx*rx*y1p*y1p + ry*ry*x1p*x1p
        guard den > 1e-12 else { path.addLine(to: p1); return }
        let co = sign * sqrt(num / den)
        let cxp = co * (rx*y1p/ry)
        let cyp = co * (-ry*x1p/rx)
        let cx = cosP*cxp - sinP*cyp + (p0.x + p1.x)/2
        let cy = sinP*cxp + cosP*cyp + (p0.y + p1.y)/2
        func ang(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux*vx + uy*vy
            let len = sqrt((ux*ux+uy*uy)*(vx*vx+vy*vy))
            var a = acos(max(-1, min(1, dot/len)))
            if ux*vy - uy*vx < 0 { a = -a }
            return a
        }
        let theta1 = ang(1, 0, (x1p-cxp)/rx, (y1p-cyp)/ry)
        var dTheta = ang((x1p-cxp)/rx, (y1p-cyp)/ry, (-x1p-cxp)/rx, (-y1p-cyp)/ry)
        if !sweep && dTheta > 0 { dTheta -= 2 * .pi }
        if sweep && dTheta < 0 { dTheta += 2 * .pi }
        guard cx.isFinite, cy.isFinite, theta1.isFinite, dTheta.isFinite, dTheta != 0 else {
            path.addLine(to: p1); return
        }

        let segs = Int(ceil(abs(dTheta) / (.pi/2)))
        let delta = dTheta / CGFloat(segs)
        let t = 4.0/3.0 * tan(delta/4)
        var ang0 = theta1
        for _ in 0..<segs {
            let ang1 = ang0 + delta
            let p0e = ellipsePoint(cx, cy, rx, ry, cosP, sinP, ang0)
            let p1e = ellipsePoint(cx, cy, rx, ry, cosP, sinP, ang1)
            let d0 = ellipseDeriv(rx, ry, cosP, sinP, ang0)
            let d1 = ellipseDeriv(rx, ry, cosP, sinP, ang1)
            let c1 = CGPoint(x: p0e.x + t*d0.x, y: p0e.y + t*d0.y)
            let c2 = CGPoint(x: p1e.x - t*d1.x, y: p1e.y - t*d1.y)
            path.addCurve(to: p1e, control1: c1, control2: c2)
            ang0 = ang1
        }
    }

    private static func ellipsePoint(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat,
                                     _ cosP: CGFloat, _ sinP: CGFloat, _ a: CGFloat) -> CGPoint {
        let x = rx * cos(a), y = ry * sin(a)
        return CGPoint(x: cx + cosP*x - sinP*y, y: cy + sinP*x + cosP*y)
    }
    private static func ellipseDeriv(_ rx: CGFloat, _ ry: CGFloat, _ cosP: CGFloat, _ sinP: CGFloat, _ a: CGFloat) -> CGPoint {
        let x = -rx * sin(a), y = ry * cos(a)
        return CGPoint(x: cosP*x - sinP*y, y: sinP*x + cosP*y)
    }
}

/// SwiftUI shape for a multi-subpath SVG (16×16 viewBox), even-odd filled.
/// One Bootstrap `<path>` (16×16 viewBox). Caller fills it even-odd, exactly
/// like the web's per-path `fillRule="evenodd"`.
struct SVGShape: Shape {
    let d: String
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 16
        var t = CGAffineTransform(scaleX: s, y: s)
        let scaled = SVGPath.scan(d).copy(using: &t) ?? SVGPath.scan(d)
        return Path(scaled)
    }
}
