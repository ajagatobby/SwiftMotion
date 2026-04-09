import SwiftUI

struct KineticTextView: View {
    private let text = "Kinetic"
    private let amplitude: CGFloat = 20
    private let phaseOffset: Double = 0.8

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                HStack(spacing: 0) {
                    ForEach(Array(text.enumerated()), id: \.offset) { index, char in
                        let yOffset = sin(time * 3.0 + Double(index) * phaseOffset) * amplitude

                        Text(String(char))
                            .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 70))
                            .foregroundStyle(.black)
                            .offset(y: yOffset)
                    }
                }
            }

            Text("tap to enjoy")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
        }
    }
}

#Preview {
    KineticTextView()
}
