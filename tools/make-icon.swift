// Draws the Kiesel app icon: three smooth pebbles stacked on a moss green
// macOS squircle. Usage: swift tools/make-icon.swift <out.png>
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let out = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

// Background squircle on the macOS icon grid (824 px body, 100 px margin).
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.35))
ctx.addPath(squircle)
ctx.setFillColor(rgb(0x2C6E57))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(squircle)
ctx.clip()
let bg = CGGradient(colorsSpace: space, colors: [rgb(0x4FA67C), rgb(0x2A6B55), rgb(0x1C4A3D)] as CFArray,
                    locations: [0, 0.55, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 300, y: 924), end: CGPoint(x: 724, y: 100),
                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
// Soft light from the top left.
let glow = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.22), rgb(0xFFFFFF, 0)] as CFArray,
                      locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 330, y: 820), startRadius: 0,
                       endCenter: CGPoint(x: 330, y: 820), endRadius: 520, options: [])
// Ground shadow under the stack.
ctx.setFillColor(rgb(0x0E2A22, 0.35))
ctx.fillEllipse(in: CGRect(x: 232, y: 196, width: 560, height: 78))
ctx.restoreGState()

/// A pebble: slightly tilted ellipse with a radial stone gradient, a highlight
/// and a contact shadow.
func pebble(center: CGPoint, width: CGFloat, height: CGFloat, tilt: CGFloat,
            light: UInt32, mid: UInt32, dark: UInt32) {
    let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: tilt * .pi / 180)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 22, color: rgb(0x0B2019, 0.55))
    ctx.setFillColor(rgb(mid))
    ctx.fillEllipse(in: rect)
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addEllipse(in: rect)
    ctx.clip()
    let stone = CGGradient(colorsSpace: space, colors: [rgb(light), rgb(mid), rgb(dark)] as CFArray,
                           locations: [0, 0.5, 1])!
    ctx.drawRadialGradient(stone, startCenter: CGPoint(x: -width * 0.18, y: height * 0.22), startRadius: 0,
                           endCenter: CGPoint(x: 0, y: 0), endRadius: width * 0.62, options: [.drawsAfterEndLocation])
    let shine = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.55), rgb(0xFFFFFF, 0)] as CFArray,
                           locations: [0, 1])!
    ctx.drawRadialGradient(shine, startCenter: CGPoint(x: -width * 0.2, y: height * 0.26), startRadius: 0,
                           endCenter: CGPoint(x: -width * 0.2, y: height * 0.26), endRadius: width * 0.28,
                           options: [])
    ctx.restoreGState()
    ctx.restoreGState()
}

pebble(center: CGPoint(x: 512, y: 312), width: 540, height: 220, tilt: -3,
       light: 0xE9E2D6, mid: 0xB8AC98, dark: 0x7A6F5E)
pebble(center: CGPoint(x: 524, y: 506), width: 400, height: 176, tilt: 4,
       light: 0xF3EEE6, mid: 0xCFC5B4, dark: 0x8F8472)
pebble(center: CGPoint(x: 504, y: 664), width: 270, height: 132, tilt: -7,
       light: 0xFFFFFF, mid: 0xE6DFD2, dark: 0xA39885)

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
