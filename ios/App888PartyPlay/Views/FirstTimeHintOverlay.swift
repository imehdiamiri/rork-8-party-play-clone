import SwiftUI

struct FirstTimeHintOverlay: View {
    let storageKey: String
    let icon: String
    let title: String
    let tip: String
    let accent: Color

    @AppStorage private var hasSeen: Bool

    init(storageKey: String, icon: String, title: String, tip: String, accent: Color = .blue) {
        self.storageKey = storageKey
        self.icon = icon
        self.title = title
        self.tip = tip
        self.accent = accent
        _hasSeen = AppStorage(wrappedValue: false, storageKey)
    }

    var body: some View {
        if !hasSeen {
            ZStack {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }

                VStack(spacing: 18) {
                    Image(systemName: icon)
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 84, height: 84)
                        .background(accent.opacity(0.15), in: .circle)

                    VStack(spacing: 8) {
                        Text(title)
                            .font(.title3.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 8)

                    Button {
                        dismiss()
                    } label: {
                        Text("Got it")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(accent, in: .rect(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(22)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(.white.opacity(0.08))
                }
                .padding(.horizontal, 32)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
            .animation(.spring(duration: 0.35), value: hasSeen)
            .zIndex(999)
        }
    }

    private func dismiss() {
        FeedbackService.shared.playClick()
        withAnimation(.spring(duration: 0.3)) {
            hasSeen = true
        }
    }
}

extension View {
    func firstTimeHint(key: String, icon: String, title: String, tip: String, accent: Color = .blue) -> some View {
        self
    }
}
