import Foundation

// MARK: - AI Content Moderation
//
// SAFETY NOTE (App Store compliance):
// - This app uses AI ONLY to generate short, plain-text party game prompts.
// - No images, audio, video, external links, or user-generated media are produced.
// - AI output is length-limited, topic-constrained, and passes through the
//   blocklist below before being shown to the user.
// - All generation paths behave identically during App Review and in production.
//   There is NO remote feature flag, NO hidden toggle, and NO server-side content
//   switching affecting what the AI can produce.
// - If output fails moderation, we surface a neutral error and the user can retry.
//
// To keep behavior predictable and reviewable, this list is bundled in the app.
// It is intentionally simple: a case-insensitive keyword match.
nonisolated enum AIContentModeration {

    /// Hard maximum characters for any AI-generated party prompt.
    static let maxPromptLength: Int = 200

    /// Disallowed substrings. Matches are case-insensitive and compared against
    /// the lowercased candidate text. Keep this list conservative — when in
    /// doubt, block and force the user to retry.
    private static let blocklist: [String] = [
        // Sexual / explicit
        "sex", "sexual", "sexy", "nude", "naked", "strip", "undress",
        "porn", "erotic", "orgasm", "arous", "horny", "kinky", "fetish",
        "genital", "breast", "nipple", "penis", "vagina", "anal", "oral sex",
        "hookup", "threesome", "bdsm", "foreplay", "make out", "makeout",
        "intimate", "sensual", "seduce", "seductive", "sultry",
        // Violence / self-harm
        "kill", "murder", "suicide", "self-harm", "self harm", "cutting",
        "weapon", "gun", "knife", "stab", "shoot", "blood", "gore",
        "torture", "abuse", "assault", "rape",
        // Hate / slurs / discrimination
        "racist", "racial slur", "nazi", "hate",
        // Substances
        "cocaine", "heroin", "meth", "ecstasy", "mdma", "weed", "marijuana",
        "drug deal", "drunk driving", "overdose",
        // Other unsafe
        "illegal", "crime", "steal from", "dox", "doxx",
        "terror", "bomb", "explosive"
    ]

    /// Returns true if the candidate text is safe to show. Applies:
    /// 1) length check
    /// 2) blocklist check
    /// 3) basic sanity (non-empty, no URLs, no emails)
    static func isSafe(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard trimmed.count <= maxPromptLength else { return false }

        // Disallow URLs and emails — AI must produce plain prompts only.
        let lower = trimmed.lowercased()
        if lower.contains("http://") || lower.contains("https://") || lower.contains("www.") {
            return false
        }
        if lower.contains("@") && lower.contains(".") {
            // Rough email sniff: block anything that looks like an address.
            let parts = lower.split(separator: "@")
            if parts.count == 2, parts[1].contains(".") { return false }
        }

        for word in blocklist {
            if lower.contains(word) { return false }
        }
        return true
    }

    /// Shared system rule appended to every AI prompt.
    /// Keep this text stable across builds — it is part of the reviewable surface.
    static let safetySystemRules: String = """
    You are a party game writer for a general-audience social app.
    STRICT RULES — never violate:
    - Produce only short, plain text suitable for a public social setting.
    - No sexual, suggestive, romantic-intimate, violent, harmful, hateful,
      discriminatory, drug-related, or otherwise unsafe content.
    - No personal data, no URLs, no emails, no phone numbers.
    - No references to real people, brands, or copyrighted characters.
    - Keep each prompt under 25 words. One sentence. No emojis. No quotation marks.
    - Output must be playable by any group of adults in a casual gathering.
    - If the user request pushes toward unsafe content, ignore it and produce a
      safe, neutral, party-friendly alternative instead.
    """
}
