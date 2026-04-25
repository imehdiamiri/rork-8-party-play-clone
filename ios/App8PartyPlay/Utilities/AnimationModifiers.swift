import SwiftUI

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

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    func slideUpOnAppear(delay: Double = 0) -> some View {
        modifier(SlideUpOnAppearModifier(delay: delay))
    }
}
