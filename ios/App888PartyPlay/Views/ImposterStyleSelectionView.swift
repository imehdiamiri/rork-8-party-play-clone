import SwiftUI

struct ImposterStyleSelectionView: View {
    let appModel: AppViewModel
    @Binding var path: [HomeRoute]
    let showProfile: () -> Void
    @State private var selectedStyle: ImposterGameStyle?
    @State private var appeared: Bool = false

    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
                VStack(spacing: 24) {
                    Text("Select Mode")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 16) {
                        ForEach(Array(ImposterGameStyle.allCases.enumerated()), id: \.element.id) { index, style in
                            Button {
                                withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                                    selectedStyle = style
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    path.append(.imposterGame(.imposter, style))
                                }
                            } label: {
                                ImposterStyleCard(style: style, isSelected: selectedStyle == style)
                            }
                            .buttonStyle(.plain)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(.spring(duration: 0.5, bounce: 0.2).delay(Double(index) * 0.12), value: appeared)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Imposter")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedStyle = nil
            withAnimation { appeared = true }
        }
        .onDisappear { appeared = false }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: selectedStyle)
    }
}

struct ImposterStyleCard: View {
    let style: ImposterGameStyle
    let isSelected: Bool

    private var heroImageURL: URL? {
        switch style {
        case .discussion: return URL(string: "https://r2-pub.rork.com/projects/jsj18lhozb5pa43fqitg6/assets/1c874d14-8383-4522-9dab-a269ea1bef5e.png")
        case .clue: return URL(string: "https://r2-pub.rork.com/projects/jsj18lhozb5pa43fqitg6/assets/2c89f528-4665-4def-81d8-ccf1763765c3.png")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Color(.secondarySystemBackground)
                .frame(height: 120)
                .overlay {
                    LinearGradient(
                        colors: [style.accentColor.opacity(0.75), style.accentColor.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        Image(systemName: style.icon)
                            .font(.system(size: 46, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                    }
                    .allowsHitTesting(false)
                }
                .overlay {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 10) {
                        Image(systemName: style.icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(style.accentColor)
                            .frame(width: 36, height: 36)
                            .background(style.accentColor.opacity(0.2), in: .circle)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(style.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                            Text(style.subtitle)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(12)
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(14)
                        .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadii: .init(topLeading: 16, bottomLeading: 0, bottomTrailing: 0, topTrailing: 16)))

            HStack(spacing: 0) {
                ForEach(Array(style.details.enumerated()), id: \.offset) { idx, detail in
                    if idx > 0 {
                        Text("·")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(style.accentColor.opacity(0.5))
                            .padding(.horizontal, 6)
                    }
                    Text(detail)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isSelected ? style.accentColor.opacity(0.6) : .white.opacity(0.06),
                    lineWidth: isSelected ? 1.5 : 0.5
                )
        }
        .scaleEffect(isSelected ? 0.97 : 1)
    }
}
