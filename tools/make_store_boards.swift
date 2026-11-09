// Assemble les planches du store a partir des photos du test terrain.
// Usage (depuis la racine du depot) :
//   swift tools/make_store_boards.swift [dossier-des-photos]
// Les photos sont lues seulement (jamais copiees dans le depot) ; sorties :
//   docs/store/store-marche.png   trois photos redressees (EXIF), recadrees sur la montre,
//                                 cote a cote, meme hauteur, fond neutre, sans retouche
//   docs/store/store-reglages.png capture du simulateur (si presente), sur fond neutre
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let defaultDir = "/Users/sam/agent-lab/data/inbox/glidator2/store-shots"
let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : defaultDir
let outDir = "docs/store"

// Fichier, centre de la montre (fractions de l'image redressee), cote du carre (fraction de la largeur).
struct Shot { let file: String; let cx: Double; let cy: Double; let side: Double }
let shots = [
    Shot(file: "IMG_9380.jpeg", cx: 790.0 / 1500, cy: 1130.0 / 2000, side: 880.0 / 1500),
    Shot(file: "IMG_9381.jpeg", cx: 740.0 / 1500, cy: 1290.0 / 2000, side: 880.0 / 1500),
    Shot(file: "IMG_9382.jpeg", cx: 580.0 / 1500, cy: 1300.0 / 2000, side: 880.0 / 1500),
]
let boardHeight = 900   // hauteur de chaque photo sur la planche
let margin = 50
let background = CGColor(gray: 0.93, alpha: 1)

func loadOriented(_ path: String) -> CGImage? {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let src = CGImageSourceCreateWithURL(url, nil) else { return nil }
    let opts: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,   // applique l'orientation EXIF
        kCGImageSourceThumbnailMaxPixelSize: 8000,
    ]
    return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
}

func context(_ w: Int, _ h: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(background)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.interpolationQuality = .high
    return ctx
}

func writePNG(_ img: CGImage, _ path: String) {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else {
        print("ecriture impossible : \(path)"); exit(1)
    }
    CGImageDestinationAddImage(dest, img, nil)
    if !CGImageDestinationFinalize(dest) { print("echec : \(path)"); exit(1) }
    print("ecrit \(path) (\(img.width)x\(img.height))")
}

// --- Planche Marche ---
var crops: [CGImage] = []
for s in shots {
    let path = dir + "/" + s.file
    guard let img = loadOriented(path) else { print("photo illisible : \(path)"); exit(1) }
    let w = Double(img.width), h = Double(img.height)
    let side = s.side * w
    var x = s.cx * w - side / 2, y = s.cy * h - side / 2
    x = max(0, min(x, w - side)); y = max(0, min(y, h - side))
    guard let c = img.cropping(to: CGRect(x: x, y: y, width: side, height: side)) else {
        print("recadrage impossible : \(path)"); exit(1)
    }
    crops.append(c)
}
let n = crops.count
let boardW = margin * (n + 1) + boardHeight * n
let boardH = boardHeight + 2 * margin
let ctx = context(boardW, boardH)
for (i, c) in crops.enumerated() {
    ctx.draw(c, in: CGRect(x: margin + i * (boardHeight + margin), y: margin,
                           width: boardHeight, height: boardHeight))
}
writePNG(ctx.makeImage()!, outDir + "/store-marche.png")

// --- Planche Reglages (facultatif) ---
let sim = dir + "/Capture d\u{2019}\u{00E9}cran 2026-11-09 \u{00E0} 13.39.33.png"
if let img = loadOriented(sim) {
    let pad = 60
    let c = context(img.width + 2 * pad, img.height + 2 * pad)
    c.draw(img, in: CGRect(x: pad, y: pad, width: img.width, height: img.height))
    writePNG(c.makeImage()!, outDir + "/store-reglages.png")
} else {
    print("capture du simulateur absente, store-reglages.png non produit")
}
