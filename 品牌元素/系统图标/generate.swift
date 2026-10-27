// macOS: swift -module-cache-path /tmp/kabu-swift-cache 品牌元素/系统图标/generate.swift
// Reproducible platform exports. The supplied mascot artwork is not repainted.
import Foundation
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let fm = FileManager.default
let sourceURL = root.deletingLastPathComponent().appendingPathComponent("Logo/应用logo.png")
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
let warm = CGColor(colorSpace: srgb, components: [1, 248.0/255, 245.0/255, 1])!
func destination(_ name: String) -> URL {
    let url = root.appendingPathComponent(name)
    try! fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    return url
}
func textFile(_ name: String, _ text: String) { try! text.write(to: destination(name), atomically: true, encoding: .utf8) }
func canvas(_ size: Int, height: Int? = nil) -> CGContext {
    let h = height ?? size
    let c = CGContext(data: nil, width: size, height: h, bitsPerComponent: 8, bytesPerRow: size*4,
                      space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.interpolationQuality = .high
    c.translateBy(x: 0, y: CGFloat(h)); c.scaleBy(x: 1, y: -1)
    return c
}
func draw(_ image: CGImage, _ rect: CGRect, _ c: CGContext) {
    c.saveGState(); c.translateBy(x: rect.minX, y: rect.maxY); c.scaleBy(x: 1, y: -1)
    c.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height)); c.restoreGState()
}
func save(_ image: CGImage, _ name: String, jpeg: Bool = false, quality: Double = 0.95) {
    let type = jpeg ? UTType.jpeg.identifier : UTType.png.identifier
    let d = CGImageDestinationCreateWithURL(destination(name) as CFURL, type as CFString, 1, nil)!
    var properties: [CFString: Any] = [kCGImagePropertyColorModel: kCGImagePropertyColorModelRGB]
    if jpeg {
        properties[kCGImageDestinationLossyCompressionQuality] = quality
        properties[kCGImagePropertyExifDictionary] = [kCGImagePropertyExifColorSpace: 1]
    } else {
        properties[kCGImagePropertyPNGDictionary] = [kCGImagePropertyPNGsRGBIntent: 0]
    }
    CGImageDestinationAddImage(d, image, properties as CFDictionary)
    precondition(CGImageDestinationFinalize(d), "Failed to export \(name)")
}
let src = CGImageSourceCreateWithURL(sourceURL as CFURL, nil)!
let source = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let rep = NSBitmapImageRep(cgImage: source)
var minX = source.width, minY = source.height, maxX = 0, maxY = 0
var points: [(Int,Int)] = []
for y in 0..<source.height { for x in 0..<source.width {
    if rep.colorAt(x: x, y: y)!.alphaComponent > 8.0/255 {
        minX = min(minX,x); maxX = max(maxX,x); minY = min(minY,y); maxY = max(maxY,y)
        points.append((x,y))
    }
}}
let bbox = CGRect(x: minX, y: minY, width: maxX-minX+1, height: maxY-minY+1)
let crop = source.cropping(to: bbox)!
let cx = bbox.midX, cy = bbox.midY
let radius = points.map { hypot(Double($0.0)+0.5-cx, Double($0.1)+0.5-cy) }.max()!
// 64 dp visible diameter, inside Android's central 66 dp safe circle.
let scale = 32.0/radius
let mascotRect = CGRect(x: 54-bbox.width*scale/2, y: 54-bbox.height*scale/2,
                        width: bbox.width*scale, height: bbox.height*scale)
func foreground(_ size: Int) -> CGImage {
    let c = canvas(size); c.scaleBy(x: Double(size)/108, y: Double(size)/108)
    c.addEllipse(in: CGRect(x: 21,y: 21,width: 66,height: 66)); c.clip()
    draw(crop, mascotRect, c); return c.makeImage()!
}
let fg = foreground(432)
save(fg, "源文件/ic_launcher_foreground.png")
save(fg, "android/res/drawable-nodpi/ic_launcher_foreground.png")
let bg = canvas(432); bg.setFillColor(warm); bg.fill(CGRect(x: 0,y: 0,width: 432,height: 432))
save(bg.makeImage()!, "源文件/ic_launcher_background.png")

// Code-native monochrome mark, with transparent visor and chest emblem cutouts.
// Same capsule robot, unequal top petals, round pods and magnifying glass.
let paths = [
    "M 31 66 C 27 78 34 91 48 92 C 65 95 78 84 75 70 Z M 50 77 L 60 82 L 49 87 Z",
    "M 20 50 C 20 29 35 23 55 24 C 76 24 88 39 87 58 C 86 74 70 80 48 78 C 29 76 20 67 20 50 Z M 29 47 C 29 34 41 32 57 33 C 72 33 79 42 78 56 C 77 67 65 70 49 68 C 34 67 29 60 29 47 Z",
    "M 57 25 C 47 16 48 6 56 7 C 66 8 70 20 66 26 Z",
    "M 49 26 C 38 23 37 17 42 15 C 48 13 55 21 55 26 Z",
    "M 20 44 C 13 43 12 60 19 64 L 23 61 L 22 46 Z",
    "M 86 48 C 94 47 95 63 87 67 L 83 64 L 84 50 Z",
    "M 33 83 C 25 80 22 89 28 94 C 35 99 42 93 40 88 Z",
    "M 62 87 C 56 88 57 98 65 98 C 73 99 77 91 71 87 Z",
    "M 75 69 C 82 66 90 75 86 81 C 82 87 73 81 73 76 Z",
    "M 38 44 C 32 44 32 57 38 57 C 44 57 44 44 38 44 Z",
    "M 68 45 L 57 51 L 67 57 L 70 53 L 64 50 L 71 48 Z"
]
func path(_ source: String) -> CGPath {
    let tokens = source.split(separator: " ").map(String.init)
    let p = CGMutablePath(); var i = 0
    func num() -> CGFloat { defer { i += 1 }; return CGFloat(Double(tokens[i])!) }
    while i < tokens.count {
        let op = tokens[i]; i += 1
        if op == "M" { let x=num(),y=num(); p.move(to: CGPoint(x:x,y:y)) }
        else if op == "L" { let x=num(),y=num(); p.addLine(to: CGPoint(x:x,y:y)) }
        else if op == "C" { let x1=num(),y1=num(),x2=num(),y2=num(),x=num(),y=num(); p.addCurve(to: CGPoint(x:x,y:y), control1: CGPoint(x:x1,y:y1), control2: CGPoint(x:x2,y:y2)) }
        else if op == "Z" { p.closeSubpath() }
        else { fatalError("Unknown path op: \(op)") }
    }; return p
}
func mono(_ size: Int, tint: CGColor = CGColor(gray: 0, alpha: 1)) -> CGImage {
    let c = canvas(size); c.scaleBy(x: Double(size)/108, y: Double(size)/108)
    c.translateBy(x: 54,y: 54); c.scaleBy(x: 0.66,y: 0.66); c.translateBy(x: -54,y: -54)
    c.setFillColor(tint); c.setStrokeColor(tint)
    for value in paths { c.addPath(path(value)); c.drawPath(using: .eoFill) }
    c.setLineWidth(5); c.strokeEllipse(in: CGRect(x: 22,y: 34,width: 32,height: 32))
    c.setLineCap(.round); c.move(to: CGPoint(x: 28,y: 63)); c.addLine(to: CGPoint(x: 20,y: 77)); c.strokePath()
    return c.makeImage()!
}
let monoPaths = paths.map { "    <path android:fillColor=\"#FF000000\" android:fillType=\"evenOdd\" android:pathData=\"\($0)\"/>" }.joined(separator: "\n")
let vector = """
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
  <group android:pivotX="54" android:pivotY="54" android:scaleX="0.66" android:scaleY="0.66">
\(monoPaths)
    <path android:strokeColor="#FF000000" android:strokeWidth="5" android:fillColor="#00000000" android:pathData="M38,34 A16,16 0,1 1,38,66 A16,16 0,1 1,38,34"/>
    <path android:strokeColor="#FF000000" android:strokeWidth="5" android:strokeLineCap="round" android:pathData="M28,63 L20,77"/>
  </group>
</vector>
"""
textFile("android/res/drawable/ic_launcher_monochrome.xml",vector)
textFile("源文件/ic_launcher_monochrome.xml",vector)
save(mono(432),"源文件/ic_launcher_monochrome.png")
func icon(_ size: Int, shape: String = "square", themed: Bool = false, dark: Bool = false) -> CGImage {
    let c = canvas(size); let r = CGRect(x: 0,y: 0,width: size,height: size)
    if shape == "circle" { c.addEllipse(in: r); c.clip() }
    if shape == "rounded" { c.addPath(CGPath(roundedRect: r,cornerWidth: Double(size)*0.30,cornerHeight: Double(size)*0.30,transform: nil)); c.clip() }
    let themeBG = CGColor(colorSpace: srgb, components: dark ? [0.16,0.23,0.23,1] : [0.86,0.94,0.92,1])!
    c.setFillColor(themed ? themeBG : warm); c.fill(r)
    // Android's nominal visible masked viewport is the central 72 of 108 dp.
    let layerSize = Double(size)*108/72
    let target = CGRect(x: (Double(size)-layerSize)/2,y: (Double(size)-layerSize)/2,width: layerSize,height: layerSize)
    let tint = CGColor(colorSpace: srgb,components: dark ? [0.72,0.91,0.86,1] : [0.12,0.32,0.29,1])!
    let renderSize = Int(ceil(layerSize))
    draw(themed ? mono(renderSize,tint:tint) : foreground(renderSize),target,c)
    return c.makeImage()!
}
for (density,size) in [("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)] {
    save(icon(size),"android/res/mipmap-\(density)/ic_launcher.png")
    save(icon(size,shape:"circle"),"android/res/mipmap-\(density)/ic_launcher_round.png")
}
textFile("android/res/values/ic_launcher_colors.xml", """
<?xml version="1.0" encoding="utf-8"?>
<resources><color name="ic_launcher_background">#FFF8F5</color></resources>
""")
for version in [26,33] { for name in ["ic_launcher","ic_launcher_round"] {
    textFile("android/res/mipmap-anydpi-v\(version)/\(name).xml", """
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/ic_launcher_background"/>
  <foreground android:drawable="@drawable/ic_launcher_foreground"/>
\(version == 33 ? "  <monochrome android:drawable=\"@drawable/ic_launcher_monochrome\"/>" : "")
</adaptive-icon>
""")
}}
save(icon(1024),"商店/kabu-master-1024.png")
save(icon(512),"商店/kabu-google-play-512.png")
save(icon(512),"商店/kabu-xiaomi-oppo-512.png")
save(icon(512),"商店/kabu-honor-512.jpg",jpeg:true,quality:0.92)
save(icon(512),"商店/kabu-vivo-512.png")
save(icon(216),"商店/kabu-huawei-harmonyos-216.png")
let sheet = canvas(1320,height:760)
sheet.setFillColor(CGColor(gray:0.94,alpha:1)); sheet.fill(CGRect(x:0,y:0,width:1320,height:760))
func label(_ value: String, _ x: Double, _ y: Double, _ size: Double = 22) {
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext:sheet,flipped:true)
    (value as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:size),.foregroundColor:NSColor.darkGray])
    NSGraphicsContext.restoreGraphicsState()
}
label("咔捕 · 安卓系统图标 / 暖白底",40,24,28)
for (i,entry) in [("square","商店原图"),("circle","圆形裁切"),("rounded","圆角方形裁切"),("theme","单色主题 · 浅色"),("dark","单色主题 · 深色")].enumerated() {
    let x=40+Double(i)*255
    draw(icon(225,shape:entry.0=="square" ? "square" : entry.0=="circle" ? "circle":"rounded",themed:i>2,dark:i==4),CGRect(x:x,y:100,width:225,height:225),sheet)
    label(entry.1,x,345,19)
}
label("小尺寸预览（实际像素）",40,420,22)
var x = 40.0
for s in [48,72,96,144,192] {
    draw(icon(s,shape:"rounded"),CGRect(x:x,y:470,width:Double(s),height:Double(s)),sheet)
    label("\(s) px",x,680,18); x += Double(s)+78
}
save(sheet.makeImage()!,"预览/图标适配总览.png")
textFile("geometry.json", """
{"background":"#FFF8F5","layer_dp":108,"layer_px":432,"safe_circle_diameter_dp":66,"visible_art_diameter_dp":64,"source_crop":[\(minX),\(minY),\(Int(bbox.width)),\(Int(bbox.height))],"foreground_rect_dp":[\(mascotRect.minX),\(mascotRect.minY),\(mascotRect.width),\(mascotRect.height)]}
""")
print("Generated platform icon assets in \(root.path)")
