import SwiftUI

struct ContentView: View {
    let appModel: AppViewModel
    let store: StoreViewModel

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if appModel.isCheckingSession {
                    SplashView()
                } else if !appModel.hasCompletedOnboarding {
                    OnboardingView { name in
                        appModel.completeOnboarding(playerName: name)
                        Task {
                            await NotificationService.shared.checkCurrentStatus()
                            if !NotificationService.shared.isAuthorized {
                                _ = await NotificationService.shared.requestPermission()
                            }
                        }
                    }
                } else if appModel.isAuthenticated {
                    MainTabView(appModel: appModel, store: store)
                } else {
                    AuthView(appModel: appModel, showCloseButton: false)
                }
            }

            if appModel.connectionState == .reconnecting {
                ConnectionBannerView(state: .reconnecting)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if appModel.connectionState == .disconnected {
                ConnectionBannerView(state: .disconnected)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: appModel.connectionState)
        .tint(.blue)
        .animation(.smooth, value: appModel.isAuthenticated)
        .animation(.smooth, value: appModel.isCheckingSession)
        .animation(.smooth, value: appModel.hasCompletedOnboarding)
        .task {
            await NotificationService.shared.checkCurrentStatus()
        }
        .onAppear {
            store.onStarsGranted = { amount, tier, periodKey, expiresAt in
                let tierEnum = SubscriptionTier(rawValue: tier) ?? .monthly
                appModel.grantSubscriptionStars(amount: amount, tier: tierEnum, periodKey: periodKey, expiresAt: expiresAt)
            }
            store.onStarPackPurchased = { amount, productID in
                appModel.grantPurchasedStars(amount: amount, productID: productID)
            }
            appModel.checkForRejoinableSession()
        }
        .alert("Rejoin Game?", isPresented: Binding(
            get: { appModel.showRejoinPrompt },
            set: { if !$0 { appModel.declineRejoin() } }
        )) {
            Button("Rejoin") { appModel.rejoinSession() }
            Button("Dismiss", role: .cancel) { appModel.declineRejoin() }
        } message: {
            Text("You have an active game session. Would you like to rejoin?")
        }
        .alert("Host Left", isPresented: Binding(
            get: { appModel.showHostLeftAlert },
            set: { if !$0 { appModel.handleHostLeftDismiss() } }
        )) {
            Button("OK") { appModel.handleHostLeftDismiss() }
        } message: {
            Text("The host left the game. The session has ended.")
        }
    }
}

struct ConnectionBannerView: View {
    let state: SessionResilienceService.ConnectionState

    var body: some View {
        HStack(spacing: 8) {
            if state == .reconnecting {
                ProgressView()
                    .tint(.white)
                    .controlSize(.small)
                Text("Reconnecting...")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "wifi.slash")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Text("Connection lost")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(state == .reconnecting ? .orange : .red)
        .padding(.top, 0)
    }
}

struct SplashView: View {
    @State private var appeared: Bool = false

    var body: some View {
        ZStack {
            AppBackgroundView()
            VStack(spacing: 20) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(appeared ? 1 : 0.7)
                    .opacity(appeared ? 1 : 0)

                Text("8PartyPlay")
                    .viralTitleStyle(size: 36, weight: .black)
                    .foregroundStyle(.white)
                    .opacity(appeared ? 1 : 0)

                ProgressView()
                    .tint(.white.opacity(0.6))
                    .padding(.top, 8)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

#Preview {
    ContentView(appModel: AppViewModel(), store: StoreViewModel())
}
