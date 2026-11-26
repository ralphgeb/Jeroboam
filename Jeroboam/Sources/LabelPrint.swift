import UIKit
import Vision

/// A label's visual fingerprint: Apple's Vision "feature print" of the scanned photo, made on the phone (free, offline).
/// Step 1 of picture matching (Vivino-style): every photo scan adds its fingerprint to the wine it turned out to be, in our
/// online wine table (worker `POST /print`, at most 5 per wine). Nothing uses them yet: once there are a few hundred, a test
/// measures how close the same label is to itself and to look-alikes, and only then does matching get switched on (with the
/// label text as a check). A fingerprint is a list of numbers, not the photo; the photo cannot be rebuilt from it.
enum LabelPrint {
    /// The fingerprint as 32-bit numbers (≈3 KB), with the Vision revision that made it (prints of different revisions don't compare).
    static func make(_ image: UIImage) -> (data: Data, revision: Int, count: Int)? {
        guard let cg = downsized(image) else { return nil }
        let req = VNGenerateImageFeaturePrintRequest()
        req.imageCropAndScaleOption = .scaleFit
        let handler = VNImageRequestHandler(cgImage: cg, orientation: orientation(image), options: [:])
        guard (try? handler.perform([req])) != nil, let obs = req.results?.first else { return nil }
        let n = obs.elementCount
        guard n > 0 else { return nil }
        var values = [Float]()
        values.reserveCapacity(n)
        obs.data.withUnsafeBytes { raw in
            switch obs.elementType {
            case .float: values.append(contentsOf: raw.bindMemory(to: Float.self).prefix(n))
            case .double: for v in raw.bindMemory(to: Double.self).prefix(n) { values.append(Float(v)) }
            default: break
            }
        }
        guard values.count == n else { return nil }
        let data = values.withUnsafeBufferPointer { Data(buffer: $0) }   // little-endian 32-bit floats
        return (data, req.revision, n)
    }

    /// Made and sent in the background after a photo scan; a failure is simply skipped.
    static func share(_ image: UIImage, for w: WineIdentity) {
        guard w.found, !w.name.isEmpty else { return }
        let key = WineDB.key(w)
        guard !key.isEmpty else { return }
        Task.detached(priority: .background) {
            guard let p = make(image) else { return }
            PriceCloud.sharePrint(key: key, print: p.data, revision: p.revision, count: p.count)
        }
    }

    private static func downsized(_ image: UIImage) -> CGImage? {
        let side = max(image.size.width, image.size.height)
        let k = min(1, 640 / max(1, side))   // Vision works on a small picture anyway
        let size = CGSize(width: image.size.width * k, height: image.size.height * k)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.cgImage
    }

    // drawn upright above, so the picture is always .up
    private static func orientation(_ image: UIImage) -> CGImagePropertyOrientation { .up }
}
