import SwiftUI
import RevenueCat
import UIKit
import UserNotifications

@main
struct App8PartyPlayApp: App {
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

class AppDelegate: NSObject, UIApplicationDelegate, UIGestureRecognizerDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationService.shared
        installGlobalKeyboardDismissGestures()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        installGlobalKeyboardDismissGestures()
    }

    private func installGlobalKeyboardDismissGestures() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
            for window in windows {
                if window.gestureRecognizers?.contains(where: { $0.name == "GlobalKeyboardDismissTap" }) != true {
                    let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleGlobalKeyboardDismissGesture(_:)))
                    tap.name = "GlobalKeyboardDismissTap"
                    tap.cancelsTouchesInView = false
                    tap.delaysTouchesBegan = false
                    tap.delaysTouchesEnded = false
                    tap.delegate = self
                    window.addGestureRecognizer(tap)
                }

                if window.gestureRecognizers?.contains(where: { $0.name == "GlobalKeyboardDismissPan" }) != true {
                    let pan = UIPanGestureRecognizer(target: self, action: #selector(self.handleGlobalKeyboardDismissGesture(_:)))
                    pan.name = "GlobalKeyboardDismissPan"
                    pan.cancelsTouchesInView = false
                    pan.delaysTouchesBegan = false
                    pan.delaysTouchesEnded = false
                    pan.delegate = self
                    window.addGestureRecognizer(pan)
                }
            }
        }
    }

    @objc private func handleGlobalKeyboardDismissGesture(_ gesture: UIGestureRecognizer) {
        if let tap = gesture as? UITapGestureRecognizer, tap.state == .ended {
            gesture.view?.endEditing(true)
        }

        if let pan = gesture as? UIPanGestureRecognizer, pan.state == .began {
            gesture.view?.endEditing(true)
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !isTouchInsideTextInput(touch.view)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    private func isTouchInsideTextInput(_ view: UIView?) -> Bool {
        var currentView = view
        while let view = currentView {
            if view is UITextField || view is UITextView || view is UISearchBar {
                return true
            }
            currentView = view.superview
        }
        return false
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        DeviceTokenStore.shared.latestToken = token
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    }
}
