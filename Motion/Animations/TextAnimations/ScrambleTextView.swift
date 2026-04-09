import SwiftUI
import Combine

struct ScrambleTextView: View {
    private let targetText = "Decode"
    private let scrambleChars = Array("!@#$%^&*ABCXYZ0123456789")
    @State private var displayedChars: [Character] = []
    @State private var resolvedCount = 0
    @State private var timer: AnyCancellable?
    @State private var tickCount = 0

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            HStack(spacing: 2) {
                ForEach(Array(displayedChars.enumerated()), id: \.offset) { _, char in
                    Text(String(char))
                        .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 80))
                        .foregroundStyle(.black)
                }
            }

            Text("tap to decode")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
        }
        .onAppear {
            startScramble()
        }
        .onDisappear {
            timer?.cancel()
        }
        .onTapGesture {
            startScramble()
        }
    }

    private func startScramble() {
        timer?.cancel()
        resolvedCount = 0
        tickCount = 0

        let targetArray = Array(targetText)
        displayedChars = targetArray.map { _ in scrambleChars.randomElement()! }

        let resolveEveryNTicks = 4

        timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                tickCount += 1
                let targetArray = Array(targetText)

                if tickCount % resolveEveryNTicks == 0 && resolvedCount < targetArray.count {
                    resolvedCount += 1
                }

                var newChars: [Character] = []
                for i in 0..<targetArray.count {
                    if i < resolvedCount {
                        newChars.append(targetArray[i])
                    } else {
                        newChars.append(scrambleChars.randomElement()!)
                    }
                }
                displayedChars = newChars

                if resolvedCount >= targetArray.count {
                    timer?.cancel()
                }
            }
    }
}

#Preview {
    ScrambleTextView()
}
