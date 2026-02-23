import Foundation
import CryptoKit

/// L2 — disk image cache.
/// Stores raw image data under `Application Support/SugarImageCache/`.
/// Uses a SHA-256 hash of the image URL as the filename.
final class ImageDiskCache: @unchecked Sendable {
    static let shared = ImageDiskCache()

    private let baseDirectory: URL
    private let fileManager = FileManager.default

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        baseDirectory = appSupport.appendingPathComponent("SugarImageCache")
        try? fileManager.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
    }

    func imageData(for url: URL) -> Data? {
        let file = fileURL(for: url)
        guard fileManager.fileExists(atPath: file.path) else { return nil }
        return try? Data(contentsOf: file)
    }

    func save(_ data: Data, for url: URL) {
        let file = fileURL(for: url)
        let dir = file.deletingLastPathComponent()
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }

    func exists(for url: URL) -> Bool {
        fileManager.fileExists(atPath: fileURL(for: url).path)
    }

    // MARK: - Private

    private func fileURL(for url: URL) -> URL {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hex = hash.compactMap { String(format: "%02x", $0) }.joined()
        return baseDirectory.appendingPathComponent("images/\(hex).dat")
    }
}
