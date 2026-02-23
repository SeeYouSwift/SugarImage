import SwiftUI
#if canImport(UIKit)
import UIKit

// MARK: - ZoomableImageView

/// Full-screen image view with pinch-to-zoom, pan, and double-tap to zoom.
/// Width matches the container width; height is proportional to the original image.
/// If the image is taller than the screen it becomes vertically scrollable at scale 1.
///
/// - `resetToken`: changing this value resets the zoom to 1×.
public struct ZoomableImageView: View {
    public let url: URL
    public let resetToken: Int

    public init(url: URL, resetToken: Int = 0) {
        self.url = url
        self.resetToken = resetToken
    }

    public var body: some View {
        GeometryReader { geo in
            ZoomableScrollView(url: url, containerSize: geo.size, resetToken: resetToken)
        }
    }
}

// MARK: - UIViewRepresentable

private struct ZoomableScrollView: UIViewRepresentable {
    let url: URL
    let containerSize: CGSize
    let resetToken: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .clear
        scrollView.isScrollEnabled = true
        scrollView.contentInsetAdjustmentBehavior = .never

        context.coordinator.scrollView = scrollView
        context.coordinator.containerSize = containerSize

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        loadImage(into: scrollView, context: context)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        if context.coordinator.lastResetToken != resetToken {
            context.coordinator.lastResetToken = resetToken
            scrollView.setZoomScale(1.0, animated: true)
            scrollView.contentOffset = .zero
        }
        context.coordinator.containerSize = containerSize
        if let imageView = context.coordinator.imageView {
            applyLayout(scrollView: scrollView, imageView: imageView, containerSize: containerSize)
        }
    }

    // MARK: - Image loading

    private func loadImage(into scrollView: UIScrollView, context: Context) {
        // 1. L1 — memory cache (instant, no I/O)
        if let uiImage = ImageCache.shared.image(for: url) {
            installImage(uiImage, into: scrollView, context: context)
            return
        }
        // 2. L2 — disk cache (fast, avoids network)
        if let data = ImageDiskCache.shared.imageData(for: url),
           let uiImage = UIImage(data: data) {
            ImageCache.shared.set(uiImage, for: url)
            installImage(uiImage, into: scrollView, context: context)
            return
        }
        // 3. L3 — network download
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let uiImage = UIImage(data: data) else { return }
            ImageCache.shared.set(uiImage, for: url)
            ImageDiskCache.shared.save(data, for: url)
            DispatchQueue.main.async {
                installImage(uiImage, into: scrollView, context: context)
            }
        }.resume()
    }

    private func installImage(_ uiImage: UIImage, into scrollView: UIScrollView, context: Context) {
        context.coordinator.imageView?.removeFromSuperview()
        let imageView = UIImageView(image: uiImage)
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .clear
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        applyLayout(scrollView: scrollView, imageView: imageView, containerSize: containerSize)
    }

    // MARK: - Layout

    private func applyLayout(scrollView: UIScrollView, imageView: UIImageView, containerSize: CGSize) {
        guard let image = imageView.image, image.size.width > 0 else { return }

        let w = containerSize.width
        let h = w * image.size.height / image.size.width

        // Centre vertically when the image is shorter than the screen
        let originY = h < containerSize.height ? (containerSize.height - h) / 2 : 0
        imageView.frame = CGRect(x: 0, y: originY, width: w, height: h)

        // Content height is at least the screen height so the view fills the space
        scrollView.contentSize = CGSize(width: w, height: max(h, containerSize.height))
    }
}

// MARK: - Coordinator

private final class Coordinator: NSObject, UIScrollViewDelegate {
    weak var scrollView: UIScrollView?
    weak var imageView: UIImageView?
    var lastResetToken: Int = 0
    var containerSize: CGSize = .zero

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContent(in: scrollView)
    }

    private func centerContent(in scrollView: UIScrollView) {
        guard let imageView else { return }
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        imageView.center = CGPoint(
            x: scrollView.contentSize.width / 2 + offsetX,
            y: scrollView.contentSize.height / 2 + offsetY
        )
    }

    @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard let scrollView else { return }
        if scrollView.zoomScale > 1 {
            scrollView.setZoomScale(1.0, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let scale: CGFloat = 2.5
            let w = scrollView.bounds.width / scale
            let h = scrollView.bounds.height / scale
            scrollView.zoom(
                to: CGRect(x: point.x - w / 2, y: point.y - h / 2, width: w, height: h),
                animated: true
            )
        }
    }
}
#endif
