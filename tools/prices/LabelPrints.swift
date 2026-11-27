// Label fingerprints of shop photos, made exactly like the app's LabelPrint (Jeroboam/Sources/LabelPrint.swift), so they compare
// with the phone's: Apple Vision VNGenerateImageFeaturePrintRequest, picture drawn upright with its longest side at most 640 px,
// imageCropAndScaleOption = .scaleFit, 32-bit floats; the Vision revision is kept (prints of different revisions don't compare).
// Runs on a macOS runner (fingerprints.yml). Only the numbers are kept, never the photos.
//
// Two prints per photo:
//   full  = the whole picture (as a phone scan would be if the whole bottle were in the frame)
//   label = a square around the label: plain background trimmed, then for a standing bottle the square of the bottle's width
//           centred 64% of the way down (phone scans are label close-ups); for other pictures the centre square.
// The crop is cut from the photo at up to 1600 px and then prepared like any other picture (longest side 640).
//
//   swiftc -O tools/prices/LabelPrints.swift -o labelprints && ./labelprints jobs.tsv out-prefix [workers]
// jobs.tsv: one photo URL per line (line number = row). Writes out-prefix.full.f16, out-prefix.label.f16 (rows of `dims` 16-bit floats,
// little-endian; zeros where status != ok) and out-prefix.status.tsv (row, status, revision, dims).
import Foundation
import Vision
import CoreGraphics
import ImageIO

let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: labelprints jobs.tsv out-prefix [workers]"); exit(2) }
let urls = try! String(contentsOfFile: args[1], encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false)
    .map(String.init).filter { !$0.isEmpty }
let prefix = args[2]
let workers = args.count > 3 ? Int(args[3]) ?? 6 : 6

final class Session: @unchecked Sendable {
    let s: URLSession
    init() {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 30
        c.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 (wine label fingerprints; personal app)"]
        s = URLSession(configuration: c)
    }
    func get(_ url: URL) -> Data? {
        for attempt in 0..<4 {
            let sem = DispatchSemaphore(value: 0)
            var out: Data?, code = 0
            s.dataTask(with: url) { d, r, _ in out = d; code = (r as? HTTPURLResponse)?.statusCode ?? 0; sem.signal() }.resume()
            sem.wait()
            if code == 200, let out, !out.isEmpty { return out }
            if code == 404 || code == 410 { return nil }
            Thread.sleep(forTimeInterval: Double(1 + 2 * attempt))
        }
        return nil
    }
}

/// Decoded upright (EXIF orientation applied), longest side at most `maxSide`, never enlarged.
func decode(_ data: Data, maxSide: Int) -> CGImage? {
    guard let src = CGImageSourceCreateWithData(data as CFData, nil),
          let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else { return nil }
    let w = (props[kCGImagePropertyPixelWidth] as? Int) ?? 0, h = (props[kCGImagePropertyPixelHeight] as? Int) ?? 0
    guard w > 0, h > 0 else { return nil }
    let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                                 kCGImageSourceThumbnailMaxPixelSize: min(maxSide, max(w, h))]
    return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
}

/// The app's preparation: drawn into an opaque picture whose longest side is at most 640 (transparent shop pictures land on white).
func prepared(_ img: CGImage) -> CGImage? {
    let side = Double(max(img.width, img.height))
    let k = min(1, 640 / max(1, side))
    let w = max(1, Int((Double(img.width) * k).rounded())), h = max(1, Int((Double(img.height) * k).rounded()))
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.interpolationQuality = .high
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    return ctx.makeImage()
}

/// RGBA bytes of a picture drawn on white (row 0 = top).
func pixels(_ img: CGImage) -> [UInt8]? {
    let w = img.width, h = img.height
    var buf = [UInt8](repeating: 255, count: w * h * 4)
    let ok = buf.withUnsafeMutableBytes { raw -> Bool in
        guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return true
    }
    return ok ? buf : nil
}

enum Crop { case unusable, ok(CGImage) }

/// The label square of a shop photo (see the header), or .unusable for blank / single-colour placeholders and tiny pictures.
func labelCrop(_ img: CGImage) -> Crop {
    let w = img.width, h = img.height
    guard min(w, h) >= 80, let px = pixels(img) else { return .unusable }
    func at(_ x: Int, _ y: Int) -> (Int, Int, Int) { let i = (y * w + x) * 4; return (Int(px[i]), Int(px[i + 1]), Int(px[i + 2])) }
    var cs: [(Int, Int, Int)] = []
    for (x0, y0) in [(0, 0), (w - 4, 0), (0, h - 4), (w - 4, h - 4)] { for dy in 0..<4 { for dx in 0..<4 { cs.append(at(x0 + dx, y0 + dy)) } } }
    func med(_ v: [Int]) -> Int { v.sorted()[v.count / 2] }
    let bg = (med(cs.map { $0.0 }), med(cs.map { $0.1 }), med(cs.map { $0.2 }))
    var minX = w, maxX = -1, minY = h, maxY = -1, on = 0
    var sum = 0.0, sum2 = 0.0
    for y in stride(from: 0, to: h, by: 1) {
        for x in stride(from: 0, to: w, by: 1) {
            let p = at(x, y)
            let g = Double(p.0 + p.1 + p.2) / 3; sum += g; sum2 += g * g
            if max(abs(p.0 - bg.0), abs(p.1 - bg.1), abs(p.2 - bg.2)) > 28 {
                on += 1; minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
    }
    let n = Double(w * h), sd = (sum2 / n - (sum / n) * (sum / n)).squareRoot()
    guard Double(on) / n >= 0.02, sd >= 6, maxX > minX, maxY > minY else { return .unusable }
    let ow = maxX - minX + 1, oh = maxY - minY + 1
    var r: CGRect
    if Double(oh) > 1.6 * Double(ow) {           // standing bottle
        let top = max(0, min(oh - ow, Int(Double(oh) * 0.64) - ow / 2))
        r = CGRect(x: minX, y: minY + top, width: ow, height: ow)
    } else {
        let s = min(ow, oh)
        r = CGRect(x: minX + (ow - s) / 2, y: minY + (oh - s) / 2, width: s, height: s)
    }
    r = r.intersection(CGRect(x: 0, y: 0, width: w, height: h))
    guard let c = img.cropping(to: r) else { return .unusable }
    return .ok(c)
}

/// LabelPrint.make: same request, options and number format.
func featurePrint(_ img: CGImage) -> (values: [Float], revision: Int)? {
    let req = VNGenerateImageFeaturePrintRequest()
    req.imageCropAndScaleOption = .scaleFit
    let handler = VNImageRequestHandler(cgImage: img, orientation: .up, options: [:])
    guard (try? handler.perform([req])) != nil, let obs = req.results?.first else { return nil }
    let n = obs.elementCount
    guard n > 0 else { return nil }
    var values = [Float](); values.reserveCapacity(n)
    obs.data.withUnsafeBytes { raw in
        switch obs.elementType {
        case .float: values.append(contentsOf: raw.bindMemory(to: Float.self).prefix(n))
        case .double: for v in raw.bindMemory(to: Double.self).prefix(n) { values.append(Float(v)) }
        default: break
        }
    }
    return values.count == n ? (values, req.revision) : nil
}

struct Result { var status = "download_failed"; var rev = 0; var full: [Float] = []; var label: [Float] = [] }

func work(_ s: String, _ session: Session) -> Result {
    var r = Result()
    var u = s.hasPrefix("//") ? "https:" + s : s
    u += (u.contains("?") ? "&" : "?") + "width=1600"          // Shopify CDN: at most 1600 px wide
    guard let url = URL(string: u), let data = session.get(url) else { return r }
    guard let big = decode(data, maxSide: 1600) else { r.status = "undecodable"; return r }
    guard case .ok(let crop) = labelCrop(big) else { r.status = "unusable"; return r }
    guard let a = prepared(big), let b = prepared(crop), let fa = featurePrint(a), let fb = featurePrint(b) else {
        r.status = "vision_failed"; return r
    }
    r.status = "ok"; r.rev = fa.revision; r.full = fa.values; r.label = fb.values
    return r
}

var results = [Result](repeating: Result(), count: urls.count)
let lock = NSLock()
var next = 0, done = 0
let start = Date()
let session = Session()
DispatchQueue.concurrentPerform(iterations: workers) { _ in
    while true {
        lock.lock(); let i = next; next += 1; lock.unlock()
        if i >= urls.count { return }
        let r = autoreleasepool { work(urls[i], session) }
        lock.lock(); results[i] = r; done += 1
        if done % 1000 == 0 { print("  \(done)/\(urls.count)  \(Int(Date().timeIntervalSince(start)))s"); fflush(stdout) }
        lock.unlock()
    }
}

let dims = results.first(where: { $0.status == "ok" })?.full.count ?? 0
var full = Data(), label = Data()
var status = "row\tstatus\trevision\tdims\n"
for (i, r) in results.enumerated() {
    let ok = r.status == "ok" && r.full.count == dims && r.label.count == dims
    // stored as 16-bit floats to halve the size (the app's 32-bit format is made again when a print is sent to the worker)
    let f = (ok ? r.full : [Float](repeating: 0, count: dims)).map { Float16($0) }
    let l = (ok ? r.label : [Float](repeating: 0, count: dims)).map { Float16($0) }
    f.withUnsafeBufferPointer { full.append(Data(buffer: $0)) }
    l.withUnsafeBufferPointer { label.append(Data(buffer: $0)) }
    status += "\(i)\t\(ok ? "ok" : (r.status == "ok" ? "dims_mismatch" : r.status))\t\(r.rev)\t\(dims)\n"
}
try! full.write(to: URL(fileURLWithPath: prefix + ".full.f16"))
try! label.write(to: URL(fileURLWithPath: prefix + ".label.f16"))
try! status.write(toFile: prefix + ".status.tsv", atomically: true, encoding: .utf8)
let okCount = results.filter { $0.status == "ok" }.count
print("done: \(okCount)/\(urls.count) fingerprinted, dims \(dims), revision \(results.first(where: { $0.status == "ok" })?.rev ?? 0), \(Int(Date().timeIntervalSince(start)))s")
