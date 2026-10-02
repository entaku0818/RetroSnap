import UIKit
// アプリの FilmRenderer / CameraCatalog をそのまま使って現像する（スクショ素材用・作業ディレクトリ専用）
let args = CommandLine.arguments
let srcDir = args[1], outDir = args[2]
var comps = DateComponents(); comps.year = 2026; comps.month = 10; comps.day = 2; comps.hour = 18
let date = Calendar(identifier: .gregorian).date(from: comps)!
for name in ["cafe", "fountain", "shibuya", "beach"] {
    guard let img = UIImage(contentsOfFile: "\(srcDir)/\(name).jpg") else { print("missing", name); continue }
    for spec in CameraCatalog.all {
        guard let out = FilmRenderer.shared.render(img, with: spec, capturedAt: date),
              let data = out.jpegData(compressionQuality: 0.93) else { print("fail", name, spec.id.rawValue); continue }
        try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)-\(spec.id.rawValue).jpg"))
        print("ok", name, spec.id.rawValue, out.size)
    }
}
