import SwiftUI

extension Font {
    static func viralTitle(size: CGFloat, weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension View {
    func viralTitleStyle(size: CGFloat, weight: Font.Weight = .black) -> some View {
        self.font(.viralTitle(size: size, weight: weight))
    }
}

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
