import SwiftUI

/// L1 — in-memory image cache backed by `NSCache`.
/// Automatically evicts entries under memory pressure.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    #if canImport(UIKit)
    private let cache = NSCache<NSURL, UIImage>()
    #else
    private let cache = NSCache<NSURL, NSImage>()
    #endif

    private init() {
        cache.countLimit = SugarImageConfig.shared.memoryCacheLimit
    }

    func updateLimit(_ limit: Int) {
        cache.countLimit = limit
    }

    #if canImport(UIKit)
    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func set(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
    #else
    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func set(_ image: NSImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
    #endif
}
