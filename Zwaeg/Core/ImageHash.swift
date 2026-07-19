import UIKit

/// Perceptual difference hash (dHash): 9x8 grayscale downscale, one bit per
/// horizontal neighbor comparison. Survives re-encoding and mild resizing,
/// which is exactly what catches the same treadmill photo uploaded twice.
enum ImageHash {
    static func dHash(_ image: UIImage) -> String {
        let width = 9, height = 8
        guard let cgImage = image.cgImage,
              let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return "" }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixels = context.data else { return "" }
        let buffer = pixels.bindMemory(to: UInt8.self, capacity: width * height)
        var hash: UInt64 = 0
        for row in 0..<height {
            for column in 0..<(width - 1) {
                let left = buffer[row * width + column]
                let right = buffer[row * width + column + 1]
                hash = (hash << 1) | (left > right ? 1 : 0)
            }
        }
        return String(format: "%016llx", hash)
    }

    /// Hamming distance ≤ threshold counts as the same picture.
    static func isNearDuplicate(_ a: String, _ b: String, threshold: Int = 6) -> Bool {
        guard let ha = UInt64(a, radix: 16), let hb = UInt64(b, radix: 16) else { return false }
        return (ha ^ hb).nonzeroBitCount <= threshold
    }
}
