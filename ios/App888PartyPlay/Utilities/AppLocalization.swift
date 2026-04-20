import Foundation

nonisolated enum AppCopyKey: String, Hashable, Sendable {
    case gamesTab
    case lobbyTab
    case friendsTab
    case walletTab
    case profileTitle
    case done
    case settingsTitle
    case accountTitle
    case accountSubtitle
    case languageTitle
    case languageSubtitle
    case soundTitle
    case vibrationTitle
    case logout
    case guestMode
    case providerPrefix
    case publicID
    case username
    case displayName
    case email
    case avatar
    case saveChanges
    case save
    case cancel
    case profileSaved
    case languageEnglish
    case signInTitle
    case signInSubtitle
    case continueAsGuest
    case usernamePlaceholder
    case passwordPlaceholder
    case login
    case createAccount
    case continueWithGoogle
    case loginLater
    case skipLogin
    case accountSection
    case appLanguageSection
    case preferencesSection
    case settingsInsideProfile
    case numericIDHint
    case guestEditHint
    case connectedEditHint
    case selectAvatar
    case usernameOnlyHint
    case publicIDLockedHint
}

nonisolated enum AppLocalizer {
    static func text(_ key: AppCopyKey, language: AppLanguage) -> String {
        let table: [AppCopyKey: String] = [
            .gamesTab: "Games",
            .lobbyTab: "Lobby",
            .friendsTab: "Friends",
            .walletTab: "Wallet",
            .profileTitle: "Profile",
            .done: "Done",
            .settingsTitle: "Settings",
            .accountTitle: "Account",
            .accountSubtitle: "Edit your public profile and app preferences.",
            .languageTitle: "Language",
            .languageSubtitle: "Choose how the app is shown.",
            .soundTitle: "Sound",
            .vibrationTitle: "Vibration",
            .logout: "Log out",
            .guestMode: "Guest mode",
            .providerPrefix: "Logged in with",
            .publicID: "Public ID",
            .username: "Username",
            .displayName: "Name",
            .email: "Email",
            .avatar: "Avatar",
            .saveChanges: "Save Changes",
            .save: "Save",
            .cancel: "Cancel",
            .profileSaved: "Profile updated.",
            .languageEnglish: "App language",
            .signInTitle: "Party Games",
            .signInSubtitle: "Jump in fast and keep testing the app.",
            .continueAsGuest: "Continue as Guest",
            .usernamePlaceholder: "Username",
            .passwordPlaceholder: "Password",
            .login: "Login",
            .createAccount: "Create account",
            .continueWithGoogle: "Continue with Google",
            .loginLater: "Login later",
            .skipLogin: "Skip login",
            .accountSection: "Account",
            .appLanguageSection: "App language",
            .preferencesSection: "Preferences",
            .settingsInsideProfile: "Settings are now inside profile.",
            .numericIDHint: "Numeric ID can be changed if available.",
            .guestEditHint: "Guest mode stays active. Changes are local on this device.",
            .connectedEditHint: "Profile edits sync to your account.",
            .selectAvatar: "Select Avatar",
            .usernameOnlyHint: "Only username can be changed.",
            .publicIDLockedHint: "Public ID is fixed and cannot be changed."
        ]
        _ = language
        return table[key] ?? ""
    }
}
