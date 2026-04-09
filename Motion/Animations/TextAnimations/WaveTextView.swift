//
//  WaveTextView.swift
//  Motion

import SwiftUI
import Combine

struct WaveTextView: View {

    @State private var time: Double = 0.0
    @State private var intensity: Double = 0.0
    @State private var isActive = false

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            Text("Waves")
                .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 90))
                .foregroundStyle(.black)
                .padding(60)
                .distortionEffect(
                    ShaderLibrary.waveEffect(
                        .float2(400, 200),
                        .float(time),
                        .float(intensity),
                        .float(1.0)
                    ),
                    maxSampleOffset: CGSize(width: 100, height: 100)
                )
                .onReceive(timer) { _ in
                    time += 1.0 / 60.0
                }
                .onTapGesture {
                    isActive.toggle()
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                        intensity = isActive ? 1.0 : 0.0
                    }
                }

            Text(isActive ? "tap to calm" : "tap to ripple")
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
    WaveTextView()
}
