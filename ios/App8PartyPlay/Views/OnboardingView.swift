import SwiftUI

struct OnboardingView: View {
    let onComplete: (String) -> Void
    @State private var currentPage: Int = 0
    @State private var playerName: String = ""
    @State private var appeared: Bool = false
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        ZStack {
            AppBackgroundView()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    gamesShowcasePage.tag(1)
                    nameEntryPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: currentPage)

                bottomControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
        .dismissKeyboardOnTap()
        .onAppear {
            withAnimation(.spring(response: 0.6).delay(0.15)) {
                appeared = true
            }
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.4), .indigo.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 30)

                VStack(spacing: 0) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 68, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.bounce, value: currentPage == 0)
                        .shadow(color: .blue.opacity(0.5), radius: 20, y: 8)
                }
            }
            .frame(height: 160)

            VStack(spacing: 14) {
                Text("Welcome to")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.secondary)

                Text("8PartyPlay")
                    .viralTitleStyle(size: 38, weight: .black)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text("The ultimate party game collection.\nPlay with friends, compete, and have fun!")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
    }

    // MARK: - Page 2: Games Showcase

    private var gamesShowcasePage: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.green.opacity(0.4), .mint.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 30)

                Image(systemName: "sparkles")
                    .font(.system(size: 68, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.bounce, value: currentPage == 1)
                    .shadow(color: .green.opacity(0.5), radius: 20, y: 8)
            }
            .frame(height: 160)

            VStack(spacing: 14) {
                Text("All the Viral Games")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)

                Text("In One Place")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)

                Text("Every trending party game you've seen\non social media — ready to play instantly\nwith your friends. No setup needed.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 4)

                HStack(spacing: 20) {
                    featurePill(icon: "person.3.fill", text: "Multiplayer")
                    featurePill(icon: "iphone", text: "One Device")
                    featurePill(icon: "bolt.fill", text: "Instant")
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    private func featurePill(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.mint)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func gameChip(game: GameType, index: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: game.symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(
                        colors: chipColors(for: index),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: .rect(cornerRadius: 8)
                )

            Text(game.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.5), in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.08))
        }
    }

    private func chipColors(for index: Int) -> [Color] {
        let palettes: [[Color]] = [
            [.purple, .pink],
            [.blue, .cyan],
            [.red, .orange],
            [.cyan, .teal],
            [.pink, .red],
            [.teal, .green],
            [.yellow, .orange]
        ]
        return palettes[index % palettes.count]
    }

    // MARK: - Page 3: Name Entry

    private var nameEntryPage: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.purple.opacity(0.35), .pink.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 25)

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.bounce, value: currentPage == 2)
            }
            .frame(height: 140)

            VStack(spacing: 14) {
                Text("What's Your Name?")
                    .font(.title.weight(.bold))

                Text("This will be your default player name\nin party games.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 32)

            VStack(spacing: 8) {
                TextField("", text: $playerName, prompt: Text("Enter your name").foregroundStyle(.white.opacity(0.3)))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(.ultraThinMaterial.opacity(0.6), in: .rect(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.purple.opacity(0.5), .pink.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                    .focused($isNameFieldFocused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { isNameFieldFocused = false }

                Text("You can change this anytime")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)

            Spacer()
            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isNameFieldFocused = true
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? .white : .white.opacity(0.25))
                        .frame(width: index == currentPage ? 28 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }

            if currentPage == 2 {
                let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
                let isNameValid = trimmedName.count >= 2
                Button {
                    guard isNameValid else { return }
                    isNameFieldFocused = false
                    SoundManager.shared.playGameStart()
                    onComplete(trimmedName)
                } label: {
                    HStack(spacing: 10) {
                        Text("Let's Play!")
                            .font(.headline.weight(.bold))
                        Image(systemName: "play.fill")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: isNameValid ? [.purple, .pink] : [.gray.opacity(0.6), .gray.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: .rect(cornerRadius: 16)
                    )
                    .shadow(color: .purple.opacity(isNameValid ? 0.4 : 0), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(!isNameValid)
                .transition(.scale.combined(with: .opacity))
                .sensoryFeedback(.impact(flexibility: .rigid), trigger: currentPage)
            } else {
                HStack(spacing: 16) {
                    Spacer()

                    Button {
                        SoundManager.shared.playNavigation()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            currentPage += 1
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Next")
                                .font(.subheadline.weight(.semibold))
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 13)
                        .background(.blue, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .animation(.spring(response: 0.3), value: currentPage)
    }
}
