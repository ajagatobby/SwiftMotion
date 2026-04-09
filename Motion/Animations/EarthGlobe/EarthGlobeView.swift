import SwiftUI
import UIKit

// MARK: - Preloaded thumbnail cache

private let globeThumbnailCache: [String: UIImage] = {
    var cache = [String: UIImage]()
    for (name, ext) in [
        ("earth_daymap", "jpg"), ("earth_nightmap", "jpg"),
        ("earth_normal_map", "tif"), ("earth_specular_map", "tif"),
        ("earth_clouds", "jpg"),
    ] {
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Textures")
            ?? Bundle.main.url(forResource: name, withExtension: ext),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            cache[name] = img
        }
    }
    return cache
}()

// MARK: - Data

private struct GlobeTextureItem: Identifiable {
    let id: Int
    let name: String
    let imageName: String
    let icon: String
}

private let globeTextures: [GlobeTextureItem] = [
    GlobeTextureItem(id: 1, name: "Day", imageName: "earth_daymap", icon: "sun.max.fill"),
    GlobeTextureItem(id: 2, name: "Night", imageName: "earth_nightmap", icon: "moon.stars.fill"),
    GlobeTextureItem(id: 3, name: "Normal", imageName: "earth_normal_map", icon: "mountain.2.fill"),
    GlobeTextureItem(id: 4, name: "Specular", imageName: "earth_specular_map", icon: "drop.fill"),
    GlobeTextureItem(id: 5, name: "Clouds", imageName: "earth_clouds", icon: "cloud.fill"),
]

private let globeLiquidSpring = Animation.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.1)

// MARK: - Earth Globe View

struct EarthGlobeView: View {

    @State private var activeTextureIndex = 0
    @State private var zoom: Float = 3.0
    @State private var isDarkBackground = true
    @Namespace private var globeSelectionNS

    private let minZoom: Float = 1.5
    private let maxZoom: Float = 8.0

    private var bgColor: Color { isDarkBackground ? .black : .white }
    private var fgColor: Color { isDarkBackground ? .white : .black }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            MetalGlobeView(activeTextureIndex: $activeTextureIndex, zoom: $zoom, isDarkBackground: isDarkBackground)
                .ignoresSafeArea()

            // Zoom — left
            zoomControls
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, 16)

            // Textures — right
            textureSelector
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 14)

            // Tag — bottom
            activeTag
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 44)

            // Background toggle — top-left
            Button {
                withAnimation(globeLiquidSpring) {
                    isDarkBackground.toggle()
                }
            } label: {
                Image(systemName: isDarkBackground ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(fgColor)
                    .frame(width: 38, height: 38)
                    .background(fgColor.opacity(0.08), in: Circle())
            }
            .buttonStyle(GlobeLiquidButtonStyle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 60)
            .padding(.leading, 16)
        }
    }

    // MARK: - Zoom

    private var zoomControls: some View {
        VStack(spacing: 10) {
            Button { zoom = max(zoom - 0.5, minZoom) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(fgColor)
                    .frame(width: 34, height: 34)
                    .background(fgColor.opacity(0.08), in: Circle())
            }

            GlobeZoomSlider(value: $zoom, range: minZoom...maxZoom, trackColor: fgColor)
                .frame(width: 34, height: 170)

            Button { zoom = min(zoom + 0.5, maxZoom) } label: {
                Image(systemName: "minus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(fgColor)
                    .frame(width: 34, height: 34)
                    .background(fgColor.opacity(0.08), in: Circle())
            }
        }
    }

    // MARK: - Texture Selector

    private var textureSelector: some View {
        VStack(spacing: 8) {
            globeThumbnailButton(id: 0, label: "All", image: nil, icon: "globe")

            ForEach(globeTextures) { item in
                globeThumbnailButton(
                    id: item.id,
                    label: item.name,
                    image: globeThumbnailCache[item.imageName],
                    icon: item.icon
                )
            }
        }
    }

    private func globeThumbnailButton(id: Int, label: String, image: UIImage?, icon: String) -> some View {
        let selected = activeTextureIndex == id
        return Button {
            withAnimation(globeLiquidSpring) {
                activeTextureIndex = id
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if selected {
                        RoundedRectangle(cornerRadius: 11)
                            .fill(.blue.opacity(0.2))
                            .matchedGeometryEffect(id: "globe_sel_bg", in: globeSelectionNS)

                        RoundedRectangle(cornerRadius: 11)
                            .strokeBorder(Color.blue.opacity(0.7), lineWidth: 2)
                            .matchedGeometryEffect(id: "globe_sel_border", in: globeSelectionNS)
                    }

                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(fgColor.opacity(selected ? 1.0 : 0.6))
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(
                            fgColor.opacity(selected ? 0 : 0.12),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: selected ? .blue.opacity(0.3) : .clear, radius: 8, y: 2)
                .scaleEffect(selected ? 1.06 : 1.0)

                Text(label)
                    .font(.system(size: 9, weight: selected ? .semibold : .regular))
                    .foregroundStyle(fgColor.opacity(selected ? 1 : 0.45))
            }
        }
        .buttonStyle(GlobeLiquidButtonStyle())
    }

    // MARK: - Active Tag

    @ViewBuilder
    private var activeTag: some View {
        let activeName = activeTextureIndex == 0
            ? "All Layers"
            : (globeTextures.first { $0.id == activeTextureIndex }?.name ?? "")

        HStack(spacing: 6) {
            Circle()
                .fill(.blue)
                .frame(width: 6, height: 6)

            Text(activeName.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(fgColor.opacity(0.85))
                .tracking(1.5)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(fgColor.opacity(0.06))
                .overlay(
                    Capsule()
                        .strokeBorder(fgColor.opacity(0.08), lineWidth: 0.5)
                )
        )
        .animation(globeLiquidSpring, value: activeTextureIndex)
    }
}

// MARK: - Globe Liquid Button Style

private struct GlobeLiquidButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Globe Zoom Slider

private struct GlobeZoomSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    var trackColor: Color = .white

    var body: some View {
        GeometryReader { geo in
            let trackH = geo.size.height - 10
            let frac = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let thumbY = frac * trackH

            ZStack(alignment: .top) {
                Capsule()
                    .fill(trackColor.opacity(0.1))
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)

                Circle()
                    .fill(trackColor)
                    .frame(width: 10, height: 10)
                    .offset(y: thumbY)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let clamped = min(max(drag.location.y - 5, 0), trackH)
                        value = range.lowerBound + Float(clamped / trackH) * (range.upperBound - range.lowerBound)
                    }
            )
        }
    }
}

#Preview {
    EarthGlobeView()
}
