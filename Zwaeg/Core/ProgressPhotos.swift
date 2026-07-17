import UIKit

/// Weekly progress photos. Stored only on this device, as Documents
/// progress-<unix>.jpg — a prefix BuddyCloset's sweep leaves alone.
enum ProgressPhotos {
    struct Photo: Identifiable, Equatable {
        let url: URL
        let date: Date

        var id: URL { url }
    }

    private static var directory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    /// Oldest first.
    static func all() -> [Photo] {
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil) else { return [] }
        return files
            .filter { $0.lastPathComponent.hasPrefix("progress-") && $0.pathExtension == "jpg" }
            .compactMap { url in
                let stamp = url.deletingPathExtension().lastPathComponent.dropFirst("progress-".count)
                guard let value = TimeInterval(stamp) else { return nil }
                return Photo(url: url, date: Date(timeIntervalSince1970: value))
            }
            .sorted { $0.date < $1.date }
    }

    @discardableResult
    static func add(_ image: UIImage, date: Date = .now) -> Photo? {
        guard let directory else { return nil }
        let scaled = downscaled(image, maxSide: 1200)
        guard let data = scaled.jpegData(compressionQuality: 0.8) else { return nil }
        let url = directory.appendingPathComponent("progress-\(Int(date.timeIntervalSince1970)).jpg")
        guard (try? data.write(to: url)) != nil else { return nil }
        return Photo(url: url, date: date)
    }

    static func delete(_ photo: Photo) {
        try? FileManager.default.removeItem(at: photo.url)
    }

    private static func downscaled(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let side = max(image.size.width, image.size.height)
        guard side > maxSide, side > 0 else { return image }
        let factor = maxSide / side
        let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        return UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
