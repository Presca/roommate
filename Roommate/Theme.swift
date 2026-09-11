import SwiftUI
import CoreText

enum Theme {
    static let cream = Color(red: 0.984, green: 0.976, blue: 0.960)
    static let card = Color.white.opacity(0.75)
    static let ink = Color(red: 0.24, green: 0.20, blue: 0.18)
    static let soft = Color(red: 0.50, green: 0.45, blue: 0.43)
    static let line = Color(red: 0.24, green: 0.20, blue: 0.18).opacity(0.18)
    static let blush = Color(red: 0.93, green: 0.55, blue: 0.60)
    static let blushLight = Color(red: 0.98, green: 0.85, blue: 0.87)
    static let sky = Color(red: 0.72, green: 0.82, blue: 0.90)
    static let skyDark = Color(red: 0.45, green: 0.58, blue: 0.72)
    static let mint = Color(red: 0.85, green: 0.93, blue: 0.91)
    static let jeans = Color(red: 0.78, green: 0.86, blue: 0.93)
    static let grumpy = Color(red: 0.55, green: 0.52, blue: 0.60)
}

/// Registers any .ttf/.otf you drop into Roommate/Resources/Fonts at launch.
/// "Cute Planner" is a paid font, so it isn't in the repo – see README.
enum FontLoader {
    private(set) static var customFontName: String?

    static func registerBundledFonts() {
        var found: [String] = []
        for ext in ["ttf", "otf"] {
            var urls: [URL] = []
            for sub in [nil, "Fonts", "Resources/Fonts"] {
                urls += Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: sub) ?? []
            }
            for url in urls {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                if let provider = CGDataProvider(url: url as CFURL),
                   let font = CGFont(provider),
                   let name = font.postScriptName as String? {
                    found.append(name)
                }
            }
        }
        customFontName = found.first(where: { $0.lowercased().contains("cute") || $0.lowercased().contains("planner") })
            ?? found.first
    }
}

extension Font {
    /// Cute Planner if it's bundled, otherwise SF Rounded (closest built-in).
    static func cute(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let name = FontLoader.customFontName {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }
}

extension View {
    func cuteCard() -> some View {
        self
            .padding(18)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.line, lineWidth: 1.5))
    }
}
