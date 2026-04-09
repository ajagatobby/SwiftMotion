//
//  SharedElementTransition.swift
//  Motion
//
//  Created by Abdulbasit Ajaga on 02/04/2026.

import SwiftUI
import UIKit

// MARK: - Seed phrase data

private let seedWords: [(Int, String)] = [
    (1, "pledge"), (2, "unveil"), (3, "smoke"), (4, "butter"),
    (5, "only"), (6, "number"), (7, "metal"), (8, "surge"),
    (9, "goddess"), (10, "balance"), (11, "undo"), (12, "fox"),
]

// MARK: - Continue button (shared element)

struct ContinueButton: View {
    var body: some View {
        Text("Continue")
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.56, green: 0.39, blue: 0.95),
                                Color(red: 0.65, green: 0.45, blue: 0.98),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .clipShape(Capsule())
    }
}

// MARK: - Seed phrase grid

struct SeedPhraseGrid: View {
    let words: [(Int, String)]

    var body: some View {
        let left = Array(words.prefix(6))
        let right = Array(words.suffix(6))

        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(left, id: \.0) { index, word in
                    seedRow(index: index, word: word)
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                ForEach(right, id: \.0) { index, word in
                    seedRow(index: index, word: word)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.58, green: 0.42, blue: 0.95),
                            Color(red: 0.68, green: 0.50, blue: 0.98),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private func seedRow(index: Int, word: String) -> some View {
        HStack(spacing: 8) {
            Text("\(index)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 20, alignment: .trailing)
            Text(word)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .underline()
        }
    }
}

// MARK: - Main view

struct SharedElementTransition: View {
    @Namespace private var ns
    @State private var showModal = false
    @State private var buttonPressed = false

    // Modal content stagger
    @State private var showIcon = false
    @State private var showTitle = false
    @State private var showDescription = false

    // Drag to dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var dismissProgress: CGFloat = 0

    // Button breathing
    @State private var buttonBreathing = false

    var body: some View {
        ZStack {
            // ── Main screen ──
            mainScreen

            // ── Dimmed backdrop ──
            if showModal {
                Color.black.opacity(0.4 * (1.0 - dismissProgress))
                    .ignoresSafeArea()
                    .transition(.opacity.animation(.easeOut(duration: 0.25)))
                    .onTapGesture { dismiss() }
            }

            // ── Floating modal ──
            if showModal {
                VStack {
                    Spacer()
                    modalContent
                        .offset(y: dragOffset)
                        .gesture(dragToDismiss)
                        .padding(.bottom, 8)
                }
                .transition(.move(edge: .bottom))
            }
        }
        // No implicit .animation — all animations are explicit via withAnimation
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                buttonBreathing = true
            }
        }
    }

    // MARK: - Main screen

    private var mainScreen: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "questionmark.circle")
                    .font(.title3)
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 8) {
                Text("iCloud Backup")
                    .font(.largeTitle.weight(.bold))
                Text("Store an encrypted version of your\nSecret Recovery Phrase on iCloud.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 24)

            Spacer()

            SeedPhraseGrid(words: seedWords)
                .padding(.horizontal, 20)

            HStack(spacing: 6) {
                Image(systemName: "doc.on.doc")
                    .font(.subheadline)
                Text("Copy to Clipboard")
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
            .padding(.top, 16)

            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "shield.checkered")
                    .font(.title2)
                    .foregroundStyle(.gray.opacity(0.4))

                Text("After pressing Continue, you'll secure this wallet\nwithin your existing iCloud Backup.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.bottom, 16)

            // Continue button — main screen state
            if !showModal {
                ContinueButton()
                    .matchedGeometryEffect(id: "cta", in: ns)
                    .scaleEffect(buttonPressed ? 0.95 : (buttonBreathing ? 1.01 : 1.0))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .onTapGesture {
                        // Anticipation: press down first
                        let pressHaptic = UIImpactFeedbackGenerator(style: .light)
                        pressHaptic.impactOccurred()

                        withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                            buttonPressed = true
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            buttonPressed = false
                            present()
                        }
                    }
            } else {
                Color.clear
                    .frame(height: 56)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Modal card

    private var modalContent: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.title)
                        .foregroundStyle(.gray)
                        .scaleEffect(showIcon ? 1.0 : 0.4)
                        .opacity(showIcon ? 1 : 0)

                    Spacer()

                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.gray.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(.gray.opacity(0.12)))
                    }
                    .opacity(showIcon ? 1 : 0)
                }

                Text("An existing iCloud\nBackup is available")
                    .font(.title2.weight(.bold))
                    .lineSpacing(2)
                    .offset(y: showTitle ? 0 : 12)
                    .opacity(showTitle ? 1 : 0)

                Text("You've already enabled iCloud Backup for at least one of your other wallets.\n\nOn the next step, simply enter your existing password to add your new wallet to your current iCloud Backup.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .offset(y: showDescription ? 0 : 12)
                    .opacity(showDescription ? 1 : 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Continue button — modal state (shared element)
            ContinueButton()
                .matchedGeometryEffect(id: "cta", in: ns)
                .onTapGesture { dismiss() }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.16), radius: 30, y: 0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 12)
    }

    // MARK: - Drag to dismiss

    private var dragToDismiss: some Gesture {
        DragGesture()
            .onChanged { value in
                let raw = value.translation.height
                // Rubber band: pulling up is resisted, pulling down stretches with diminishing returns
                if raw > 0 {
                    dragOffset = pow(raw, 0.72)
                } else {
                    dragOffset = raw * 0.25
                }
                dismissProgress = min(max(dragOffset / 300, 0), 1)
            }
            .onEnded { value in
                if value.translation.height > 120 || value.predictedEndTranslation.height > 250 {
                    dismiss()
                } else {
                    // Snap back with bounce
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.68)) {
                        dragOffset = 0
                        dismissProgress = 0
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }

    // MARK: - Present & dismiss

    private func present() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
            showModal = true
        }
        withAnimation(.easeOut(duration: 0.25).delay(0.08)) {
            showIcon = true
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.12)) {
            showTitle = true
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.16)) {
            showDescription = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showDescription = false
            showTitle = false
            showIcon = false
            showModal = false
            dragOffset = 0
            dismissProgress = 0
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

#Preview {
    SharedElementTransition()
}
