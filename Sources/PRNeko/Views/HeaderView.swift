import SwiftUI
import AppKit
import ImageIO

struct HeaderView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var catFrames: [NSImage] = []
    @State private var staticImage: NSImage?
    @State private var currentFrame: Int = 0
    @State private var animationTimer: Timer?
    @State private var lastLoadedState: AnimationState?

    var body: some View {
        mainContent
    }

    private var mainContent: some View {
        HStack(spacing: 12) {
            // Cat Image Section (left side)
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.05))

                // Cat image - either animated GIF frames or static PNG
                if viewModel.animationState.isAnimated && !catFrames.isEmpty {
                    if viewModel.animationState.useFillMode {
                        Image(nsImage: catFrames[currentFrame])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 130, height: 130)
                            .clipped()
                    } else {
                        Image(nsImage: catFrames[currentFrame])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(viewModel.animationState.imageScale)
                            .frame(maxWidth: 120, maxHeight: 120)
                    }
                } else if let image = staticImage {
                    if viewModel.animationState.useFillMode {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 130, height: 130)
                            .clipped()
                    } else {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(viewModel.animationState.imageScale)
                            .frame(maxWidth: 120, maxHeight: 120)
                    }
                }
            }
            .frame(width: 130, height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onAppear {
                loadImageForCurrentState()
            }
            .onDisappear {
                animationTimer?.invalidate()
            }
            .onChange(of: viewModel.animationState) { newState in
                loadImageForCurrentState()
            }

            // Status (right side)
            VStack(alignment: .leading, spacing: 12) {
                // Mood indicator
                HStack(spacing: 6) {
                    Image(systemName: viewModel.mood.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(moodColor)
                    Text(viewModel.mood.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                }

                // Queue counts
                VStack(alignment: .leading, spacing: 4) {
                    if viewModel.pendingReviews.count > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "eye")
                                .font(.system(size: 10))
                            Text("\(viewModel.pendingReviews.count) to review")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.orange)
                    }
                    if viewModel.mergeReady.count > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 10))
                            Text("\(viewModel.mergeReady.count) ready to merge")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.green)
                    }
                    if viewModel.blocked.count > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 10))
                            Text("\(viewModel.blocked.count) blocked")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.red)
                    }
                    if viewModel.totalActionableItems == 0 {
                        Text("All clear!")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(10)
    }

    private func loadImageForCurrentState() {
        let state = viewModel.animationState

        // Skip if already loaded this state
        if lastLoadedState == state { return }
        lastLoadedState = state

        // Stop existing animation
        animationTimer?.invalidate()
        animationTimer = nil

        let fileName = state.imageFileName

        // Try Bundle resources first (for .app distribution), then fall back to dev path
        let basePath: String
        if let resourcePath = Bundle.main.resourcePath {
            basePath = resourcePath
        } else {
            // Fallback for development
            basePath = NSString(string: "~/Documents/petDesktop/asset").expandingTildeInPath
        }

        if state.isAnimated {
            // Load animated GIF
            let gifPath = "\(basePath)/\(fileName).gif"
            loadGifFrames(from: gifPath)
            startAnimation()
        } else {
            // Load static PNG
            let pngPath = "\(basePath)/\(fileName).png"
            loadStaticImage(from: pngPath)
        }
    }

    private func loadStaticImage(from path: String) {
        catFrames = []
        currentFrame = 0

        let url = URL(fileURLWithPath: path)
        if let image = NSImage(contentsOf: url) {
            staticImage = image
        }
    }

    private func loadGifFrames(from path: String) {
        staticImage = nil
        catFrames = []
        currentFrame = 0

        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }

        let frameCount = CGImageSourceGetCount(source)
        for i in 0..<frameCount {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                catFrames.append(image)
            }
        }
    }

    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.22, repeats: true) { _ in
            if !catFrames.isEmpty {
                currentFrame = (currentFrame + 1) % catFrames.count
            }
        }
    }

    private var moodColor: Color {
        switch viewModel.mood {
        case .anxious: return .red
        case .hungry: return .orange
        case .excited: return .yellow
        case .idle: return .gray
        }
    }
}
