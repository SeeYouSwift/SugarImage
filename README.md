# SugarImage

A SwiftUI image loading library with 3-level caching, full-screen photo gallery, pinch-to-zoom, and a drop-in `AsyncImage` replacement. Zero configuration — works out of the box.

## Features

- **`CachedAsyncImage`** — drop-in `AsyncImage` replacement with L1/L2/L3 caching
- **3-level cache**: memory (`NSCache`) → disk (Application Support) → network (`URLSession`)
- **`PhotoGalleryView`** — full-screen gallery with swipe paging, animated thumbnail indicator, and fade transitions
- **`ZoomableImageView`** — pinch-to-zoom, pan, double-tap, vertical scroll for tall images
- Protocol-based items (`PhotoGalleryItem`) — works with any model
- Configurable via `SugarImageConfig.shared`
- No external dependencies

## Requirements

- iOS 18+
- Swift 6+

## Installation

### Swift Package Manager

**Via Xcode:**
1. File → Add Package Dependencies
2. Enter the repository URL:
   ```
   https://github.com/SeeYouSwift/SugarImage
   ```
3. Select version rule and click **Add Package**

**Via `Package.swift`:**

```swift
dependencies: [
    .package(url: "https://github.com/SeeYouSwift/SugarImage", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["SugarImage"]
    )
]
```
## Usage

### CachedAsyncImage

A drop-in replacement for `AsyncImage`. Images are loaded once and cached in memory and on disk — subsequent loads are instant.

```swift
import SugarImage

CachedAsyncImage(url: imageURL) { phase in
    switch phase {
    case .success(let image):
        image.resizable().scaledToFill()
    case .failure:
        Image(systemName: "photo")
    case .empty:
        ProgressView()
    @unknown default:
        EmptyView()
    }
}
```

### PhotoGalleryView

Full-screen photo viewer. Conforms any model to `PhotoGalleryItem` to use it.

```swift
import SugarImage

// 1. Conform your model
struct Photo: PhotoGalleryItem {
    let id: UUID
    let imageURL: URL
}

// 2. Show the gallery
@State private var selectedIndex: Int? = nil

if let index = selectedIndex {
    PhotoGalleryView(
        items: photos,
        initialIndex: index
    ) { selected in
        selectedIndex = nil
        print("Dismissed on photo:", selected.imageURL)
    }
}
```

The `onDismiss` closure is optional — omit it if you don't need to know which item was selected:

```swift
PhotoGalleryView(items: photos, initialIndex: 0)
```

### ZoomableImageView

Embeds a single full-screen zoomable image. Used internally by `PhotoGalleryView`.

```swift
ZoomableImageView(url: photo.imageURL)
```

Pass `resetToken` to programmatically reset zoom:

```swift
ZoomableImageView(url: photo.imageURL, resetToken: resetCounter)
```

### Configuration

```swift
import SugarImage

// Disable disk cache (L2)
SugarImageConfig.shared.isDiskCacheEnabled = false

// Increase memory cache capacity
SugarImageConfig.shared.memoryCacheLimit = 200

// Extend network timeout
SugarImageConfig.shared.timeoutInterval = 30
```

## Cache Architecture

| Level | Storage | Speed | Persistence |
|-------|---------|-------|-------------|
| L1 | `NSCache` (memory) | Instant | Lost on app restart |
| L2 | Application Support (disk) | Fast | Survives restarts |
| L3 | `URLSession` (network) | Slow | Writes to L1 + L2 |

On every load, `CachedAsyncImage` checks L1 → L2 → L3 in order and promotes the result upward. Images loaded by `PhotoGalleryView` are already in cache when `ZoomableImageView` opens them — no visible delay.

## API Reference

### `PhotoGalleryItem`

```swift
public protocol PhotoGalleryItem: Identifiable {
    var imageURL: URL { get }
}
```

### `PhotoGalleryView`

```swift
public struct PhotoGalleryView<Item: PhotoGalleryItem>: View {
    public init(
        items: [Item],
        initialIndex: Int = 0,
        onDismiss: ((Item) -> Void)? = nil
    )
}
```

### `ZoomableImageView`

```swift
public struct ZoomableImageView: View {
    public init(url: URL, resetToken: Int = 0)
}
```

### `CachedAsyncImage`

```swift
public struct CachedAsyncImage<Content: View>: View {
    public init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content)
}
```

### `SugarImageConfig`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `isDiskCacheEnabled` | `Bool` | `true` | Enable/disable L2 disk cache |
| `memoryCacheLimit` | `Int` | `100` | Max images in memory (L1) |
| `timeoutInterval` | `TimeInterval` | `10` | Network download timeout (seconds) |
