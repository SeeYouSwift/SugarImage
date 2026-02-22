import Foundation

/// Global configuration for SugarImage caching behavior.
public final class SugarImageConfig: @unchecked Sendable {
    public static let shared = SugarImageConfig()

    /// Enable/disable disk caching (L2). Default: `true`.
    public var isDiskCacheEnabled: Bool = true

    /// Timeout for network image downloads. Default: 10 seconds.
    public var timeoutInterval: TimeInterval = 10

    /// Maximum number of images held in the memory cache (L1). Default: 100.
    public var memoryCacheLimit: Int = 100 {
        didSet { ImageCache.shared.updateLimit(memoryCacheLimit) }
    }

    private init() {}
}
