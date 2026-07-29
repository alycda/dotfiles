// pdfocr — OCR a PDF using the macOS Vision framework (no network, no extra deps).
//
// Why this exists: some statements (PayPal) are image-rendered with no text
// layer, so pypdf returns ~200 bytes of mail-barcode junk. The ingest pipeline
// would then hand that junk to the bookkeeper agent as if it were a statement.
// This is the fallback extractor for those.
//
// Usage: pdfocr <input.pdf> [output.txt]     (writes stdout if no output path)
// Requires macOS 10.15+ (VNRecognizeTextRequest).

import Foundation
import PDFKit
import Vision
import CoreGraphics

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: pdfocr <input.pdf> [output.txt]\n".data(using: .utf8)!)
    exit(2)
}
let inPath = args[1]
guard let doc = PDFDocument(url: URL(fileURLWithPath: inPath)) else {
    FileHandle.standardError.write("error: cannot open \(inPath)\n".data(using: .utf8)!)
    exit(1)
}

// Render at 2x for legibility of statement small print; Vision is scale sensitive.
let scale: CGFloat = 2.0
var out = ""

for i in 0..<doc.pageCount {
    guard let page = doc.page(at: i) else { continue }
    let bounds = page.bounds(for: .mediaBox)
    let w = Int(bounds.width * scale), h = Int(bounds.height * scale)
    guard w > 0, h > 0,
          let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { continue }

    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
    ctx.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: ctx)

    guard let cgImage = ctx.makeImage() else { continue }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false   // financial text: don't "correct" figures
    if #available(macOS 11.0, *) { request.revision = VNRecognizeTextRequestRevision2 }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
        try handler.perform([request])
    } catch {
        FileHandle.standardError.write("page \(i): OCR failed: \(error)\n".data(using: .utf8)!)
        continue
    }
    guard let observations = request.results as? [VNRecognizedTextObservation] else { continue }

    // Group observations into visual lines by vertical position so that
    // side-by-side columns (rate tables!) don't get interleaved arbitrarily.
    var lines: [(y: CGFloat, x: CGFloat, text: String)] = []
    for obs in observations {
        guard let best = obs.topCandidates(1).first else { continue }
        lines.append((y: obs.boundingBox.midY, x: obs.boundingBox.minX, text: best.string))
    }
    lines.sort { a, b in
        if abs(a.y - b.y) > 0.006 { return a.y > b.y }  // top-to-bottom
        return a.x < b.x                                 // then left-to-right
    }
    var current: [String] = []
    var lastY: CGFloat? = nil
    for l in lines {
        if let ly = lastY, abs(l.y - ly) > 0.006 {
            out += current.joined(separator: " ") + "\n"
            current = []
        }
        current.append(l.text)
        lastY = l.y
    }
    if !current.isEmpty { out += current.joined(separator: " ") + "\n" }
    out += "\n"
}

if args.count >= 3 {
    try? out.write(toFile: args[2], atomically: true, encoding: .utf8)
    print("wrote \(args[2]) (\(out.count) chars, \(doc.pageCount) pages)")
} else {
    print(out)
}
