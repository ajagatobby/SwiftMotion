import SwiftUI

struct FlipRevealTextView: View {
    private let text = "Reveal"
    @State private var revealed: [Bool]

    init() {
        _revealed = State(initialValue: Array(repeating: false, count: "Reveal".count))
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            HStack(spacing: 0) {
                ForEach(Array(text.enumerated()), id: \.offset) { index, char in
                    Text(String(char))
                        .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 80))
                        .foregroundStyle(.black)
                        .rotation3DEffect(
                            .degrees(revealed[index] ? 0 : 90),
                            axis: (x: 1, y: 0, z: 0)
                        )
                        .opacity(revealed[index] ? 1 : 0)
                }
            }

            Text("tap to reveal")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
        }
        .onAppear {
            triggerReveal()
        }
        .onTapGesture {
            replay()
        }
    }

    private func triggerReveal() {
        for i in 0..<text.count {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(i) * 0.08)) {
                revealed[i] = true
            }
        }
    }

    private func replay() {
        for i in 0..<text.count {
            revealed[i] = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            triggerReveal()
        }
    }
}

#Preview {
    FlipRevealTextView()
}
