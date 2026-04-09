//
//  VortexTextView.swift
//  Motion

import SwiftUI
import Combine

struct VortexTextView: View {

    @State private var time: Double = 0.0
    @State private var strength: Double = 0.0
    @State private var isActive = false

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

                Text("Vortex")
                    .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 90))
                    .foregroundStyle(.black)
                    .padding(60)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .distortionEffect(
                        ShaderLibrary.vortexEffect(
                            .float2(center),
                            .float(time),
                            .float(strength),
                            .float(200.0)
                        ),
                        maxSampleOffset: CGSize(width: 150, height: 150)
                    )
                    .onReceive(timer) { _ in
                        time += 1.0 / 60.0
                    }
                    .onTapGesture {
                        isActive.toggle()
                        withAnimation(.spring(response: 0.9, dampingFraction: 0.55)) {
                            strength = isActive ? 3.0 : 0.0
                        }
                    }
            }

            Text(isActive ? "tap to unwind" : "tap to swirl")
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
    VortexTextView()
}
