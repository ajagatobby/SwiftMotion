import SwiftUI
import Combine

struct PixelSortTextView: View {
    @State private var intensity: CGFloat = 0
    @State private var isSorting = false
    @State private var time: Float = 0
    @State private var timer: AnyCancellable?

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            GeometryReader { geo in
                Text("Sort")
                    .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 90))
                    .foregroundStyle(.black)
                    .padding(60)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layerEffect(
                        ShaderLibrary.pixelSortEffect(
                            .float2(geo.size),
                            .float(Float(intensity)),
                            .float(time)
                        ),
                        maxSampleOffset: CGSize(width: 100, height: 0)
                    )
            }

            Text("tap to sort")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
        }
        .onTapGesture {
            isSorting.toggle()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                intensity = isSorting ? 1.0 : 0.0
            }
        }
        .onAppear {
            timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    time += 1.0 / 60.0
                }
        }
        .onDisappear {
            timer?.cancel()
        }
    }
}

#Preview {
    PixelSortTextView()
}
