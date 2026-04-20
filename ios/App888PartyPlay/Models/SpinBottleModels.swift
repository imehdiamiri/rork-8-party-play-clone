import Foundation

nonisolated enum SpinBottleChoice: String, Hashable, Sendable {
    case truth
    case dare

    var title: String {
        switch self {
        case .truth: return "Truth"
        case .dare: return "Dare"
        }
    }

    var icon: String {
        switch self {
        case .truth: return "bubble.left.and.text.bubble.right.fill"
        case .dare: return "flame.fill"
        }
    }
}

nonisolated enum SpinBottleDifficulty: String, CaseIterable, Identifiable, Hashable, Sendable {
    case mild
    case classic
    case bold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mild: return "Mild"
        case .classic: return "Classic"
        case .bold: return "Bold"
        }
    }

    var subtitle: String {
        switch self {
        case .mild: return "Safe & friendly"
        case .classic: return "Balanced fun"
        case .bold: return "Spicy & risky"
        }
    }
}

nonisolated enum SpinBottleContent {
    static func truths(for level: SpinBottleDifficulty) -> [String] {
        switch level {
        case .mild:
            return [
                "What's the silliest thing you believed as a kid?",
                "What's your guilty pleasure song?",
                "What's the weirdest food combination you secretly love?",
                "What's a small habit you can't break?",
                "What's your most-used emoji and why?",
                "What's a movie you can watch over and over?",
                "What's the worst gift you've ever received?",
                "What's the last lie you told today?",
                "Who in this room makes you laugh the most?",
                "What's something you're proud of but never talk about?",
                "What was your most embarrassing school moment?",
                "What's a talent you wish you had?",
                "What's your biggest pet peeve?",
                "What's the longest you've gone without sleep?",
                "What's a fear you had as a child that you still kind of have?",
                "What's the most useless thing you know how to do?",
                "What's your dream vacation spot?",
                "What show do you secretly love but won't admit?",
                "What's the most childish thing you still do?",
                "What was your worst haircut?"
            ]
        case .classic:
            return [
                "Who in this room would you trust with your phone unlocked?",
                "What's the biggest lie you've told your parents?",
                "Who was your first crush?",
                "What's the most embarrassing thing in your search history?",
                "Have you ever pretended to like a gift?",
                "What's a secret you've kept from your best friend?",
                "Who in this room do you find most attractive?",
                "What's the worst date you've ever been on?",
                "What's the meanest thing you've ever done?",
                "Have you ever ghosted someone? Why?",
                "What's a rumor about you that's actually true?",
                "What's the most trouble you've ever been in?",
                "Who's the last person you stalked online?",
                "What's something you've Googled but would be embarrassed to admit?",
                "Have you ever lied to get out of plans? With who?",
                "What's the longest you've held a grudge?",
                "Who's the worst kisser you've ever kissed?",
                "What's the most awkward text you've ever sent?",
                "What's a moment you wish you could redo?",
                "What's the boldest thing you've done for love?"
            ]
        case .bold:
            return [
                "Who in this room would you kiss if you had to?",
                "What's your wildest fantasy you'd actually try?",
                "Who in this room have you thought about more than once?",
                "What's the most scandalous text you've ever sent?",
                "Have you ever been attracted to a friend's partner?",
                "What's something you want in a partner but never asked for?",
                "What's the most risky place you've kissed someone?",
                "Who's the last person you flirted with that wasn't your partner?",
                "What's a deal-breaker that secretly turns you on?",
                "Have you ever lied about how many people you've kissed?",
                "Who in this room would you consider dating?",
                "What's the boldest thing you've done to get someone's attention?",
                "What's a secret about your dating life nobody knows?",
                "Have you ever sent a message you immediately regretted?",
                "What's something you've done that you'd never tell your parents?",
                "Who's the last person you thought about before sleeping?",
                "What's the most jealous you've ever felt?",
                "Have you ever cheated, even just emotionally?",
                "What's a thought you've had about someone here that surprised you?",
                "What's the most you've ever lied about yourself to impress someone?"
            ]
        }
    }

    static func dares(for level: SpinBottleDifficulty) -> [String] {
        switch level {
        case .mild:
            return [
                "Do your best impression of someone in the room.",
                "Sing the chorus of the last song you played.",
                "Speak in an accent until your next turn.",
                "Do 10 jumping jacks right now.",
                "Tell a joke. If no one laughs, tell another.",
                "Do your best runway walk across the room.",
                "Show the last photo in your camera roll.",
                "Let the group pick your next selfie pose. Take it.",
                "Dance for 15 seconds with no music.",
                "Speak only in questions for one minute.",
                "Do your best superhero landing.",
                "Whisper a compliment to everyone in the room.",
                "Eat or drink something in the most dramatic way possible.",
                "Pretend to be a news anchor reporting this party.",
                "Balance something on your head for 30 seconds.",
                "Do your best evil villain laugh.",
                "Talk like a baby until your next turn.",
                "Make up a song about the person on your left.",
                "Do 5 push-ups. Now.",
                "Give a TED talk about a random object in the room."
            ]
        case .classic:
            return [
                "Send a flirty emoji to the last person in your messages.",
                "Let the group post a one-word status on your socials.",
                "Show the last 3 people you texted to the room.",
                "Call someone in your contacts and sing them happy birthday.",
                "Let the group pick a contact — send them 'I was just thinking about you.'",
                "Show your most recent search history.",
                "Read the last DM you sent out loud.",
                "Let the player on your left write your next Instagram caption.",
                "Do a slow-motion hair flip on command.",
                "Try to make someone in the room laugh in 10 seconds.",
                "Whisper a secret to the player on your right.",
                "Hold eye contact with someone for 30 seconds without speaking.",
                "Imitate the voice of the person across from you.",
                "Let the group give you a new ringtone for the next round.",
                "Confess one thing you Googled this week.",
                "Send a heart emoji to your 5th contact.",
                "Take a goofy selfie and set it as your lock screen for the night.",
                "Trade phones with someone for 30 seconds. No peeking allowed.",
                "Let the group pick an emoji to text your last contact.",
                "Tell the group the most awkward DM you've ever sent."
            ]
        case .bold:
            return [
                "Whisper something flirty to the player on your left.",
                "Slow dance with someone in the room for 15 seconds.",
                "Send a risky text to your crush — the group helps write it.",
                "Sit on the lap of the person to your right for one round.",
                "Give the player across from you a 5-second back massage.",
                "Take a sultry selfie. Show it to the group.",
                "Whisper your type out loud to someone here.",
                "Hold hands with the player on your right until your next turn.",
                "Pick someone here and describe what you'd do on a perfect date with them.",
                "Lock eyes with someone for 20 seconds without smiling.",
                "Let someone in the room write a flirty message and send it from your phone.",
                "Compliment someone here in the most seductive voice you can.",
                "Bite your lip and stare at the player of your choice for 5 seconds.",
                "Reveal which player here you'd swipe right on.",
                "Whisper a confession to the group that would surprise them.",
                "Text your ex one word of the group's choosing.",
                "Take off one accessory and give it to the player you find most attractive.",
                "Pick someone and tell them what you noticed first about them.",
                "Give your most dramatic, slow wink to someone of your choice.",
                "Tell the player on your left exactly what you're thinking right now."
            ]
        }
    }
}
