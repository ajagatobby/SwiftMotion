//
//  GlitchTextView.swift
//  Motion

import SwiftUI
import Combine

struct GlitchTextView: View {

    @State private var time: Double = 0.0
    @State private var intensity: Double = 0.0
    @State private var isActive = false

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            Text("Glitch")
                .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 90))
                .foregroundStyle(.black)
                .padding(60)
                .layerEffect(
                    ShaderLibrary.glitchEffect(
                        .float2(400, 200),
                        .float(time),
                        .float(intensity)
                    ),
                    maxSampleOffset: CGSize(width: 80, height: 0)
                )
                .onReceive(timer) { _ in
                    time += 1.0 / 60.0
                }
                .onTapGesture {
                    isActive.toggle()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        intensity = isActive ? 1.0 : 0.0
                    }
                }

            Text(isActive ? "tap to fix" : "tap to glitch")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
                .contentTransition(.numericText())
                .animation(.easeInOut, value: isActive)
        }
    }
}

#Preview {
    GlitchTextView()
}
