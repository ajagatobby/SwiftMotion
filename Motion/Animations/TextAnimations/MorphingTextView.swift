import SwiftUI
import Combine

struct MorphingTextView: View {
    private let words = ["Hello", "World"]
    @State private var currentIndex = 0
    @State private var scale: CGFloat = 1.0
    @State private var timer: AnyCancellable?

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            Text(words[currentIndex])
                .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 90))
                .foregroundStyle(.black)
                .contentTransition(.numericText())
                .scaleEffect(scale)

            Text("tap to morph")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.cancel()
        }
    }

    private func startTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                switchWord()
            }
    }

    private func switchWord() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            scale = 0.85
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                currentIndex = (currentIndex + 1) % words.count
                scale = 1.0
            }
        }
    }
}

#Preview {
    MorphingTextView()
}
