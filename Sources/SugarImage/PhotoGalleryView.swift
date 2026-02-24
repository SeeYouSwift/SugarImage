import SwiftUI
#if canImport(UIKit)

// MARK: - PhotoGalleryItem

/// Protocol for photo gallery items. Conform your model to this protocol.
public protocol PhotoGalleryItem: Identifiable {
    var imageURL: URL { get }
}

// MARK: - PhotoGalleryView

/// Full-screen photo viewer with swipe paging, pinch-to-zoom, and fade transitions.
///
/// Usage:
/// ```swift
/// PhotoGalleryView(items: photos, initialIndex: 2) { selectedItem in
///     // handle dismiss
/// }
/// ```
public struct PhotoGalleryView<Item: PhotoGalleryItem>: View {
    public let items: [Item]
    public let initialIndex: Int
    public let onDismiss: ((Item) -> Void)?

    @State private var currentIndex: Int
    @State private var zoomResetTokens: [Int]
    @State private var opacity: CGFloat = 0
    @State private var indicatorOffset: CGFloat

    public init(
        items: [Item],
        initialIndex: Int = 0,
        onDismiss: ((Item) -> Void)? = nil
    ) {
        self.items = items
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        self._currentIndex = State(initialValue: initialIndex)
        self._zoomResetTokens = State(initialValue: Array(repeating: 0, count: items.count))
        self._indicatorOffset = State(initialValue: CGFloat(initialIndex))
    }

    public var body: some View {
        GeometryReader { screen in
            let sw = screen.size.width
            let sh = screen.size.height

            ZStack {
                Color.black.ignoresSafeArea()

                TabView(selection: $currentIndex) {
                    ForEach(items.indices, id: \.self) { i in
                        ZoomableImageView(url: items[i].imageURL, resetToken: zoomResetTokens[i])
                            .frame(width: sw, height: sh)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
                .onChange(of: currentIndex) { _, newIndex in
                    withAnimation(.easeOut(duration: 0.2)) {
                        indicatorOffset = CGFloat(newIndex)
                    }
                    // Reset zoom on all pages except the current one
                    for i in items.indices where i != newIndex {
                        zoomResetTokens[i] += 1
                    }
                }

                closeButton

                if items.count > 1 {
                    VStack {
                        Spacer()
                        pageIndicator(indicatorOffset: indicatorOffset, containerWidth: sw)
                            .padding(.bottom, 32)
                    }
                }
            }
            .frame(width: sw, height: sh)
        }
        .opacity(opacity)
        .task {
            withAnimation(.easeInOut(duration: 0.25)) {
                opacity = 1
            }
        }
    }

    // MARK: - Dismiss

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.25)) {
            opacity = 0
        }
        let selected = items[currentIndex]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            onDismiss?(selected)
        }
    }

    // MARK: - Close button

    private var closeButton: some View {
        VStack {
            HStack {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(.regularMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            Spacer()
        }
    }

    // MARK: - Page indicator with thumbnails

    private func pageIndicator(indicatorOffset: CGFloat, containerWidth: CGFloat) -> some View {
        let h: CGFloat = 36
        let activeW: CGFloat = 54
        let inactiveW: CGFloat = 18
        let spacing: CGFloat = 6
        let radius: CGFloat = 3

        func itemWidth(_ i: Int) -> CGFloat {
            let fraction = max(0, 1 - abs(indicatorOffset - CGFloat(i)))
            return inactiveW + (activeW - inactiveW) * fraction
        }

        // Compute the center X of the active indicator within the HStack
        let activeIdx = Int(indicatorOffset.rounded())
        var activeCenterX: CGFloat = 0
        for i in items.indices {
            let w = itemWidth(i)
            if i == activeIdx {
                activeCenterX += w / 2
                break
            }
            activeCenterX += w + spacing
        }

        // Offset so the active indicator is always centred on screen
        let hstackOffset = containerWidth / 2 - activeCenterX

        return HStack(spacing: spacing) {
            ForEach(items.indices, id: \.self) { i in
                let fraction = max(0, 1 - abs(indicatorOffset - CGFloat(i)))
                let w = inactiveW + (activeW - inactiveW) * fraction

                CachedAsyncImage(url: items[i].imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .frame(width: activeW, height: h)
                    default:
                        Color.white.opacity(0.3)
                            .frame(width: activeW, height: h)
                    }
                }
                // Always render at full activeW, then clip to w (keeps content centred)
                .frame(width: activeW, height: h)
                .frame(width: w, height: h)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: radius))
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .strokeBorder(Color.white.opacity(fraction * 0.8), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
            }
        }
        .offset(x: hstackOffset)
        .frame(width: containerWidth, alignment: .leading)
        .clipped()
    }
}
#endif
