import SwiftUI

struct AppLanguageFontModifier: ViewModifier {
    let language: AppLanguage

    func body(content: Content) -> some View {
        content
            .environment(\.layoutDirection, layoutDirection)
    }

    private var layoutDirection: LayoutDirection {
        _ = language
        return .leftToRight
    }
}

extension View {
    func appLanguageStyling(language: AppLanguage) -> some View {
        modifier(AppLanguageFontModifier(language: language))
    }
}
