import SwiftUI
import CoreMotion
import Combine

class ParallaxMotionManager: ObservableObject {
    private let manager = CMMotionManager()
    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    private let smoothing: Double = 0.15

    init() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion, let self else { return }
            self.pitch = self.pitch * (1.0 - self.smoothing) + motion.attitude.pitch * self.smoothing
            self.roll = self.roll * (1.0 - self.smoothing) + motion.attitude.roll * self.smoothing
        }
    }

    deinit { manager.stopDeviceMotionUpdates() }
}

struct ParallaxImageView: View {
    @State private var dragOffset: CGSize = .zero
    @State private var currentTilt: CGPoint = .zero

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            Image("eagle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 320)
                .padding(40)
                .distortionEffect(
                    ShaderLibrary.parallaxEffect(
                        .float2(320, 400),
                        .float2(currentTilt.x, currentTilt.y),
                        .float(1.0)
                    ),
                    maxSampleOffset: CGSize(width: 30, height: 30)
                )
                .rotation3DEffect(
                    .degrees(currentTilt.x * 8),
                    axis: (x: 0, y: 1, z: 0)
                )
                .rotation3DEffect(
                    .degrees(-currentTilt.y * 8),
                    axis: (x: 1, y: 0, z: 0)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let x = value.translation.width / 150.0
                            let y = value.translation.height / 150.0
                            withAnimation(.interactiveSpring(response: 0.1)) {
                                currentTilt = CGPoint(
                                    x: min(max(x, -1), 1),
                                    y: min(max(y, -1), 1)
                                )
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                                currentTilt = .zero
                            }
                        }
                )

            Text("drag to tilt")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
        }
    }
}

#Preview {
    ParallaxImageView()
}
