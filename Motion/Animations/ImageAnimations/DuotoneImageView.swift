import SwiftUI

struct DuotonePalette: Identifiable {
    let id = UUID()
    let name: String
    let shadow: SIMD3<Float>
    let highlight: SIMD3<Float>
}

struct DuotoneImageView: View {
    private let palettes: [DuotonePalette] = [
        DuotonePalette(name: "Cyan/Magenta", shadow: SIMD3(0.0, 0.2, 0.4), highlight: SIMD3(1.0, 0.2, 0.6)),
        DuotonePalette(name: "Orange/Teal", shadow: SIMD3(0.0, 0.3, 0.3), highlight: SIMD3(1.0, 0.5, 0.1)),
        DuotonePalette(name: "Purple/Gold", shadow: SIMD3(0.2, 0.0, 0.3), highlight: SIMD3(1.0, 0.85, 0.2)),
        DuotonePalette(name: "Navy/Coral", shadow: SIMD3(0.05, 0.05, 0.2), highlight: SIMD3(1.0, 0.4, 0.35)),
    ]

    @State private var selectedIndex: Int = 0
    @State private var intensity: Double = 1.0

    private var currentPalette: DuotonePalette { palettes[selectedIndex] }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image("eagle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 320)
                    .padding(40)
                    .colorEffect(
                        ShaderLibrary.duotoneEffect(
                            .float3(currentPalette.shadow.x, currentPalette.shadow.y, currentPalette.shadow.z),
                            .float3(currentPalette.highlight.x, currentPalette.highlight.y, currentPalette.highlight.z),
                            .float(intensity)
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4)) {
                            intensity = intensity > 0.5 ? 0.0 : 1.0
                        }
                    }

                HStack(spacing: 12) {
                    ForEach(Array(palettes.enumerated()), id: \.element.id) { index, palette in
                        Button {
                            withAnimation(.spring(response: 0.4)) {
                                selectedIndex = index
                                intensity = 1.0
                            }
                        } label: {
                            VStack(spacing: 4) {
                                HStack(spacing: 2) {
                                    Circle()
                                        .fill(Color(
                                            red: Double(palette.shadow.x),
                                            green: Double(palette.shadow.y),
                                            blue: Double(palette.shadow.z)
                                        ))
                                        .frame(width: 14, height: 14)
                                    Circle()
                                        .fill(Color(
                                            red: Double(palette.highlight.x),
                                            green: Double(palette.highlight.y),
                                            blue: Double(palette.highlight.z)
                                        ))
                                        .frame(width: 14, height: 14)
                                }
                                Text(palette.name)
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.black.opacity(0.5))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selectedIndex == index ? Color.black.opacity(0.08) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }

            Text("tap image to toggle / pick palette")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
        }
    }
}

#Preview {
    DuotoneImageView()
}
