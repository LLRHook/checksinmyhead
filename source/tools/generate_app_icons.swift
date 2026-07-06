import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct IconSpec {
    let filename: String
    let pixels: Int
}

let specs: [IconSpec] = [
    IconSpec(filename: "Icon-iPhone-20@2x.png", pixels: 40),
    IconSpec(filename: "Icon-iPhone-20@3x.png", pixels: 60),
    IconSpec(filename: "Icon-iPhone-29@2x.png", pixels: 58),
    IconSpec(filename: "Icon-iPhone-29@3x.png", pixels: 87),
    IconSpec(filename: "Icon-iPhone-40@2x.png", pixels: 80),
    IconSpec(filename: "Icon-iPhone-40@3x.png", pixels: 120),
    IconSpec(filename: "Icon-iPhone-60@2x.png", pixels: 120),
    IconSpec(filename: "Icon-iPhone-60@3x.png", pixels: 180),
    IconSpec(filename: "Icon-iPad-20.png", pixels: 20),
    IconSpec(filename: "Icon-iPad-20@2x.png", pixels: 40),
    IconSpec(filename: "Icon-iPad-29.png", pixels: 29),
    IconSpec(filename: "Icon-iPad-29@2x.png", pixels: 58),
    IconSpec(filename: "Icon-iPad-40.png", pixels: 40),
    IconSpec(filename: "Icon-iPad-40@2x.png", pixels: 80),
    IconSpec(filename: "Icon-iPad-76.png", pixels: 76),
    IconSpec(filename: "Icon-iPad-76@2x.png", pixels: 152),
    IconSpec(filename: "Icon-iPad-83.5@2x.png", pixels: 167),
    IconSpec(filename: "Icon-AppStore-1024.png", pixels: 1024)
]

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "VictorWake/Assets.xcassets/AppIcon.appiconset")

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func interpolate(_ start: CGFloat, _ end: CGFloat, _ progress: CGFloat) -> CGFloat {
    start + (end - start) * progress
}

func makeColor(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: 1)
}

func drawIcon(size: Int) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else {
        fatalError("Unable to create icon context")
    }

    let side = CGFloat(size)
    let rect = CGRect(x: 0, y: 0, width: side, height: side)

    context.setFillColor(makeColor(red: 0.018, green: 0.034, blue: 0.045))
    context.fill(rect)

    let steps = max(size, 1)
    for index in 0..<steps {
        let progress = CGFloat(index) / CGFloat(max(steps - 1, 1))
        let red = interpolate(0.03, 0.00, progress)
        let green = interpolate(0.31, 0.62, progress)
        let blue = interpolate(0.36, 0.50, progress)
        context.setFillColor(makeColor(red: red, green: green, blue: blue))
        context.fill(CGRect(x: 0, y: CGFloat(index), width: side, height: 1))
    }

    let glowCenter = CGPoint(x: side * 0.68, y: side * 0.72)
    let gradientColors = [
        makeColor(red: 0.47, green: 0.93, blue: 0.78),
        makeColor(red: 0.47, green: 0.93, blue: 0.78).copy(alpha: 0) ?? makeColor(red: 0, green: 0, blue: 0)
    ] as CFArray
    let gradientLocations: [CGFloat] = [0, 1]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: gradientLocations) {
        context.drawRadialGradient(
            gradient,
            startCenter: glowCenter,
            startRadius: 0,
            endCenter: glowCenter,
            endRadius: side * 0.58,
            options: [.drawsAfterEndLocation]
        )
    }

    context.setBlendMode(.softLight)
    context.setFillColor(makeColor(red: 1.0, green: 1.0, blue: 1.0))
    context.fill(CGRect(x: side * -0.15, y: side * 0.52, width: side * 1.3, height: side * 0.5))
    context.setBlendMode(.normal)

    let lineWidth = max(side * 0.075, 2)
    context.setLineWidth(lineWidth)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setStrokeColor(makeColor(red: 0.94, green: 1.0, blue: 0.98))

    let center = CGPoint(x: side * 0.5, y: side * 0.50)
    let radius = side * 0.24
    context.addArc(
        center: center,
        radius: radius,
        startAngle: .pi * 0.74,
        endAngle: .pi * 2.26,
        clockwise: false
    )
    context.strokePath()

    context.move(to: CGPoint(x: side * 0.5, y: side * 0.78))
    context.addLine(to: CGPoint(x: side * 0.5, y: side * 0.55))
    context.strokePath()

    let bolt = CGMutablePath()
    bolt.move(to: CGPoint(x: side * 0.66, y: side * 0.29))
    bolt.addLine(to: CGPoint(x: side * 0.53, y: side * 0.29))
    bolt.addLine(to: CGPoint(x: side * 0.61, y: side * 0.14))
    bolt.addLine(to: CGPoint(x: side * 0.42, y: side * 0.39))
    bolt.addLine(to: CGPoint(x: side * 0.55, y: side * 0.39))
    bolt.closeSubpath()

    context.setFillColor(makeColor(red: 0.96, green: 0.80, blue: 0.28))
    context.addPath(bolt)
    context.fillPath()

    if size >= 1024 {
        context.setFillColor(makeColor(red: 0.94, green: 1.0, blue: 0.98))
        let text = "W"
        let font = CTFontCreateWithName("AvenirNext-Heavy" as CFString, side * 0.20, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): makeColor(red: 0.94, green: 1.0, blue: 0.98)
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetBoundsWithOptions(line, [.useOpticalBounds])
        context.textPosition = CGPoint(x: side * 0.5 - bounds.width / 2, y: side * 0.08)
        CTLineDraw(line, context)
    }

    guard let image = context.makeImage() else {
        fatalError("Unable to make icon image")
    }
    return image
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Unable to create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Unable to write PNG at \(url.path)")
    }
}

for spec in specs {
    let url = outputDirectory.appendingPathComponent(spec.filename)
    try writePNG(drawIcon(size: spec.pixels), to: url)
}

print("Generated \(specs.count) app icon files in \(outputDirectory.path)")
