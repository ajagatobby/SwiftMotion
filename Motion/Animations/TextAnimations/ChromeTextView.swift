import SwiftUI
import Combine
import CoreMotion

class ChromeMotionManager: ObservableObject {
    private let manager = CMMotionManager()
    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    private let smoothing: Double = 0.15

    init() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion = motion, let self = self else { return }
            self.pitch = self.pitch * (1.0 - self.smoothing) + motion.attitude.pitch * self.smoothing
            self.roll = self.roll * (1.0 - self.smoothing) + motion.attitude.roll * self.smoothing
        }
    }

    deinit {
        manager.stopDeviceMotionUpdates()
    }
}

struct ChromeTextView: View {
    @StateObject private var motionManager = ChromeMotionManager()
    @State private var time: Float = 0
    @State private var timer: AnyCancellable?

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            GeometryReader { geo in
                let angleX = motionManager.roll != 0 ? Float(motionManager.roll) : Float(sin(Double(time) * 0.5))
                let angleY = motionManager.pitch != 0 ? Float(motionManager.pitch) : Float(cos(Double(time) * 0.3))

                Text("Chrome")
                    .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 75))
                    .foregroundStyle(.black)
                    .padding(60)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .colorEffect(
                        ShaderLibrary.chromeEffect(
                            .float2(geo.size),
                            .float2(angleX, angleY),
                            .float(time)
                        )
                    )
            }

            Text("tilt to reflect")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
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
    ChromeTextView()
}
