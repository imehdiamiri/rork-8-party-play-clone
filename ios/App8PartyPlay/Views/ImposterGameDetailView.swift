import SwiftUI

struct ImposterGameDetailView: View {
    let appModel: AppViewModel
    let game: GameType
    let gameStyle: ImposterGameStyle
    @Binding var path: [HomeRoute]
    let showProfile: () -> Void
    @State private var selectedMode: GameMode?

    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    modeSelectionSection
                    instructionsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedMode) { mode in
            switch mode {
            case .singleDevice:
                ImposterSingleDeviceSetupView(
                    appModel: appModel,
                    game: game,
                    gameStyle: gameStyle,
                    showProfile: showProfile
                )
            case .multiDevice:
                MultiDeviceEntryView(appModel: appModel, game: game) { room in
                    path.append(.lobby(room))
                }
            case .teamMode:
                TeamModeEntryView(appModel: appModel, game: game)
            }
        }
    }

    private var heroImageURL: URL? {
        switch gameStyle {
        case .discussion: return URL(string: "https://r2-pub.rork.com/projects/jsj18lhozb5pa43fqitg6/assets/1c874d14-8383-4522-9dab-a269ea1bef5e.png")
        case .clue: return URL(string: "https://r2-pub.rork.com/projects/jsj18lhozb5pa43fqitg6/assets/2c89f528-4665-4def-81d8-ccf1763765c3.png")
        }
    }

    private var hero: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Color(.secondarySystemBackground)
                    .frame(height: 200)
                    .overlay {
                        LinearGradient(
                            colors: [gameStyle.accentColor.opacity(0.92), .indigo.opacity(0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .overlay {
                            Image(systemName: game.symbolName)
                                .font(.system(size: 72, weight: .semibold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                        }
                        .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 18))
            }
        }
    }

    private var modeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(GameLocalizer.chooseMode(language: appModel.currentLanguage))
                .font(.subheadline.weight(.semibold))
                .padding(.top, 8)

            VStack(spacing: 10) {
                ForEach(game.supportedModes) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        ModeSelectionCard(mode: mode, language: appModel.currentLanguage)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var instructionsSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeaderView(title: GameLocalizer.howItWorks(language: appModel.currentLanguage), subtitle: "")
                ForEach(Array(imposterInstructions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .frame(width: 20, height: 20)
                            .background(.white.opacity(0.1), in: .circle)
                        Text(step)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var imposterInstructions: [String] {
        switch gameStyle {
        case .discussion:
            return [
                "Each player secretly sees their role — one is the Imposter.",
                "A secret word is revealed to everyone except the Imposter.",
                "Discuss freely within the time limit to find the Imposter.",
                "Vote on who you think the Imposter is. Majority wins!"
            ]
        case .clue:
            return [
                "Each player secretly sees their role — one is the Imposter.",
                "A secret word is revealed to everyone except the Imposter.",
                "Take turns giving a one-word clue about the secret word.",
                "After all clues, vote on who you think the Imposter is."
            ]
        }
    }
}
