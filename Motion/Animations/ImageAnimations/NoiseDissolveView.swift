import SwiftUI

struct NoiseDissolveView: View {
    @State private var threshold: Double = 0.0
    @State private var dissolved = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                Image("eagle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 320)
                    .padding(40)
                    .colorEffect(
                        ShaderLibrary.noiseDissolveEffect(
                            .float(threshold),
                            .float(0.05)
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .onTapGesture {
                        dissolved.toggle()
                        withAnimation(.spring(response: 1.2, dampingFraction: 0.8)) {
                            threshold = dissolved ? 1.0 : 0.0
                        }
                    }

                Slider(value: $threshold, in: 0...1)
                    .tint(.orange)
                    .padding(.horizontal, 40)

                Spacer()
            }

            Text("tap or slide to dissolve")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
        }
    }
}

#Preview {
    NoiseDissolveView()
}
