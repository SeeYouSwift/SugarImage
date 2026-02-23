import SwiftUI

/// A drop-in replacement for `AsyncImage` with 3-level caching:
/// - **L1**: In-memory `NSCache` (fast, cleared on app restart)
/// - **L2**: Disk cache in Application Support (persists across launches)
/// - **L3**: Network download via `URLSession`
///
/// Configure caching behaviour via `SugarImageConfig.shared`.
public struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    public init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
    }

    public var body: some View {
        content(phase)
            .task(id: url) {
                await load()
            }
    }

    private func load() async {
        guard let url else {
            phase = .empty
            return
        }

        // L1: In-memory NSCache
        if let cached = ImageCache.shared.image(for: url) {
            phase = .success(makeImage(from: cached))
            return
        }

        // L2: Disk cache
        let config = SugarImageConfig.shared
        if config.isDiskCacheEnabled,
           let data = ImageDiskCache.shared.imageData(for: url),
           let platformImage = makePlatformImage(from: data) {
            ImageCache.shared.set(platformImage, for: url)
            phase = .success(makeImage(from: platformImage))
            return
        }

        // L3: Network download
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = config.timeoutInterval

            let (data, _) = try await URLSession.shared.data(for: request)

            guard let platformImage = makePlatformImage(from: data) else {
                phase = .failure(URLError(.cannotDecodeContentData))
                return
            }

            // Promote to L1
            ImageCache.shared.set(platformImage, for: url)

            // Persist to L2
            if config.isDiskCacheEnabled {
                ImageDiskCache.shared.save(data, for: url)
            }

            phase = .success(makeImage(from: platformImage))
        } catch {
            phase = .failure(error)
        }
    }

    // MARK: - Platform helpers

    #if canImport(UIKit)
    private func makePlatformImage(from data: Data) -> UIImage? { UIImage(data: data) }
    private func makeImage(from image: UIImage) -> Image { Image(uiImage: image) }
    #else
    private func makePlatformImage(from data: Data) -> NSImage? { NSImage(data: data) }
    private func makeImage(from image: NSImage) -> Image { Image(nsImage: image) }
    #endif
}
