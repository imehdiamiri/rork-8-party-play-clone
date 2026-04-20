import SwiftUI
import RevenueCat
import UserNotifications

@main
struct App888PartyPlayApp: App {
    @State private var appModel = AppViewModel()
    @State private var store = StoreViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .error
        #endif
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(appModel: appModel, store: store)
                .environment(\.locale, Locale(identifier: appModel.currentLanguageCode))
                .appLanguageStyling(language: appModel.currentLanguage)
                .preferredColorScheme(.dark)
                .onAppear { store.start() }
                .onOpenURL { url in
                    if let code = Self.extractInviteCode(from: url) {
                        appModel.setPendingInviteCode(code)
                    } else {
                        appModel.handleOAuthCallback(url)
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            appModel.handleScenePhaseChange(to: newPhase)
        }
    }

    private static func extractInviteCode(from url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""
        let scheme = url.scheme?.lowercased() ?? ""
        let path = url.path.lowercased()
        let isHTTPInvite = (scheme == "https" || scheme == "http")
            && AppConstants.Invite.allowedHosts.contains(host)
            && path.hasPrefix("/invite")
        let isCustomScheme = scheme == AppConstants.Invite.inviteScheme
        guard isHTTPInvite || isCustomScheme else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let code = components?.queryItems?.first(where: { $0.name.lowercased() == "code" })?.value,
           !code.isEmpty {
            return code
        }
        return nil
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationService.shared
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        DeviceTokenStore.shared.latestToken = token
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    }
}
