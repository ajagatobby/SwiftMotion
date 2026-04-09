import SwiftUI
import Combine

struct TypewriterTextView: View {
    private let fullText = "Typewriter"
    @State private var visibleCount = 0
    @State private var isDeleting = false
    @State private var cursorVisible = true
    @State private var timer: AnyCancellable?
    @State private var cursorTimer: AnyCancellable?

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            HStack(spacing: 0) {
                Text(String(fullText.prefix(visibleCount)))
                    .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 50))
                    .foregroundStyle(.black)

                Text("|")
                    .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 50))
                    .foregroundStyle(.black)
                    .opacity(cursorVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: cursorVisible)
            }

            Text("tap to restart")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
        }
        .onAppear {
            startCursorBlink()
            startTyping()
        }
        .onDisappear {
            timer?.cancel()
            cursorTimer?.cancel()
        }
        .onTapGesture {
            restart()
        }
    }

    private func startCursorBlink() {
        cursorTimer?.cancel()
        cursorTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                cursorVisible.toggle()
            }
    }

    private func startTyping() {
        timer?.cancel()
        isDeleting = false
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if !isDeleting {
                    if visibleCount < fullText.count {
                        visibleCount += 1
                    } else {
                        timer?.cancel()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            startDeleting()
                        }
                    }
                }
            }
    }

    private func startDeleting() {
        isDeleting = true
        timer?.cancel()
        timer = Timer.publish(every: 0.06, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if visibleCount > 0 {
                    visibleCount -= 1
                } else {
                    timer?.cancel()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        startTyping()
                    }
                }
            }
    }

    private func restart() {
        timer?.cancel()
        visibleCount = 0
        isDeleting = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            startTyping()
        }
    }
}

#Preview {
    TypewriterTextView()
}
