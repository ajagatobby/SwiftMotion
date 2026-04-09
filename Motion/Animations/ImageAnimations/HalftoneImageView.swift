import SwiftUI
import Combine

struct HalftoneImageView: View {
    @State private var time: Double = 0
    @State private var dotSize: Double = 8.0
    @State private var intensity: Double = 1.0

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 20) {
                Image("eagle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 320)
                    .padding(40)
                    .colorEffect(
                        ShaderLibrary.halftoneEffect(
                            .float(dotSize),
                            .float(intensity),
                            .float(time)
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4)) {
                            intensity = intensity > 0.5 ? 0.0 : 1.0
                        }
                    }

                HStack {
                    Text("Dot Size")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.4))
                    Slider(value: $dotSize, in: 4...20)
                        .tint(.black.opacity(0.3))
                }
                .padding(.horizontal, 40)
            }

            Text("tap/drag to halftone")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
        }
        .onReceive(timer) { _ in
            time += 1.0 / 60.0
        }
    }
}

#Preview {
    HalftoneImageView()
}
