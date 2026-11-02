import AppKit
import Foundation

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: destination,withIntermediateDirectories: true)
for (name,size) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)] {
    let image = NSImage(size: NSSize(width: size,height: size))
    image.lockFocus()
    let side = CGFloat(size)
    NSColor(calibratedRed: 0.12,green: 0.14,blue: 0.14,alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: side*0.04,y: side*0.04,width: side*0.92,height: side*0.92),xRadius: side*0.21,yRadius: side*0.21).fill()
    NSColor(calibratedRed: 0.89,green: 0.72,blue: 0.47,alpha: 1).setStroke()
    let path = NSBezierPath(); path.lineWidth = side*0.065; path.lineCapStyle = .round; path.lineJoinStyle = .round
    let coordinates: [(CGFloat,CGFloat)] = [(0.21,0.38),(0.21,0.62),(0.34,0.62),(0.34,0.38),(0.47,0.38),(0.47,0.73),(0.60,0.73),(0.60,0.27),(0.73,0.27),(0.73,0.62),(0.81,0.62)]
    for (index,p) in coordinates.enumerated() { let point = NSPoint(x: side*p.0,y: side*p.1); if index == 0 { path.move(to: point) } else { path.line(to: point) } }; path.stroke()
    image.unlockFocus()
    guard let cg = image.cgImage(forProposedRect: nil,context: nil,hints: nil),let png = NSBitmapImageRep(cgImage: cg).representation(using: .png,properties: [:]) else { fatalError("Could not render icon") }
    try png.write(to: destination.appendingPathComponent(name+".png"))
}
