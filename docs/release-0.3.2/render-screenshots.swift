import AppKit
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let size = NSSize(width: 1320, height: 2868)
func text(_ value: String, _ rect: NSRect, _ pointSize: CGFloat, _ color: NSColor, bold: Bool = false) {
 let style = NSMutableParagraphStyle(); style.lineSpacing = 12
 (value as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: pointSize, weight: bold ? .bold : .regular), .foregroundColor: color, .paragraphStyle: style])
}
let ink = NSColor(calibratedRed: 0.23, green: 0.17, blue: 0.13, alpha: 1)
for locale in ["ja", "en-US"] {
 let ja = locale == "ja"
 for shot in 1...2 {
  let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1320, pixelsHigh: 2868, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  bitmap.size = size
  NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  NSColor(calibratedRed: 0.94, green: 0.90, blue: 0.83, alpha: 1).setFill(); NSRect(origin: .zero, size: size).fill()
  text("RETROSNAP", NSRect(x: 100, y: 2670, width: 1120, height: 70), 38, ink, bold: true)
  let title = shot == 1 ? (ja ? "撮るだけで、\nフィルム写真。" : "Just shoot.\nGet film.") : (ja ? "買う前に、\n写りを見比べる。" : "Preview first.\nPick your look.")
  text(title, NSRect(x: 100, y: 2290, width: 1120, height: 350), ja ? 104 : 114, ink, bold: true)
  let sub = shot == 1 ? (ja ? "平成デジカメも。無料3台から。" : "Start with 3 free cameras. Y2K included.") : (ja ? "有料カメラは、保存するときに買い切り。" : "Paid cameras: buy once to save your shots.")
  text(sub, NSRect(x: 100, y: 2130, width: 1120, height: 130), ja ? 43 : 40, ink)
  let asset = shot == 1 ? "screen-cafe-sunsetfade.jpg" : "screen-fountain-locked-notice.jpg"
  let url = root.appendingPathComponent("docs/screenshot_directions/src/assets/real/\(ja ? "ja" : "en")/\(asset)")
  let source = NSImage(contentsOf: url)!
  let frame = NSRect(x: 235, y: 260, width: 850, height: 1847)
  NSColor.black.setFill(); NSBezierPath(roundedRect: frame.insetBy(dx: -16, dy: -16), xRadius: 60, yRadius: 60).fill()
  NSGraphicsContext.saveGraphicsState(); NSBezierPath(roundedRect: frame, xRadius: 45, yRadius: 45).addClip()
  source.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1)
  NSGraphicsContext.restoreGraphicsState()
  text(ja ? "8つの写り  /  サブスクなし" : "8 camera looks  /  No subscription", NSRect(x: 100, y: 80, width: 1120, height: 100), 42, ink, bold: true)
  NSGraphicsContext.restoreGraphicsState()
  let out = root.appendingPathComponent("docs/release-0.3.2/screenshots/\(locale)/\(shot-1)_APP_IPHONE_67_0.png")
  try bitmap.representation(using: .png, properties: [:])!.write(to: out)
 }
}
