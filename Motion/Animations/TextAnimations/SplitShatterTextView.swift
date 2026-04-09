import SwiftUI

struct SplitShatterTextView: View {
    private let text = "Shatter"
    @State private var isShattered = false

    @State private var offsets: [CGSize]
    @State private var rotations: [Double]
    @State private var scales: [Double]
    @State private var opacities: [Double]

    init() {
        let count = "Shatter".count
        _offsets = State(initialValue: Array(repeating: .zero, count: count))
        _rotations = State(initialValue: Array(repeating: 0.0, count: count))
        _scales = State(initialValue: Array(repeating: 1.0, count: count))
        _opacities = State(initialValue: Array(repeating: 1.0, count: count))
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            HStack(spacing: 0) {
                ForEach(Array(text.enumerated()), id: \.offset) { index, char in
                    Text(String(char))
                        .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 60))
                        .foregroundStyle(.black)
                        .offset(offsets[index])
                        .rotationEffect(.degrees(rotations[index]))
                        .scaleEffect(scales[index])
                        .opacity(opacities[index])
                }
            }

            Text("tap to shatter")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
        }
        .onTapGesture {
            if isShattered {
                reassemble()
            } else {
                shatter()
            }
            isShattered.toggle()
        }
    }

    private func shatter() {
        for i in 0..<text.count {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(i) * 0.05)) {
                offsets[i] = CGSize(
                    width: CGFloat.random(in: -200...200),
                    height: CGFloat.random(in: -400...400)
                )
                rotations[i] = Double.random(in: -180...180)
                scales[i] = Double.random(in: 0.3...1.8)
                opacities[i] = Double.random(in: 0.2...0.6)
            }
        }
    }

    private func reassemble() {
        for i in 0..<text.count {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(i) * 0.05)) {
                offsets[i] = .zero
                rotations[i] = 0
                scales[i] = 1.0
                opacities[i] = 1.0
            }
        }
    }
}

#Preview {
    SplitShatterTextView()
}
