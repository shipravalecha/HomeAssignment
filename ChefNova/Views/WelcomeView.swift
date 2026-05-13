// WelcomeView.swift
// ChefNova
//
// Full-screen welcome screen shown before the main ingredient input flow.
// Transitions to IngredientInputView when the user taps "Get Started".

import SwiftUI

struct WelcomeView: View {

    // MARK: - Dependencies

    /// Factory that builds the fully-wired IngredientInputView.
    let makeIngredientInputView: () -> IngredientInputView

    // MARK: - Animation state

    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var titleOffset: CGFloat = 30
    @State private var titleOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 20
    @State private var floatingOffset: CGFloat = 0

    /// Triggers the full-screen transition to the main flow.
    @State private var showMain = false

    // MARK: - Body

    var body: some View {
        if showMain {
            makeIngredientInputView()
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
        } else {
            welcomeScreen
                .transition(.opacity)
        }
    }

    // MARK: - Welcome screen

    private var welcomeScreen: some View {
        ZStack {
            // ── Background ──────────────────────────────────────────────
            backgroundGradient

            // Decorative food emoji tiles (subtle, blurred)
            foodPatternOverlay

            // ── Content ─────────────────────────────────────────────────
            VStack(spacing: 0) {
                Spacer()

                // App icon / logo area
                logoSection
                    .offset(y: floatingOffset)

                Spacer().frame(height: 40)

                // App name + tagline
                textSection

                Spacer()

                // Get Started button
                getStartedButton

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, 32)
        }
        .ignoresSafeArea()
        .onAppear { runEntranceAnimation() }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.13, green: 0.08, blue: 0.04),   // deep espresso
                Color(red: 0.28, green: 0.12, blue: 0.04),   // dark mahogany
                Color(red: 0.55, green: 0.22, blue: 0.05),   // burnt sienna
                Color(red: 0.80, green: 0.38, blue: 0.08)    // warm amber
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Food pattern overlay

    private var foodPatternOverlay: some View {
        GeometryReader { geo in
            let emojis = ["🌿", "🧅", "🍅", "🌶️", "🧄", "🫚", "🌾", "🥕", "🫛", "🧆"]
            let columns = 5
            let rows = 8
            let cellW = geo.size.width / CGFloat(columns)
            let cellH = geo.size.height / CGFloat(rows)

            ZStack {
                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<columns, id: \.self) { col in
                        let index = (row * columns + col) % emojis.count
                        Text(emojis[index])
                            .font(.system(size: 28))
                            .opacity(0.07)
                            .rotationEffect(.degrees(Double((row * 37 + col * 53) % 60) - 30))
                            .position(
                                x: cellW * CGFloat(col) + cellW / 2,
                                y: cellH * CGFloat(row) + cellH / 2
                            )
                    }
                }
            }
        }
        .blur(radius: 1)
    }

    // MARK: - Logo section

    private var logoSection: some View {
        ZStack {
            // Glow ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.orange.opacity(0.35),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)

            // Icon container
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.55, blue: 0.15),
                                Color(red: 0.85, green: 0.28, blue: 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: .orange.opacity(0.6), radius: 20, x: 0, y: 8)

                Image(systemName: "fork.knife")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .scaleEffect(logoScale)
        .opacity(logoOpacity)
    }

    // MARK: - Text section

    private var textSection: some View {
        VStack(spacing: 12) {
            // App name
            Text("ChefNova")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(red: 1.0, green: 0.85, blue: 0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                .offset(y: titleOffset)
                .opacity(titleOpacity)

            // Tagline
            Text("Your AI-powered recipe assistant")
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .opacity(taglineOpacity)

            // Decorative divider
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.orange.opacity(0.5))
                    .frame(width: 40, height: 1)
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.orange.opacity(0.7))
                Rectangle()
                    .fill(Color.orange.opacity(0.5))
                    .frame(width: 40, height: 1)
            }
            .opacity(taglineOpacity)
            .padding(.top, 4)
        }
    }

    // MARK: - Get Started button

    private var getStartedButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.4)) {
                showMain = true
            }
        } label: {
            HStack(spacing: 10) {
                Text("Get Started")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.55, blue: 0.15),
                                    Color(red: 0.85, green: 0.28, blue: 0.05)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                }
            )
            .shadow(color: Color.orange.opacity(0.5), radius: 12, x: 0, y: 6)
        }
        .opacity(buttonOpacity)
        .offset(y: buttonOffset)
    }

    // MARK: - Animations

    private func runEntranceAnimation() {
        // Logo pops in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        // Title slides up
        withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
            titleOffset = 0
            titleOpacity = 1.0
        }
        // Tagline fades in
        withAnimation(.easeOut(duration: 0.5).delay(0.65)) {
            taglineOpacity = 1.0
        }
        // Button slides up
        withAnimation(.easeOut(duration: 0.5).delay(0.85)) {
            buttonOpacity = 1.0
            buttonOffset = 0
        }
        // Gentle floating loop for the logo
        withAnimation(
            .easeInOut(duration: 2.5)
            .repeatForever(autoreverses: true)
            .delay(1.0)
        ) {
            floatingOffset = -8
        }
    }
}

// MARK: - Preview

#Preview {
    // Preview with a stub factory — shows the welcome screen only.
    WelcomeView {
        IngredientInputView(
            viewModel: IngredientInputViewModel(normalizer: IngredientNormalizerService()),
            makePreferenceViewModel: {
                PreferenceViewModel(persistenceService: PreviewPreferencePersistenceService())
            }
        )
    }
}

/// Minimal in-memory persistence service used only in previews.
private struct PreviewPreferencePersistenceService: PreferencePersistenceServiceProtocol {
    func savePreferences(_ profile: PreferenceProfile) throws {}
    func loadLatestPreferences() -> PreferenceProfile? { nil }
}
