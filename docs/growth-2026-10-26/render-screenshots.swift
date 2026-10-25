import AppKit
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let retro = CommandLine.arguments.contains("retro")
let copy = try JSONDecoder().decode([String:[String]].self, from: Data(contentsOf: root.appendingPathComponent("docs/growth-2026-10-26/store-copy.json")))
let output = root.appendingPathComponent("temp/screenshots/iphone")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let ink = retro ? NSColor(calibratedRed: 0.22, green: 0.17, blue: 0.13, alpha: 1) : .white
func text(_ s: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, font: CGFloat, bold: Bool = false) {
 let style=NSMutableParagraphStyle(); style.lineSpacing=8
 let attrs: [NSAttributedString.Key:Any] = [.font:NSFont.systemFont(ofSize:font,weight:bold ? .bold : .regular),.foregroundColor:ink,.paragraphStyle:style]
 let bounds=(s as NSString).boundingRect(with:NSSize(width:w,height:10000),options:[.usesLineFragmentOrigin],attributes:attrs)
 precondition(bounds.height <= h, "Text overflows: \(s)")
 (s as NSString).draw(in:NSRect(x:x,y:y,width:w,height:h),withAttributes:attrs)
}
func picture(_ path: String, _ r: NSRect, round: CGFloat = 24, crop: Bool = false) {
 guard let image=NSImage(contentsOfFile:path) else { fatalError("Missing \(path)") }
 NSGraphicsContext.saveGraphicsState();NSBezierPath(roundedRect:r,xRadius:round,yRadius:round).addClip()
 var frame=r
 if crop {let scale=max(r.width/image.size.width,r.height/image.size.height);let w=image.size.width*scale,h=image.size.height*scale;frame=NSRect(x:r.midX-w/2,y:r.midY-h/2,width:w,height:h)}
 image.draw(in:frame,from:.zero,operation:.sourceOver,fraction:1);NSGraphicsContext.restoreGraphicsState()
}
for locale in ["ja","en-US","ko","de-DE","fr-FR","es-ES"] {
 let language=String(locale.prefix(2)); let row=copy[locale]!
 for index in 0..<2 {
  let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1320,pixelsHigh:2868,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
  bitmap.size=NSSize(width:1320,height:2868)
  NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
  (retro ? NSColor(calibratedRed:0.95,green:0.91,blue:0.84,alpha:1) : NSColor(calibratedRed:0.06,green:0.09,blue:0.17,alpha:1)).setFill();NSRect(x:0,y:0,width:1320,height:2868).fill()
  text(retro ? "RETROSNAP" : "SMART PLAYER",x:90,y:2690,w:1140,h:65,font:35,bold:true)
  let title=retro ? row[2+index] : row[3+index]
  text(title,x:90,y:2300,w:1140,h:350,font:locale == "de-DE" || locale == "es-ES" ? 88 : 98,bold:true)
  if retro && index == 0 {
   picture(root.appendingPathComponent("fastlane/screenshots/source/photos/02_iced_coffee_cafe.jpg").path,NSRect(x:80,y:1400,width:560,height:800),crop:true)
   picture(root.appendingPathComponent("docs/screenshot_directions/src/assets/real/cafe-sunsetfade.jpg").path,NSRect(x:680,y:1400,width:560,height:800),crop:true)
   text(row[4],x:80,y:1280,w:560,h:100,font:32,bold:true)
   text(row[5],x:680,y:1280,w:560,h:100,font:32,bold:true)
   picture("/tmp/retrosnap-growth-screens/\(language)-camera.png",NSRect(x:420,y:100,width:480,height:1040))
  } else if retro {
   picture("/tmp/retrosnap-growth-screens/\(language)-camera.png",NSRect(x:235,y:200,width:850,height:1847))
  } else {
   let file=index == 0 ? "library" : "resume"
   picture("/tmp/smartplayer-growth-screens/\(language)-\(file).png",NSRect(x:200,y:180,width:920,height:1998))
  }
  NSGraphicsContext.restoreGraphicsState()
  try bitmap.representation(using:.jpeg,properties:[.compressionFactor:0.97])!.write(to:output.appendingPathComponent("\(locale)_0\(index+1).jpg"))
 }
}
print("Rendered 12 localized screenshots")
