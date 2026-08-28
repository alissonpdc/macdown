// Gera o ícone do MacDown: squircle macOS, gradiente dark slate, monograma "M↓".
// Uso: swift generate-icon.swift <saida.png>
import AppKit
import CoreGraphics

let size = CGFloat(1024)
let master = NSSize(width: size, height: size)

func bezierCGPath(_ bezier: NSBezierPath) -> CGPath {
    let path = CGMutablePath()
    var points = [CGPoint](repeating: .zero, count: 3)
    for i in 0..<bezier.elementCount {
        let element = bezier.element(at: i, associatedPoints: &points)
        switch element {
        case .moveTo: path.move(to: points[0])
        case .lineTo: path.addLine(to: points[0])
        case .curveTo, .cubicCurveTo:
            path.addCurve(to: points[2], control1: points[0], control2: points[1])
        case .quadraticCurveTo:
            path.addQuadCurve(to: points[1], control: points[0])
        case .closePath: path.closeSubpath()
        @unknown default: break
        }
    }
    return path
}

let tile = size * 0.804 // 824pt no canvas 1024 (padrão Big Sur)
let origin = (size - tile) / 2
let radius = tile * 0.225
let squircle = NSBezierPath(roundedRect: NSRect(x: origin, y: origin, width: tile, height: tile),
                            xRadius: radius, yRadius: radius)
let squirclePath = bezierCGPath(squircle)

func drawIcon(_ rect: CGRect) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }

    // Fundo: gradiente diagonal dark slate (#24303F → #0D1420)
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()
    let gradientColors = [
        CGColor(srgbRed: 0.153, green: 0.208, blue: 0.278, alpha: 1),
        CGColor(srgbRed: 0.051, green: 0.086, blue: 0.133, alpha: 1)
    ] as CFArray
    let angle: CGFloat = -60
    let radians = angle * .pi / 180
    let dX = cos(radians), dY = sin(radians)
    let mid = origin + tile / 2
    // Cobrir o squircle inteiro: alcance maior que a semi-diagonal
    let reach = tile * 0.75
    let start = CGPoint(x: mid - dX * reach, y: mid - dY * reach)
    let end = CGPoint(x: mid + dX * reach, y: mid + dY * reach)
    ctx.drawLinearGradient(CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: gradientColors,
                                      locations: [0, 1])!,
                           start: start, end: end, options: [])

    // Halo suave na base atrás do monograma
    let halo = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [
                            CGColor(srgbRed: 0.220, green: 0.741, blue: 0.973, alpha: 0.16),
                            CGColor(srgbRed: 0.220, green: 0.741, blue: 0.973, alpha: 0.0)
                          ] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(halo,
                           start: CGPoint(x: mid, y: origin),
                           end: CGPoint(x: mid, y: origin + tile * 0.85),
                           options: [])
    ctx.restoreGState()

    // Borda interna sutil
    squircle.lineWidth = tile * 0.006
    NSColor(white: 1.0, alpha: 0.10).setStroke()
    squircle.stroke()

    // Monograma "M↓"
    func glyph(_ text: String, weight: NSFont.Weight, fontSize: CGFloat,
               color: NSColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: color
        ])
    }
    let mSize = tile * 0.52
    let arrowSize = mSize * 0.82
    let accent = NSColor(srgbRed: 0.302, green: 0.769, blue: 0.969, alpha: 1)
    let m = glyph("M", weight: .heavy, fontSize: mSize, color: .white)
    let arrow = glyph("↓", weight: .black, fontSize: arrowSize, color: accent)

    let gap = tile * 0.045
    let total = m.size().width + gap + arrow.size().width
    let midY = rect.midY
    let mX = rect.midX - total / 2
    m.draw(at: NSPoint(x: mX, y: midY - m.size().height / 2))
    let arrowBaselineDelta = (m.size().height - arrow.size().height) * 0.42
    arrow.draw(at: NSPoint(x: mX + m.size().width + gap,
                           y: midY - m.size().height / 2 + arrowBaselineDelta))
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = master
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
drawIcon(NSRect(origin: .zero, size: master))
NSGraphicsContext.restoreGraphicsState()

guard CommandLine.arguments.count > 1 else { exit(1) }
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("Ícone gerado em \(CommandLine.arguments[1])")
