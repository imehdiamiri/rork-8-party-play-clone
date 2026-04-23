import SwiftUI

struct TeamModeEntryView: View {
    let appModel: AppViewModel
    let game: GameType
    @State private var casualVM = CasualRoomViewModel()
    @State private var navigateToTeamSetup: Bool = false

    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
                VStack(spacing: 20) {
                    iconHeader
                    nameInputCard
                    createButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Team Room")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToTeamSetup) {
            TeamSetupView(appModel: appModel, casualVM: casualVM)
        }
        .onAppear {
            casualVM.playMode = .teamMode
        }
        .onChange(of: casualVM.isConnected) { _, connected in
            if connected && casualVM.room != nil {
                navigateToTeamSetup = true
            }
        }
    }

    private var iconHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.badge.gearshape.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.purple)
                .frame(width: 64, height: 64)
                .background(.purple.opacity(0.14), in: .rect(cornerRadius: 20))

            Text("Create a Team Room")
                .font(.title3.weight(.bold))

            Text("No login needed. Share the code, then assign teams.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var nameInputCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Your Name", subtitle: "This is how others will see you.")

                TextField("Display name", text: $casualVM.displayName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(.white.opacity(0.05), in: .rect(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(casualVM.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && casualVM.errorMessage != nil ? .red.opacity(0.5) : .white.opacity(0.05))
                    }

                if casualVM.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label("Display name is required", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var createButton: some View {
        VStack(spacing: 8) {
            Button("Create Team Room") {
                casualVM.createRoom(gameType: game) {}
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(casualVM.isBusy)

            if let error = casualVM.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            if casualVM.isBusy {
                ProgressView()
                    .tint(.white)
            }
        }
    }
}
