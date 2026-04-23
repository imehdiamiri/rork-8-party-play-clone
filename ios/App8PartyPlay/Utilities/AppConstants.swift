import Foundation

nonisolated enum AppConstants {
    enum Supabase {
        static let urlString: String = "https://lhbepwdudjhghxgiegnl.supabase.co"
        static let anonKey: String = "sb_publishable_0gBYSRLqEyJrrN6bDp5mag_jOPIzSzR"
        static let callbackScheme: String = "app.rork.cejfnhlng6nv3gg1g94ab"
    }

    enum URLs {
        static let privacyPolicy: URL = URL(string: "https://www.8partyplay.com/privacy.html")!
        static let termsOfService: URL = URL(string: "https://www.8partyplay.com/terms.html")!
        static let marketingSite: URL = URL(string: "https://www.8partyplay.com")!
    }

    enum Invite {
        static let allowedHosts: Set<String> = [
            "8partyplay.com",
            "www.8partyplay.com",
            "app.8partyplay.com"
        ]
        static let inviteScheme: String = "invite"
    }
}
