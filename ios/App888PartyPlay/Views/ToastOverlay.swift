import SwiftUI

struct ToastBanner: View {
    let message: String
    let style: ToastStyle
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: style.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(style.tint)
            Text(message)
                .font(.subheadline.weight(.medium))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style.tint.opacity(0.3), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .padding(.horizontal, 16)
    }
}

nonisolated enum ToastStyle: Sendable {
    case error
    case success
    case warning
    case info

    var icon: String {
        switch self {
        case .error: return "xmark.octagon.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .error: return .red
        case .success: return .green
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

struct ToastOverlayModifier: ViewModifier {
    let errorMessage: String?
    let economyFeedback: EconomyFeedback?
    let lobbyNotice: String?
    let onDismissError: () -> Void
    let onDismissEconomy: () -> Void
    let onDismissNotice: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    if let errorMessage, !errorMessage.isEmpty {
                        ToastBanner(message: errorMessage, style: .error, onDismiss: onDismissError)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if let feedback = economyFeedback {
                        ToastBanner(
                            message: "\(feedback.title): \(feedback.message)",
                            style: toastStyle(from: feedback.style),
                            onDismiss: onDismissEconomy
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if let lobbyNotice, !lobbyNotice.isEmpty {
                        ToastBanner(message: lobbyNotice, style: .info, onDismiss: onDismissNotice)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.top, 8)
                .animation(.spring(duration: 0.35), value: errorMessage)
                .animation(.spring(duration: 0.35), value: economyFeedback)
                .animation(.spring(duration: 0.35), value: lobbyNotice)
            }
    }

    private func toastStyle(from style: EconomyFeedbackStyle) -> ToastStyle {
        switch style {
        case .success: return .success
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        }
    }
}

extension View {
    func toastOverlay(appModel: AppViewModel) -> some View {
        modifier(ToastOverlayModifier(
            errorMessage: appModel.errorMessage,
            economyFeedback: appModel.economyFeedback,
            lobbyNotice: appModel.lobbyNotice,
            onDismissError: { appModel.errorMessage = nil },
            onDismissEconomy: { appModel.clearEconomyFeedback() },
            onDismissNotice: { appModel.lobbyNotice = nil }
        ))
    }
}
