import SwiftUI
import Combine

struct BurnDissolveTextView: View {
    @State private var touchX: Float = 0
    @State private var touchY: Float = 0
    @State private var burnRadius: Float = 0
    @State private var time: Float = 0
    @State private var isDragging = false

    @State private var targetTouchX: Float = 0
    @State private var targetTouchY: Float = 0
    @State private var targetBurnRadius: Float = 0

    @State private var displayLink: AnyCancellable?

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            Text("Burn")
                .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 90))
                .foregroundStyle(.black)
                .padding(60)
                .colorEffect(
                    ShaderLibrary.burnEffect(
                        .float(touchX),
                        .float(touchY),
                        .float(burnRadius),
                        .float(time)
                    )
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            targetTouchX = Float(value.location.x)
                            targetTouchY = Float(value.location.y)
                            targetBurnRadius = min(targetBurnRadius + 1.5, 300)
                        }
                        .onEnded { _ in
                            isDragging = false
                            targetBurnRadius = 0
                        }
                )

            Text("drag to burn")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
        }
        .onAppear {
            startDisplayLink()
        }
        .onDisappear {
            displayLink?.cancel()
        }
    }

    private func startDisplayLink() {
        displayLink = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                let smoothing: Float = 0.12
                touchX += (targetTouchX - touchX) * smoothing
                touchY += (targetTouchY - touchY) * smoothing
                burnRadius += (targetBurnRadius - burnRadius) * smoothing
                time += 1.0 / 60.0
            }
    }
}

#Preview {
    BurnDissolveTextView()
}
