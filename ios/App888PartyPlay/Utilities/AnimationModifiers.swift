import SwiftUI

struct BounceOnAppearModifier: ViewModifier {
    let delay: Double
    @State private var appeared: Bool = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.65).delay(delay)) {
                    appeared = true
                }
            }
    }
}

struct SlideUpOnAppearModifier: ViewModifier {
    let delay: Double
    @State private var appeared: Bool = false

    func body(content: Content) -> some View {
        content
            .offset(y: appeared ? 0 : 24)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(delay)) {
                    appeared = true
                }
            }
    }
}

struct PulseModifier: ViewModifier {
    let isActive: Bool
    @State private var pulse: Bool = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive && pulse ? 1.08 : 1.0)
            .opacity(isActive && pulse ? 0.85 : 1.0)
            .onAppear {
                guard isActive else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                } else {
                    withAnimation(.spring) {
                        pulse = false
                    }
                }
            }
    }
}

struct ShakeModifier: ViewModifier, Animatable {
    var shakeCount: Double

    var animatableData: Double {
        get { shakeCount }
        set { shakeCount = newValue }
    }

    func body(content: Content) -> some View {
        content.offset(x: sin(shakeCount * .pi * 2) * 8)
    }
}

struct CountdownScaleModifier: ViewModifier {
    let trigger: Int
    @State private var scale: Double = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: trigger) { _, _ in
                withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                    scale = 1.3
                } completion: {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        scale = 1.0
                    }
                }
            }
    }
}

struct ConfettiModifier: ViewModifier {
    let trigger: Bool
    @State private var particles: [ConfettiParticle] = []

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack {
                    ForEach(particles) { particle in
                        Circle()
                            .fill(particle.color)
                            .frame(width: particle.size, height: particle.size)
                            .offset(x: particle.x, y: particle.y)
                            .opacity(particle.opacity)
                    }
                }
                .allowsHitTesting(false)
            }
            .onChange(of: trigger) { _, active in
                guard active else { return }
                spawnConfetti()
            }
    }

    private func spawnConfetti() {
        let colors: [Color] = [.yellow, .orange, .pink, .purple, .cyan, .green, .mint]
        particles = (0..<30).map { i in
            ConfettiParticle(
                id: i,
                color: colors[i % colors.count],
                size: CGFloat.random(in: 4...8),
                x: CGFloat.random(in: -140...140),
                y: -20,
                opacity: 1.0
            )
        }
        withAnimation(.easeOut(duration: 1.2)) {
            particles = particles.map { p in
                ConfettiParticle(
                    id: p.id,
                    color: p.color,
                    size: p.size,
                    x: p.x + CGFloat.random(in: -40...40),
                    y: CGFloat.random(in: 80...300),
                    opacity: 0
                )
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            particles = []
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id: Int
    let color: Color
    let size: CGFloat
    let x: CGFloat
    let y: CGFloat
    let opacity: Double
}

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    func bounceOnAppear(delay: Double = 0) -> some View {
        modifier(BounceOnAppearModifier(delay: delay))
    }

    func slideUpOnAppear(delay: Double = 0) -> some View {
        modifier(SlideUpOnAppearModifier(delay: delay))
    }

    func pulseEffect(isActive: Bool) -> some View {
        modifier(PulseModifier(isActive: isActive))
    }

    func shakeEffect(trigger: Double) -> some View {
        modifier(ShakeModifier(shakeCount: trigger))
    }

    func countdownScale(trigger: Int) -> some View {
        modifier(CountdownScaleModifier(trigger: trigger))
    }

    func confettiEffect(trigger: Bool) -> some View {
        modifier(ConfettiModifier(trigger: trigger))
    }
}
