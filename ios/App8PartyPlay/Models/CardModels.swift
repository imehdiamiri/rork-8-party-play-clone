import Foundation
import SwiftUI

nonisolated enum CardCategory: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case act
    case talk
    case challenges
    case penalty
    case couple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .act: return "Act"
        case .talk: return "Talk"
        case .challenges: return "Challenges"
        case .penalty: return "Penalty"
        case .couple: return "Couple"
        }
    }

    var subtitle: String {
        switch self {
        case .act: return "Perform it out loud"
        case .talk: return "Speak, answer, discuss"
        case .challenges: return "Short rules with a twist"
        case .penalty: return "A playful consequence"
        case .couple: return "Just for two"
        }
    }

    var icon: String {
        switch self {
        case .act: return "theatermasks.fill"
        case .talk: return "bubble.left.and.bubble.right.fill"
        case .challenges: return "bolt.fill"
        case .penalty: return "exclamationmark.triangle.fill"
        case .couple: return "heart.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .act: return .purple
        case .talk: return .blue
        case .challenges: return .orange
        case .penalty: return .red
        case .couple: return .pink
        }
    }

    var subtypes: [CardSubtype] {
        switch self {
        case .act: return [.pantomime, .dare, .funnyAction]
        case .talk: return [.starters, .personal, .discussion, .truth, .explainGuess, .icebreaker]
        case .challenges: return [.speech, .behavior, .timeLimit]
        case .penalty: return [.penaltyFunny, .embarrassing, .groupChoice]
        case .couple: return [.coupleQuestions, .dynamics, .playful]
        }
    }
}

nonisolated enum CardSubtype: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    // Act
    case pantomime
    case dare
    case funnyAction
    // Talk
    case starters
    case personal
    case discussion
    case truth
    case explainGuess
    case icebreaker
    // Challenges
    case speech
    case behavior
    case timeLimit
    // Penalty
    case penaltyFunny
    case embarrassing
    case groupChoice
    // Couple
    case coupleQuestions
    case dynamics
    case playful

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pantomime: return "Pantomime"
        case .dare: return "Dare"
        case .funnyAction: return "Funny Action"
        case .starters: return "Starters"
        case .personal: return "Personal"
        case .discussion: return "Discussion"
        case .truth: return "Truth"
        case .explainGuess: return "Explain / Guess"
        case .icebreaker: return "Icebreaker"
        case .speech: return "Speech"
        case .behavior: return "Behavior"
        case .timeLimit: return "Time Limit"
        case .penaltyFunny: return "Funny"
        case .embarrassing: return "Embarrassing"
        case .groupChoice: return "Group Choice"
        case .coupleQuestions: return "Questions"
        case .dynamics: return "Dynamics"
        case .playful: return "Playful"
        }
    }

    var isFeatured: Bool {
        self == .starters
    }
}


// SAFETY NOTE: This app does NOT expose any 18+ or adult-only content.
// All card content is bundled locally and reviewable in `CardDeckSeed`.
// Content is limited to two tiers: normal and spicy (playful/flirty, party-appropriate).
nonisolated struct PartyCard: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let category: CardCategory
    let subtype: CardSubtype
    let text: String
    let isSpicy: Bool
    let isPremium: Bool

    init(
        id: UUID = UUID(),
        category: CardCategory,
        subtype: CardSubtype,
        text: String,
        isSpicy: Bool = false,
        isPremium: Bool = false
    ) {
        self.id = id
        self.category = category
        self.subtype = subtype
        self.text = text
        self.isSpicy = isSpicy
        self.isPremium = isSpicy || isPremium
    }
}

nonisolated enum CardDeckSeed {
    static let all: [PartyCard] = act + talk + talkIcebreaker + challenges + penalty + couple

    static func cards(for category: CardCategory) -> [PartyCard] {
        switch category {
        case .act: return act
        case .talk: return talk + talkIcebreaker
        case .challenges: return challenges
        case .penalty: return penalty
        case .couple: return couple
        }
    }

    /// SAFETY NOTE: Only two content tiers exist: `.normal` and `.spicy`.
    /// No 18+ or adult-only classification is present anywhere in the app.
    /// All content is bundled locally and fully reviewable.
    private static func make(_ category: CardCategory, _ entries: [(String, CardSubtype, Flag)]) -> [PartyCard] {
        entries.map { text, subtype, flag in
            PartyCard(
                category: category,
                subtype: subtype,
                text: text,
                isSpicy: flag == .spicy
            )
        }
    }

    private enum Flag { case normal, spicy }

    // MARK: ACT (160)
    private static let act: [PartyCard] = make(.act, [
        // Pantomime (50) — normal + spicy
        ("Angry boss", .pantomime, .normal),
        ("Elephant", .pantomime, .normal),
        ("Driving a car in rush hour", .pantomime, .normal),
        ("Nervous bride", .pantomime, .normal),
        ("Tired waiter at closing time", .pantomime, .normal),
        ("Chef tasting his own soup", .pantomime, .normal),
        ("Cat chasing a laser", .pantomime, .normal),
        ("Runway model", .pantomime, .normal),
        ("Zombie in a shopping mall", .pantomime, .normal),
        ("Magician losing his rabbit", .pantomime, .normal),
        ("Bad singer at karaoke", .pantomime, .normal),
        ("Baby tasting lemon", .pantomime, .normal),
        ("Grandpa at the gym", .pantomime, .normal),
        ("Ninja in a library", .pantomime, .normal),
        ("Surgeon who forgot something", .pantomime, .normal),
        ("Person stuck in a tiny elevator", .pantomime, .normal),
        ("Bodybuilder posing", .pantomime, .normal),
        ("Drunk giraffe", .pantomime, .normal),
        ("Ballerina with hiccups", .pantomime, .normal),
        ("Scared pilot", .pantomime, .normal),
        ("Tourist taking selfies", .pantomime, .normal),
        ("Yoga teacher who just woke up", .pantomime, .normal),
        ("Weightlifter lifting a feather", .pantomime, .normal),
        ("Firefighter who forgot the water", .pantomime, .normal),
        ("Detective in a bad mood", .pantomime, .normal),
        ("Octopus at a piano", .pantomime, .normal),
        ("Librarian finding a loud book", .pantomime, .normal),
        ("Astronaut walking on the moon", .pantomime, .normal),
        ("Teacher catching a cheater", .pantomime, .normal),
        ("Clown who forgot the joke", .pantomime, .normal),
        ("Flirting across the room at a bar", .pantomime, .spicy),
        ("Bad first date", .pantomime, .spicy),
        ("Slow dance with a stranger", .pantomime, .spicy),
        ("Catching your crush staring at you", .pantomime, .spicy),
        ("Showing off for a cute stranger", .pantomime, .spicy),
        ("Walking past someone you like", .pantomime, .spicy),
        ("Awkward hug that lasts too long", .pantomime, .spicy),
        ("Sneaking out the morning after", .pantomime, .spicy),
        ("Jealous partner at a party", .pantomime, .spicy),
        ("Trying on something too tight", .pantomime, .spicy),
        ("Slow wink from across the room", .pantomime, .spicy),
        ("Texting someone you shouldn't", .pantomime, .spicy),
        ("Caught in a lie by your date", .pantomime, .spicy),
        ("Undressing after a long day", .pantomime, .spicy),
        ("Couple on their wedding night", .pantomime, .spicy),
        ("Someone sneaking in very late", .pantomime, .spicy),
        ("A wild night at a club", .pantomime, .spicy),
        ("Private dance for one", .pantomime, .spicy),
        ("Morning after a party", .pantomime, .spicy),
        ("Intense makeout interrupted", .pantomime, .spicy),

        // Dare (60) — normal + spicy
        ("Dance without music for 20 seconds", .dare, .normal),
        ("Do your best runway walk across the room", .dare, .normal),
        ("Talk in a dramatic voice until your next turn", .dare, .normal),
        ("Call the last person you texted and say hi", .dare, .normal),
        ("Speak with an accent for the next 30 seconds", .dare, .normal),
        ("Record a 5 second hype video for the person on your right", .dare, .normal),
        ("Let the group pick your next emoji reply", .dare, .normal),
        ("Do an impression of the player across from you", .dare, .normal),
        ("Whisper a genuine compliment to everyone in the room", .dare, .normal),
        ("Do 10 jumping jacks right now", .dare, .normal),
        ("Show the last photo you took without explanation", .dare, .normal),
        ("Post a one word story on your socials immediately", .dare, .normal),
        ("Sing the chorus of the last song you listened to", .dare, .normal),
        ("Do your best superhero landing", .dare, .normal),
        ("Shake everyone's hand like a politician", .dare, .normal),
        ("Tell a 15 second ghost story", .dare, .normal),
        ("Write your name in the air with your hip", .dare, .normal),
        ("Do your best evil scientist laugh", .dare, .normal),
        ("Speak only in questions for 1 minute", .dare, .normal),
        ("Give the person next to you a handshake you invent", .dare, .normal),
        ("Act out your last embarrassing moment", .dare, .normal),
        ("Do 5 pushups on the floor right now", .dare, .normal),
        ("Pretend you won an Oscar and give a speech", .dare, .normal),
        ("Give a motivational speech to a pillow", .dare, .normal),
        ("Impersonate the host of the party", .dare, .normal),
        ("Do a commercial for the drink nearest to you", .dare, .normal),
        ("Say a tongue twister three times fast", .dare, .normal),
        ("Do your best baby voice for 15 seconds", .dare, .normal),
        ("Pretend to interview the player on your right", .dare, .normal),
        ("Do your best angry chef yell", .dare, .normal),
        ("Balance something on your head for 20 seconds", .dare, .normal),
        ("Pretend to be a GPS for 30 seconds", .dare, .normal),
        ("Imitate the laugh of someone in the room", .dare, .normal),
        ("Do your best fashion pose", .dare, .normal),
        ("Tell a joke without laughing yourself", .dare, .normal),
        ("Draw a portrait of someone in 20 seconds", .dare, .normal),
        ("Send a flirty emoji to the last person in your messages", .dare, .spicy),
        ("Let another player write one sentence in your story", .dare, .spicy),
        ("Do a slow motion hair flip", .dare, .spicy),
        ("Whisper a flirty compliment to someone in the room", .dare, .spicy),
        ("Send a heart emoji to the third person in your contacts", .dare, .spicy),
        ("Give your most seductive look for 5 seconds", .dare, .spicy),
        ("Pretend to ask someone here on a first date", .dare, .spicy),
        ("Bite your lip and hold eye contact for 10 seconds", .dare, .spicy),
        ("Do your best slow wink at the group", .dare, .spicy),
        ("Text your ex a single word of your choice", .dare, .spicy),
        ("Describe your crush type without saying names", .dare, .spicy),
        ("Dance for 10 seconds like no one is watching", .dare, .spicy),
        ("Strike a glamour pose and hold it for 10 seconds", .dare, .spicy),
        ("Give someone here a compliment about their looks", .dare, .spicy),
        ("Do a sultry runway walk to the kitchen", .dare, .spicy),
        ("Slow dance with the player on your left for 10 seconds", .dare, .spicy),
        ("Whisper the last dirty thought you had to the group", .dare, .spicy),
        ("Say the name of someone you had a crush on secretly", .dare, .spicy),
        ("Let the group pick a name to text back right now", .dare, .spicy),
        ("Describe your ideal first kiss in one sentence", .dare, .spicy),
        ("Confess the last text you regret sending", .dare, .spicy),
        ("Give someone here a 3 second neck kiss on the cheek", .dare, .spicy),
        ("Reveal the wildest place you've ever kissed someone", .dare, .spicy),
        ("Tell the group your favorite type of kiss", .dare, .spicy),

        // Funny Action (50) — normal + spicy
        ("Act like a jealous taxi driver", .funnyAction, .normal),
        ("Walk like a penguin to the kitchen and back", .funnyAction, .normal),
        ("Pretend you are invisible for 30 seconds", .funnyAction, .normal),
        ("Act like a robot just learning emotions", .funnyAction, .normal),
        ("Pretend to argue with a vending machine", .funnyAction, .normal),
        ("Be a dramatic weather reporter for 20 seconds", .funnyAction, .normal),
        ("Act like a cat who just discovered gravity", .funnyAction, .normal),
        ("Do your worst villain laugh for 10 seconds", .funnyAction, .normal),
        ("Pretend to be a very tired king on his throne", .funnyAction, .normal),
        ("Act like you are selling the chair behind you", .funnyAction, .normal),
        ("Pretend to swim across the living room floor", .funnyAction, .normal),
        ("Act like a fashion model who tripped on the runway", .funnyAction, .normal),
        ("Pretend you are stuck in invisible glue", .funnyAction, .normal),
        ("Be a news anchor reporting about snacks", .funnyAction, .normal),
        ("Pretend to run in slow motion for 15 seconds", .funnyAction, .normal),
        ("Act like a dog seeing snow for the first time", .funnyAction, .normal),
        ("Pretend you are lifting an impossibly heavy bag", .funnyAction, .normal),
        ("Be a pirate explaining WiFi to his crew", .funnyAction, .normal),
        ("Act like a bee that forgot how to fly", .funnyAction, .normal),
        ("Pretend you just saw a ghost in slow motion", .funnyAction, .normal),
        ("Act like a salesperson selling air", .funnyAction, .normal),
        ("Be an over the top theater kid saying hello", .funnyAction, .normal),
        ("Pretend the floor is lava for 20 seconds", .funnyAction, .normal),
        ("Act like a diva who lost their phone", .funnyAction, .normal),
        ("Be a conductor leading an invisible orchestra", .funnyAction, .normal),
        ("Pretend to give a TED talk about socks", .funnyAction, .normal),
        ("Act like a baby taking his first steps", .funnyAction, .normal),
        ("Be a referee in a very intense match of silence", .funnyAction, .normal),
        ("Pretend to accept an award in tears", .funnyAction, .normal),
        ("Act like a confused tourist asking for directions", .funnyAction, .normal),
        ("Be a model posing on a very windy runway", .funnyAction, .spicy),
        ("Act out trying to impress your crush across the room", .funnyAction, .spicy),
        ("Pretend to flirt badly with a houseplant", .funnyAction, .spicy),
        ("Do a slow motion heartbreak scene", .funnyAction, .spicy),
        ("Act like a soap opera character seeing their ex", .funnyAction, .spicy),
        ("Pretend to be jealous of a stranger's drink", .funnyAction, .spicy),
        ("Do a dramatic reading of a breakup text", .funnyAction, .spicy),
        ("Act like you're on a reality dating show", .funnyAction, .spicy),
        ("Pretend to be caught flirting by your partner", .funnyAction, .spicy),
        ("Do a dramatic slow motion hair flip", .funnyAction, .spicy),
        ("Act like a bachelor giving out his rose", .funnyAction, .spicy),
        ("Pretend your phone buzzed from a secret crush", .funnyAction, .spicy),
        ("Do your best impression of a smooth romantic", .funnyAction, .spicy),
        ("Act out a dramatic couple's fight over pasta", .funnyAction, .spicy),
        ("Pretend to be caught at 3am coming home", .funnyAction, .spicy),
        ("Do a dramatic sultry pose for 10 seconds", .funnyAction, .spicy),
        ("Act out an awkward morning after breakfast", .funnyAction, .spicy),
        ("Pretend to sneak around avoiding a roommate", .funnyAction, .spicy),
        ("Do a dramatic scene of ordering something risky online", .funnyAction, .spicy),
        ("Act out forgetting their name mid hookup", .funnyAction, .spicy)
    ])

    // MARK: TALK (200)
    private static let talk: [PartyCard] = make(.talk, [
        // Starters (40) — normal + spicy
        ("Where are you from?", .starters, .normal),
        ("What do you like doing on weekends?", .starters, .normal),
        ("What kind of music do you enjoy most?", .starters, .normal),
        ("What was the last thing you watched?", .starters, .normal),
        ("How did you end up here today?", .starters, .normal),
        ("What is your go to comfort food?", .starters, .normal),
        ("Are you more of a morning person or a night person?", .starters, .normal),
        ("What is one app you use every day?", .starters, .normal),
        ("What kind of trips do you enjoy most?", .starters, .normal),
        ("What is your favorite way to spend a free evening?", .starters, .normal),
        ("What drink do you order most often?", .starters, .normal),
        ("What is something simple that always improves your day?", .starters, .normal),
        ("What is your favorite season and why?", .starters, .normal),
        ("What is one thing you never get bored of talking about?", .starters, .normal),
        ("What kind of places do you like hanging out in?", .starters, .normal),
        ("What is the last song you played on purpose?", .starters, .normal),
        ("Do you usually plan everything or go with the flow?", .starters, .normal),
        ("What snack disappears fastest around you?", .starters, .normal),
        ("What is a show you would easily watch again?", .starters, .normal),
        ("What hobby always sounds fun to you?", .starters, .normal),
        ("What kind of weather matches your ideal day?", .starters, .normal),
        ("What is one city you would happily revisit?", .starters, .normal),
        ("What do friends usually ask you for help with?", .starters, .normal),
        ("What is your usual vibe in a group?", .starters, .normal),
        ("What type of person do you instantly click with?", .starters, .spicy),
        ("What is a small thing that makes someone more attractive to you?", .starters, .spicy),
        ("What kind of first impression works best on you?", .starters, .spicy),
        ("What is a green flag you notice quickly?", .starters, .spicy),
        ("What kind of humor wins you over fast?", .starters, .spicy),
        ("What is your favorite kind of date plan?", .starters, .spicy),
        ("What vibe makes someone instantly interesting to you?", .starters, .spicy),
        ("Do you like bold people or calm people more?", .starters, .spicy),
        ("What compliment style works on you best?", .starters, .spicy),
        ("What makes a conversation feel flirty in a good way?", .starters, .spicy),
        ("What is something charming that people rarely do anymore?", .starters, .spicy),
        ("What makes late night conversations more memorable for you?", .starters, .spicy),
        ("What kind of chemistry do you notice first?", .starters, .spicy),
        ("What is one dating rule you actually believe in?", .starters, .spicy),
        ("What turns a good conversation into real tension for you?", .starters, .spicy),
        ("What kind of confidence do you find hardest to ignore?", .starters, .spicy),

        // Personal (50) — normal + spicy
        ("What is one thing people always misunderstand about you?", .personal, .normal),
        ("What is your favorite childhood memory?", .personal, .normal),
        ("What small thing annoys you way more than it should?", .personal, .normal),
        ("What is one habit you actually like about yourself?", .personal, .normal),
        ("When was the last time you felt truly proud?", .personal, .normal),
        ("What compliment do you remember the most?", .personal, .normal),
        ("What is a song that always lifts your mood?", .personal, .normal),
        ("What is something you would love to be better at?", .personal, .normal),
        ("What is the best advice you have ever been given?", .personal, .normal),
        ("What is one thing that instantly calms you down?", .personal, .normal),
        ("What is a small thing that always makes you smile?", .personal, .normal),
        ("What place feels most like home to you?", .personal, .normal),
        ("What is something you are afraid to admit you enjoy?", .personal, .normal),
        ("What is the last thing that made you laugh hard?", .personal, .normal),
        ("What is a silly thing you still believe in?", .personal, .normal),
        ("What is the worst gift you've ever received?", .personal, .normal),
        ("What is the best gift you've ever given?", .personal, .normal),
        ("What is a food you could never live without?", .personal, .normal),
        ("Who was your childhood hero and why?", .personal, .normal),
        ("What is a show you watched too many times?", .personal, .normal),
        ("What is one thing from your past you miss?", .personal, .normal),
        ("What is a smell that takes you somewhere?", .personal, .normal),
        ("What is something you are weirdly passionate about?", .personal, .normal),
        ("What is your comfort movie?", .personal, .normal),
        ("What is one thing you do to feel better on a bad day?", .personal, .normal),
        ("What is the first thing you notice about a person?", .personal, .normal),
        ("What is something you judge people for silently?", .personal, .normal),
        ("What is a subject you could talk about for hours?", .personal, .normal),
        ("What is one thing you are still learning about yourself?", .personal, .normal),
        ("What is your biggest pet peeve?", .personal, .normal),
        ("What topic makes you instantly shy?", .personal, .spicy),
        ("What is your biggest red flag on paper?", .personal, .spicy),
        ("What is a weird thing that makes you instantly attracted to someone?", .personal, .spicy),
        ("What is the cheesiest thing you secretly love?", .personal, .spicy),
        ("What is the most jealous you've ever been?", .personal, .spicy),
        ("What is something you do when you're crushing on someone?", .personal, .spicy),
        ("What is a compliment that would instantly get you?", .personal, .spicy),
        ("What is a dating habit you can't break?", .personal, .spicy),
        ("What is the softest thing about you that nobody sees?", .personal, .spicy),
        ("What is something that always makes you blush?", .personal, .spicy),
        ("What do you find irresistible in a person?", .personal, .spicy),
        ("What is the bravest thing you've done for love?", .personal, .spicy),
        ("What makes you feel most confident?", .personal, .spicy),
        ("What is a secret crush you had and never told anyone?", .personal, .spicy),
        ("What is the longest you've ever waited for someone?", .personal, .spicy),
        ("What is your worst dating story?", .personal, .spicy),
        ("What is a private rule you set for yourself in relationships?", .personal, .spicy),
        ("What is something you regret doing to impress someone?", .personal, .spicy),
        ("When was the last time you felt truly desired?", .personal, .spicy),
        ("What is a secret fear in your current or past relationships?", .personal, .spicy),

        // Discussion (40) — normal + spicy
        ("Is money more important than happiness?", .discussion, .normal),
        ("Can people really change?", .discussion, .normal),
        ("Is social media doing more harm than good?", .discussion, .normal),
        ("What makes someone successful?", .discussion, .normal),
        ("Should friends always be completely honest with each other?", .discussion, .normal),
        ("Is it better to follow your heart or your plan?", .discussion, .normal),
        ("Are long distance relationships really possible today?", .discussion, .normal),
        ("Is ambition a blessing or a trap?", .discussion, .normal),
        ("Does age really matter in friendships?", .discussion, .normal),
        ("Is kindness a weakness in today's world?", .discussion, .normal),
        ("Is it better to be liked or respected?", .discussion, .normal),
        ("Can you be truly happy without goals?", .discussion, .normal),
        ("Is working hard overrated?", .discussion, .normal),
        ("Should you always tell your friend the truth about their partner?", .discussion, .normal),
        ("Is nostalgia a healthy feeling?", .discussion, .normal),
        ("Are humans getting lonelier as tech improves?", .discussion, .normal),
        ("Is it okay to unfollow friends on social media?", .discussion, .normal),
        ("Does fame ruin good people?", .discussion, .normal),
        ("Is being alone the same as being lonely?", .discussion, .normal),
        ("Can you forgive without forgetting?", .discussion, .normal),
        ("Is saying sorry overused these days?", .discussion, .normal),
        ("Should friendships be as deep as family?", .discussion, .normal),
        ("Is overthinking a sign of caring too much?", .discussion, .normal),
        ("Should kindness be conditional?", .discussion, .normal),
        ("Is jealousy ever a sign of love?", .discussion, .spicy),
        ("Can two exes really stay friends?", .discussion, .spicy),
        ("Is flirting innocent or always a red flag?", .discussion, .spicy),
        ("Does love at first sight really exist?", .discussion, .spicy),
        ("Is chasing someone romantic or just annoying?", .discussion, .spicy),
        ("Should you share all your past relationships with a new partner?", .discussion, .spicy),
        ("Is attraction more about looks or energy?", .discussion, .spicy),
        ("Is it okay to keep a crush a secret forever?", .discussion, .spicy),
        ("Should you follow your crush on social media?", .discussion, .spicy),
        ("Is dating apps killing real romance?", .discussion, .spicy),
        ("Is monogamy realistic for everyone?", .discussion, .spicy),
        ("Should exes stay completely out of your life?", .discussion, .spicy),
        ("Is emotional cheating worse than physical?", .discussion, .spicy),
        ("Is it okay to keep a sexy secret from your partner?", .discussion, .spicy),
        ("Do open relationships work long term?", .discussion, .spicy),
        ("Is desire something you can really control?", .discussion, .spicy),

        // Truth (40) — normal + spicy
        ("What is your biggest regret?", .truth, .normal),
        ("What is something you never admitted openly?", .truth, .normal),
        ("Who in this room do you trust the most and why?", .truth, .normal),
        ("What is the last lie you told today?", .truth, .normal),
        ("What is a rumor about you that is actually true?", .truth, .normal),
        ("What is your most irrational fear?", .truth, .normal),
        ("What is the biggest lie you've ever told your parents?", .truth, .normal),
        ("What is something you've pretended to understand but didn't?", .truth, .normal),
        ("What is the last thing you cried about?", .truth, .normal),
        ("What is a fear you haven't told anyone in this room?", .truth, .normal),
        ("What is something you did as a kid that you got away with?", .truth, .normal),
        ("What is a grudge you are still holding?", .truth, .normal),
        ("What is a time you let a friend down?", .truth, .normal),
        ("What is something you lied about on a resume?", .truth, .normal),
        ("What is something you said you liked just to fit in?", .truth, .normal),
        ("What is a compliment you gave but didn't mean?", .truth, .normal),
        ("What is the pettiest thing that has ever upset you?", .truth, .normal),
        ("What is something you have stolen, even small?", .truth, .normal),
        ("What is a promise you didn't keep?", .truth, .normal),
        ("What is something embarrassing you still do?", .truth, .normal),
        ("What is the worst thing a friend has done to you?", .truth, .normal),
        ("What is a moment you behaved badly and regret it?", .truth, .normal),
        ("What is something you have judged people for, unfairly?", .truth, .normal),
        ("What is the last secret you kept?", .truth, .normal),
        ("What is the meanest thing you have ever thought about a friend?", .truth, .spicy),
        ("Who in this room would you date if you were single?", .truth, .spicy),
        ("What is something flirty you did and got caught?", .truth, .spicy),
        ("Who was your last crush that nobody knew about?", .truth, .spicy),
        ("What is the boldest thing you've ever said to a crush?", .truth, .spicy),
        ("Have you ever lied to get out of a date?", .truth, .spicy),
        ("What is the worst way you've been rejected?", .truth, .spicy),
        ("Have you ever stalked an ex online recently?", .truth, .spicy),
        ("What is the most you've ever fought for a crush?", .truth, .spicy),
        ("Have you ever kissed someone just to prove a point?", .truth, .spicy),
        ("Who in this room would you flirt with if you were single?", .truth, .spicy),
        ("What is the riskiest text you ever sent?", .truth, .spicy),
        ("Have you ever crushed on a friend's partner?", .truth, .spicy),
        ("Have you ever lied about being single?", .truth, .spicy),
        ("What is the wildest thing you've done for attention?", .truth, .spicy),
        ("What is a secret from your last relationship you never told?", .truth, .spicy),

        // Explain / Guess (30) — normal + spicy
        ("Time travel", .explainGuess, .normal),
        ("Broken phone", .explainGuess, .normal),
        ("Cold pizza", .explainGuess, .normal),
        ("A bad haircut", .explainGuess, .normal),
        ("Monday morning", .explainGuess, .normal),
        ("Lost keys", .explainGuess, .normal),
        ("First day at a new school", .explainGuess, .normal),
        ("A traffic jam", .explainGuess, .normal),
        ("Late night snack", .explainGuess, .normal),
        ("A rainy wedding", .explainGuess, .normal),
        ("Overpacked suitcase", .explainGuess, .normal),
        ("Burnt toast", .explainGuess, .normal),
        ("Loud neighbors", .explainGuess, .normal),
        ("Long airport line", .explainGuess, .normal),
        ("Hidden talent", .explainGuess, .normal),
        ("A cheap vacation", .explainGuess, .normal),
        ("Slow internet", .explainGuess, .normal),
        ("Dead battery", .explainGuess, .normal),
        ("Secret crush", .explainGuess, .spicy),
        ("First kiss nerves", .explainGuess, .spicy),
        ("Bad first date", .explainGuess, .spicy),
        ("Flirty text", .explainGuess, .spicy),
        ("Third wheel dinner", .explainGuess, .spicy),
        ("Blind date disaster", .explainGuess, .spicy),
        ("Drunken confession", .explainGuess, .spicy),
        ("One night in Vegas", .explainGuess, .spicy),
        ("Love bite", .explainGuess, .spicy),
        ("Forbidden romance", .explainGuess, .spicy),
        ("Wedding night nerves", .explainGuess, .spicy),
        ("Secret lover", .explainGuess, .spicy)
    ])

    // MARK: CHALLENGES (140)
    private static let challenges: [PartyCard] = make(.challenges, [
        // Speech (50) — normal + spicy
        ("Do not say yes for 1 minute", .speech, .normal),
        ("Talk like a robot for 30 seconds", .speech, .normal),
        ("Only ask questions until your next turn", .speech, .normal),
        ("End every sentence with the word banana for 1 minute", .speech, .normal),
        ("Speak only in whispers until your next turn", .speech, .normal),
        ("Speak only in rhymes for the next 30 seconds", .speech, .normal),
        ("Speak only in compliments for 1 minute", .speech, .normal),
        ("Say every sentence twice until your next turn", .speech, .normal),
        ("Do not use the word I for the next 2 minutes", .speech, .normal),
        ("Speak only in a pirate voice until your next turn", .speech, .normal),
        ("Start every sentence with so anyway for 1 minute", .speech, .normal),
        ("Speak only in movie quotes for 30 seconds", .speech, .normal),
        ("Replace every verb with dance for 1 minute", .speech, .normal),
        ("Talk like a news anchor for 30 seconds", .speech, .normal),
        ("Speak only in third person until your next turn", .speech, .normal),
        ("Talk like a dramatic villain for 30 seconds", .speech, .normal),
        ("Use only five word sentences for 2 minutes", .speech, .normal),
        ("Whisper every other word for 1 minute", .speech, .normal),
        ("Speak only in food words for 30 seconds", .speech, .normal),
        ("Speak in an opera voice for 20 seconds", .speech, .normal),
        ("Never say the word no until your next turn", .speech, .normal),
        ("Answer only in song lyrics until your next turn", .speech, .normal),
        ("Speak like a very bored teacher for 1 minute", .speech, .normal),
        ("Speak only in weather forecasts for 30 seconds", .speech, .normal),
        ("End every sentence with good times until your next turn", .speech, .normal),
        ("Never say the word but for 2 minutes", .speech, .normal),
        ("Reply to every question with exactly three words", .speech, .normal),
        ("Speak only in very long and slow sentences for 1 minute", .speech, .normal),
        ("Speak only in hashtags for 30 seconds", .speech, .normal),
        ("Use a British accent for the next 2 minutes", .speech, .normal),
        ("Speak in a flirty tone for the next 30 seconds", .speech, .spicy),
        ("End every sentence with my love for 1 minute", .speech, .spicy),
        ("Only give compliments about looks for 30 seconds", .speech, .spicy),
        ("Speak only in pickup lines for 1 minute", .speech, .spicy),
        ("Sigh dreamily after every sentence for 1 minute", .speech, .spicy),
        ("Call everyone sweetheart until your next turn", .speech, .spicy),
        ("Narrate your life as a romance novel for 30 seconds", .speech, .spicy),
        ("Speak only in flirty whispers for 30 seconds", .speech, .spicy),
        ("Finish every sentence with you know you like it", .speech, .spicy),
        ("Answer everything with a wink and a line", .speech, .spicy),
        ("Use the word darling in every sentence for 2 minutes", .speech, .spicy),
        ("Pretend every sentence is a love confession for 1 minute", .speech, .spicy),
        ("Flirt with every object you name for 30 seconds", .speech, .spicy),
        ("Speak only in sultry whispers until your next turn", .speech, .spicy),
        ("Say a risky compliment to each player, one at a time", .speech, .spicy),
        ("Only speak in rated R dialogue for 30 seconds", .speech, .spicy),
        ("Whisper one bold secret into the group's silence", .speech, .spicy),
        ("Narrate your last date as a steamy book", .speech, .spicy),
        ("Turn every sentence into a pickup line for 1 minute", .speech, .spicy),
        ("Pretend to confess a crush every 15 seconds for 1 minute", .speech, .spicy),

        // Behavior (50) — normal + spicy
        ("Do not laugh for 1 minute", .behavior, .normal),
        ("Use only one hand until your next turn", .behavior, .normal),
        ("Keep a serious face for 30 seconds while we try to break you", .behavior, .normal),
        ("Do not break eye contact with the player on your left for 30 seconds", .behavior, .normal),
        ("Stand up every time someone says the word yes for 2 minutes", .behavior, .normal),
        ("Keep your arms crossed until your next turn", .behavior, .normal),
        ("Mirror the movements of the player across from you for 30 seconds", .behavior, .normal),
        ("Do not sit down for the next 2 minutes", .behavior, .normal),
        ("Keep one hand on your head until your next turn", .behavior, .normal),
        ("Blink every three seconds for 1 minute", .behavior, .normal),
        ("Never look at your phone for the next 5 minutes", .behavior, .normal),
        ("Clap once after every sentence anyone says for 2 minutes", .behavior, .normal),
        ("Raise your hand before speaking until your next turn", .behavior, .normal),
        ("Copy the next three gestures of someone else", .behavior, .normal),
        ("Move only in slow motion for 1 minute", .behavior, .normal),
        ("Close your eyes for 30 seconds while others talk", .behavior, .normal),
        ("Do not smile for 1 minute while someone tries to make you", .behavior, .normal),
        ("Keep your feet flat on the floor no matter what for 2 minutes", .behavior, .normal),
        ("Sit on your hands until your next turn", .behavior, .normal),
        ("Pretend to be a statue for 30 seconds", .behavior, .normal),
        ("Stand on one leg until your next turn", .behavior, .normal),
        ("Bow after everything you say for 1 minute", .behavior, .normal),
        ("Nod after every sentence you hear for 2 minutes", .behavior, .normal),
        ("Do a little shoulder shimmy every time you speak for 1 minute", .behavior, .normal),
        ("Keep a pillow on your head until your next turn", .behavior, .normal),
        ("Speak only while standing up for 2 minutes", .behavior, .normal),
        ("Keep your eyes closed every time you speak for 1 minute", .behavior, .normal),
        ("Face the wall when anyone says your name for 2 minutes", .behavior, .normal),
        ("Do not touch your face until your next turn", .behavior, .normal),
        ("Do a little hop each time someone laughs for 2 minutes", .behavior, .normal),
        ("Hold a seductive pose while speaking for 20 seconds", .behavior, .spicy),
        ("Keep slow eye contact with one player for 30 seconds", .behavior, .spicy),
        ("Bite your lip before every sentence for 1 minute", .behavior, .spicy),
        ("Walk like a runway model every time you get up for 2 minutes", .behavior, .spicy),
        ("Sit extra confidently until your next turn", .behavior, .spicy),
        ("Fix your hair dramatically before every answer for 1 minute", .behavior, .spicy),
        ("Give a smirk before every sentence for 30 seconds", .behavior, .spicy),
        ("Slow dance to any music that plays for 2 minutes", .behavior, .spicy),
        ("Do a slow hair flip at the end of every sentence for 1 minute", .behavior, .spicy),
        ("Wink at a different player after every sentence for 2 minutes", .behavior, .spicy),
        ("Blow a kiss after every answer for 1 minute", .behavior, .spicy),
        ("Sit on the floor in a glamorous pose until your next turn", .behavior, .spicy),
        ("Pretend to be on a runway while speaking for 30 seconds", .behavior, .spicy),
        ("Flirt with one player silently for the next 30 seconds", .behavior, .spicy),
        ("Keep a sultry expression for 30 seconds no matter what", .behavior, .spicy),
        ("Touch your own shoulder softly before every sentence for 1 minute", .behavior, .spicy),
        ("Pretend you're in a music video every time you move for 1 minute", .behavior, .spicy),
        ("Keep one hand near your collarbone until your next turn", .behavior, .spicy),
        ("Give one slow wink to each player without saying a word", .behavior, .spicy),
        ("Strike a magazine cover pose every 20 seconds for 1 minute", .behavior, .spicy),

        // Time Limit (40) — normal + spicy
        ("Explain yourself in exactly 5 words", .timeLimit, .normal),
        ("Say three genuine compliments in 10 seconds", .timeLimit, .normal),
        ("Make someone in the room laugh in 15 seconds", .timeLimit, .normal),
        ("Name five red flags in 10 seconds", .timeLimit, .normal),
        ("List 7 fruits in 10 seconds", .timeLimit, .normal),
        ("Come up with a band name in 5 seconds", .timeLimit, .normal),
        ("Describe your day in 3 words, right now", .timeLimit, .normal),
        ("Name 5 cartoon characters in 10 seconds", .timeLimit, .normal),
        ("Say 3 things you love about the host in 10 seconds", .timeLimit, .normal),
        ("Give a 10 second speech about your socks", .timeLimit, .normal),
        ("Name 4 countries that start with the same letter in 15 seconds", .timeLimit, .normal),
        ("List 5 things in your bag in 10 seconds", .timeLimit, .normal),
        ("Invent a slogan for the party in 10 seconds", .timeLimit, .normal),
        ("Say the alphabet backwards in 20 seconds", .timeLimit, .normal),
        ("Name 6 apps on your phone in 10 seconds", .timeLimit, .normal),
        ("Say 3 things you are grateful for in 10 seconds", .timeLimit, .normal),
        ("Describe yourself in one hashtag in 5 seconds", .timeLimit, .normal),
        ("List 5 songs you love in 15 seconds", .timeLimit, .normal),
        ("Do 3 different accents in 15 seconds", .timeLimit, .normal),
        ("Think of a life hack in 10 seconds", .timeLimit, .normal),
        ("Give a weather forecast for the party in 10 seconds", .timeLimit, .normal),
        ("Say 5 animals you could outrun in 10 seconds", .timeLimit, .normal),
        ("Name 5 movies you could watch forever in 15 seconds", .timeLimit, .normal),
        ("Do your best stand up joke in 20 seconds", .timeLimit, .normal),
        ("Say the most flirty sentence you can in 10 seconds", .timeLimit, .spicy),
        ("Come up with a pickup line in 10 seconds", .timeLimit, .spicy),
        ("Describe your ideal date in 15 seconds", .timeLimit, .spicy),
        ("Name 3 qualities that instantly attract you in 10 seconds", .timeLimit, .spicy),
        ("List 3 celebrity crushes in 10 seconds", .timeLimit, .spicy),
        ("Say 3 compliments about appearance in 10 seconds", .timeLimit, .spicy),
        ("Describe your type in exactly 5 words", .timeLimit, .spicy),
        ("Pitch yourself on a dating app in 15 seconds", .timeLimit, .spicy),
        ("Describe your love language in 10 seconds", .timeLimit, .spicy),
        ("List 3 flirting tricks that work on you in 15 seconds", .timeLimit, .spicy),
        ("Whisper something bold in someone's ear within 10 seconds", .timeLimit, .spicy),
        ("Confess a crush name in exactly 3 words within 10 seconds", .timeLimit, .spicy),
        ("Describe your wildest dream in 15 seconds", .timeLimit, .spicy),
        ("Rate the last kiss you had in 5 seconds", .timeLimit, .spicy),
        ("Share a bold confession in exactly 10 words", .timeLimit, .spicy),
        ("Give a sultry compliment to someone here in 10 seconds", .timeLimit, .spicy)
    ])

    // MARK: PENALTY (120)
    private static let penalty: [PartyCard] = make(.penalty, [
        // Penalty Funny (50) — normal + spicy
        ("Talk like a baby for 30 seconds", .penaltyFunny, .normal),
        ("Sing one sentence dramatically like an opera singer", .penaltyFunny, .normal),
        ("Do 5 silly jumps in a row", .penaltyFunny, .normal),
        ("Announce your next sentence as a movie trailer", .penaltyFunny, .normal),
        ("Do your most dramatic sigh three times in a row", .penaltyFunny, .normal),
        ("Laugh like a cartoon villain for 10 seconds", .penaltyFunny, .normal),
        ("Give a 15 second motivational speech to a chair", .penaltyFunny, .normal),
        ("Pretend to cry like a soap opera star for 10 seconds", .penaltyFunny, .normal),
        ("Do a slow clap for yourself for 10 seconds", .penaltyFunny, .normal),
        ("Give a standing ovation to the snacks", .penaltyFunny, .normal),
        ("Speak in a fake accent until your next turn", .penaltyFunny, .normal),
        ("Pretend to be a grumpy old man complaining about nothing", .penaltyFunny, .normal),
        ("Do your most exaggerated yawn three times in a row", .penaltyFunny, .normal),
        ("Pretend to be a zombie for 15 seconds", .penaltyFunny, .normal),
        ("Do a slow motion sneeze", .penaltyFunny, .normal),
        ("Be an infomercial host selling a spoon for 20 seconds", .penaltyFunny, .normal),
        ("Hum the theme song of your life dramatically for 15 seconds", .penaltyFunny, .normal),
        ("Pretend to be a toddler negotiating bedtime", .penaltyFunny, .normal),
        ("Say a made up word and use it in three sentences", .penaltyFunny, .normal),
        ("Do your best horse gallop across the room", .penaltyFunny, .normal),
        ("Pretend you are a news reporter in a windstorm", .penaltyFunny, .normal),
        ("Do your worst robot dance for 15 seconds", .penaltyFunny, .normal),
        ("Pretend to be a sleepy owl for 10 seconds", .penaltyFunny, .normal),
        ("Sing your next sentence like a musical number", .penaltyFunny, .normal),
        ("Do 3 fake sneezes in a row", .penaltyFunny, .normal),
        ("Act like a cat begging for food for 15 seconds", .penaltyFunny, .normal),
        ("Do a dramatic faint onto the couch", .penaltyFunny, .normal),
        ("Pretend to cry because your fake pet ran away", .penaltyFunny, .normal),
        ("Do your worst beatbox for 10 seconds", .penaltyFunny, .normal),
        ("Say one sentence in a whisper then scream the last word", .penaltyFunny, .normal),
        ("Sing your flirty theme song for 15 seconds", .penaltyFunny, .spicy),
        ("Do a dramatic telenovela moment with imaginary rain", .penaltyFunny, .spicy),
        ("Pretend to faint because of a compliment", .penaltyFunny, .spicy),
        ("Blow a dramatic kiss to each player", .penaltyFunny, .spicy),
        ("Do a sultry catwalk across the room and back", .penaltyFunny, .spicy),
        ("Pretend to slow dance with an imaginary partner", .penaltyFunny, .spicy),
        ("Recite a dramatic love poem to a pillow", .penaltyFunny, .spicy),
        ("Flutter your eyelashes at every player for 5 seconds each", .penaltyFunny, .spicy),
        ("Do a slow motion hair flip three times", .penaltyFunny, .spicy),
        ("Sing a jingle about your crush life in 20 seconds", .penaltyFunny, .spicy),
        ("Pretend to take a flirty selfie with each player", .penaltyFunny, .spicy),
        ("Do a cheesy flirty wink at the whole room", .penaltyFunny, .spicy),
        ("Walk across the room like you own a nightclub", .penaltyFunny, .spicy),
        ("Pretend to lose a lover in a dramatic death scene", .penaltyFunny, .spicy),
        ("Act out stumbling home after a wild night", .penaltyFunny, .spicy),
        ("Do a telenovela breakup scene for 20 seconds", .penaltyFunny, .spicy),
        ("Pretend to sneak in at 4am while your parents watch", .penaltyFunny, .spicy),
        ("Recite your dating resume out loud with style", .penaltyFunny, .spicy),
        ("Pretend to accept a fake marriage proposal in tears", .penaltyFunny, .spicy),
        ("Do a dramatic confession scene like a rom com", .penaltyFunny, .spicy),

        // Embarrassing (40) — normal + spicy
        ("Let the group give you a nickname for the night", .embarrassing, .normal),
        ("Speak with an accent until your next turn", .embarrassing, .normal),
        ("Give yourself a dramatic wrestler style introduction", .embarrassing, .normal),
        ("Post a random emoji to your story right now", .embarrassing, .normal),
        ("Change your profile picture for 10 minutes", .embarrassing, .normal),
        ("Read the last message you sent in a theatrical voice", .embarrassing, .normal),
        ("Show the group your last three photos without explanation", .embarrassing, .normal),
        ("Take a silly selfie with the player on your left", .embarrassing, .normal),
        ("Show the group your step count today", .embarrassing, .normal),
        ("Read your most recent notification out loud", .embarrassing, .normal),
        ("Show the group your phone background for 10 seconds", .embarrassing, .normal),
        ("Show your last Google search to the group", .embarrassing, .normal),
        ("Announce your next sentence like a radio host", .embarrassing, .normal),
        ("Give yourself an embarrassing new middle name for the night", .embarrassing, .normal),
        ("Read your last voice message in a funny tone", .embarrassing, .normal),
        ("Show the group your longest group chat", .embarrassing, .normal),
        ("Yawn loudly before every sentence until your next turn", .embarrassing, .normal),
        ("Do your worst magic trick right now", .embarrassing, .normal),
        ("Make an announcement out loud in an over the top voice", .embarrassing, .normal),
        ("Show the last item you bought online", .embarrassing, .normal),
        ("Let a player pick one weird sound you must make before every sentence", .embarrassing, .normal),
        ("Share the worst compliment you've ever received", .embarrassing, .normal),
        ("Show the group your oldest saved meme", .embarrassing, .normal),
        ("Tell the group the last thing you sang in the shower", .embarrassing, .normal),
        ("Say something flirty to the player on your left", .embarrassing, .spicy),
        ("Share the last thing you searched online", .embarrassing, .spicy),
        ("Read the latest DM you sent in a dramatic voice", .embarrassing, .spicy),
        ("Read your last late night text out loud", .embarrassing, .spicy),
        ("Show the group the emoji you use most", .embarrassing, .spicy),
        ("Share the nickname your crush calls you", .embarrassing, .spicy),
        ("Describe your flirting style in one embarrassing sentence", .embarrassing, .spicy),
        ("Confess one old text you wish you could delete", .embarrassing, .spicy),
        ("Say a romantic line in the cheesiest voice possible", .embarrassing, .spicy),
        ("Read the last compliment you got from a crush", .embarrassing, .spicy),
        ("Let the group write a flirty bio and read it out loud", .embarrassing, .spicy),
        ("Share the name of someone you shouldn't have texted", .embarrassing, .spicy),
        ("Confess the last bold move you ever made for love", .embarrassing, .spicy),
        ("Show the group your oldest selfie on your phone", .embarrassing, .spicy),
        ("Tell the group the first song on your romantic playlist", .embarrassing, .spicy),
        ("Say your most embarrassing dating moment out loud", .embarrassing, .spicy),

        // Group Choice (30) — normal + spicy
        ("Let the group choose your pose for a photo", .groupChoice, .normal),
        ("Let the group choose your voice for the next round", .groupChoice, .normal),
        ("Let the group pick one harmless rule for you until the next round", .groupChoice, .normal),
        ("Let the group decide your next song on the playlist", .groupChoice, .normal),
        ("Let the group write a one line bio for you", .groupChoice, .normal),
        ("Let the group choose a compliment you must give to everyone", .groupChoice, .normal),
        ("Let the group decide your next drink", .groupChoice, .normal),
        ("Let the group pick a fake accent you must use", .groupChoice, .normal),
        ("Let the group choose a superhero name for you", .groupChoice, .normal),
        ("Let the group pick a silly walk you must use until your next turn", .groupChoice, .normal),
        ("Let the group choose a dare for you", .groupChoice, .normal),
        ("Let the group pick an animal you must imitate for 30 seconds", .groupChoice, .normal),
        ("Let the group vote on a song you must sing", .groupChoice, .normal),
        ("Let the group decide your new fake age for the night", .groupChoice, .normal),
        ("Let the group choose a facial expression you must hold for 1 minute", .groupChoice, .normal),
        ("Let the group name a random object on the table and you must praise it", .groupChoice, .normal),
        ("Let the group pick one word you cannot say for 5 minutes", .groupChoice, .normal),
        ("Let the group decide a silly story starter for you", .groupChoice, .normal),
        ("Let the group choose a dance move you must do right now", .groupChoice, .spicy),
        ("Let the group pick a flirty compliment you give to each player", .groupChoice, .spicy),
        ("Let the group choose one pet name you use for everyone", .groupChoice, .spicy),
        ("Let the group pick a pickup line for you to say", .groupChoice, .spicy),
        ("Let the group decide the first message you send your crush", .groupChoice, .spicy),
        ("Let the group choose a romantic song you must hum", .groupChoice, .spicy),
        ("Let the group pick a flirty pose you must hold for 15 seconds", .groupChoice, .spicy),
        ("Let the group decide one flirty rule for the night", .groupChoice, .spicy),
        ("Let the group choose a bold confession for you to make", .groupChoice, .spicy),
        ("Let the group pick the last person you should text tonight", .groupChoice, .spicy),
        ("Let the group choose a risky rule you must follow", .groupChoice, .spicy),
        ("Let the group decide a daring dare for you", .groupChoice, .spicy)
    ])

    // MARK: COUPLE (140)
    private static let couple: [PartyCard] = make(.couple, [
        // Couple Questions (60) — normal + spicy
        ("What was your first impression of each other?", .coupleQuestions, .normal),
        ("Who said sorry first after your last fight?", .coupleQuestions, .normal),
        ("What is one thing your partner does that always makes you smile?", .coupleQuestions, .normal),
        ("When did you know this was something real?", .coupleQuestions, .normal),
        ("What is the small habit you love most about each other?", .coupleQuestions, .normal),
        ("What was your favorite date together so far?", .coupleQuestions, .normal),
        ("What is something you want to do together in the next year?", .coupleQuestions, .normal),
        ("What is one thing that changed your relationship for the better?", .coupleQuestions, .normal),
        ("What is a song that reminds you of each other?", .coupleQuestions, .normal),
        ("What is something you admire in your partner's work?", .coupleQuestions, .normal),
        ("What is a place you want to travel together?", .coupleQuestions, .normal),
        ("What is something silly only the two of you understand?", .coupleQuestions, .normal),
        ("What is the first thing you noticed about each other?", .coupleQuestions, .normal),
        ("What is a small promise you have kept?", .coupleQuestions, .normal),
        ("What is one thing you do better together than apart?", .coupleQuestions, .normal),
        ("What is something your partner does that makes you feel safe?", .coupleQuestions, .normal),
        ("What is a memory you want to keep forever?", .coupleQuestions, .normal),
        ("What was the best surprise you gave each other?", .coupleQuestions, .normal),
        ("What is something you both want to learn together?", .coupleQuestions, .normal),
        ("What is a tradition you hope to build together?", .coupleQuestions, .normal),
        ("What is one thing you appreciate more now than in the beginning?", .coupleQuestions, .normal),
        ("What is something you quietly do for each other?", .coupleQuestions, .normal),
        ("What is one thing you love about how you fight?", .coupleQuestions, .normal),
        ("What is the funniest moment you've shared together?", .coupleQuestions, .normal),
        ("What is the best piece of advice you've taken from each other?", .coupleQuestions, .normal),
        ("What is a compliment you wish you said more?", .coupleQuestions, .normal),
        ("What is one thing you are proud of each other for this year?", .coupleQuestions, .normal),
        ("What is the best thing about being in this relationship?", .coupleQuestions, .normal),
        ("What is a dream you share together?", .coupleQuestions, .normal),
        ("What is a memory that always makes you laugh?", .coupleQuestions, .normal),
        ("What is something you want to stop worrying about together?", .coupleQuestions, .normal),
        ("What is one thing you want to hear more often?", .coupleQuestions, .normal),
        ("What is the first thing you'd say in a love letter to each other?", .coupleQuestions, .normal),
        ("What is a song you want as your couple anthem?", .coupleQuestions, .normal),
        ("What is one thing that always brings you back to each other?", .coupleQuestions, .normal),
        ("What is one small ritual you never want to lose?", .coupleQuestions, .normal),
        ("What is the most attractive thing you find about each other?", .coupleQuestions, .spicy),
        ("What is the cutest jealous moment you've shared?", .coupleQuestions, .spicy),
        ("What is one flirty thing your partner does that still works every time?", .coupleQuestions, .spicy),
        ("What is a sweet way your partner lets you know they miss you?", .coupleQuestions, .spicy),
        ("What is a flirty memory that still makes you blush?", .coupleQuestions, .spicy),
        ("What is the sweetest kiss you've shared?", .coupleQuestions, .spicy),
        ("What is a look that instantly tells you what your partner wants?", .coupleQuestions, .spicy),
        ("What is the best date night you want to repeat?", .coupleQuestions, .spicy),
        ("What is one way your partner makes you feel wanted?", .coupleQuestions, .spicy),
        ("What is a flirty inside joke between the two of you?", .coupleQuestions, .spicy),
        ("What is the first moment you felt butterflies with them?", .coupleQuestions, .spicy),
        ("What is your favorite way your partner touches your hand?", .coupleQuestions, .spicy),
        ("What is a cheesy thing you secretly love doing together?", .coupleQuestions, .spicy),
        ("What is the most romantic thing your partner has ever done?", .coupleQuestions, .spicy),
        ("What is a shy thing you wanted to ask but never did?", .coupleQuestions, .spicy),
        ("What is something you have been afraid to ask each other?", .coupleQuestions, .spicy),
        ("What is the most intimate memory you share?", .coupleQuestions, .spicy),
        ("What is a fantasy you've never told your partner?", .coupleQuestions, .spicy),
        ("What is a secret desire you've been holding back?", .coupleQuestions, .spicy),
        ("What was your most passionate moment together?", .coupleQuestions, .spicy),
        ("What is something bold you want to try together?", .coupleQuestions, .spicy),
        ("What is a private thing you miss when apart?", .coupleQuestions, .spicy),
        ("What is the boldest confession you can give each other now?", .coupleQuestions, .spicy),
        ("What is a favorite memory from your first few nights together?", .coupleQuestions, .spicy),

        // Dynamics (40) — normal + spicy
        ("Who gets jealous faster?", .dynamics, .normal),
        ("Who talks more when upset?", .dynamics, .normal),
        ("Who is more stubborn in arguments?", .dynamics, .normal),
        ("Who apologizes first, usually?", .dynamics, .normal),
        ("Who is the planner and who is the chaos?", .dynamics, .normal),
        ("Who is more likely to cry during a movie?", .dynamics, .normal),
        ("Who is more romantic on a regular day?", .dynamics, .normal),
        ("Who snores louder?", .dynamics, .normal),
        ("Who steals the blanket more at night?", .dynamics, .normal),
        ("Who controls the playlist in the car?", .dynamics, .normal),
        ("Who is the better cook?", .dynamics, .normal),
        ("Who is the better driver, honestly?", .dynamics, .normal),
        ("Who spends more time on their phone?", .dynamics, .normal),
        ("Who is more likely to forget an anniversary?", .dynamics, .normal),
        ("Who is the first to text when apart?", .dynamics, .normal),
        ("Who overthinks more?", .dynamics, .normal),
        ("Who laughs at their own jokes more?", .dynamics, .normal),
        ("Who is more organized at home?", .dynamics, .normal),
        ("Who takes longer to get ready?", .dynamics, .normal),
        ("Who is more patient in traffic?", .dynamics, .normal),
        ("Who is the better listener?", .dynamics, .normal),
        ("Who remembers small details better?", .dynamics, .normal),
        ("Who is louder in an argument?", .dynamics, .normal),
        ("Who is the softer one emotionally?", .dynamics, .normal),
        ("Who initiates more and who resists more?", .dynamics, .spicy),
        ("Who flirts more outside the relationship?", .dynamics, .spicy),
        ("Who is more jealous of exes?", .dynamics, .spicy),
        ("Who sneaks more kisses during the day?", .dynamics, .spicy),
        ("Who is the bigger flirt at parties?", .dynamics, .spicy),
        ("Who takes the lead when you slow dance?", .dynamics, .spicy),
        ("Who gets needier when tired?", .dynamics, .spicy),
        ("Who is more likely to plan a surprise date?", .dynamics, .spicy),
        ("Who says I love you first, more often?", .dynamics, .spicy),
        ("Who is more romantic in text messages?", .dynamics, .spicy),
        ("Who starts flirting first after a fight?", .dynamics, .spicy),
        ("Who is more open about desires?", .dynamics, .spicy),
        ("Who pushes boundaries more in private?", .dynamics, .spicy),
        ("Who is bolder after midnight?", .dynamics, .spicy),
        ("Who is more likely to send a risky text?", .dynamics, .spicy),
        ("Who sets the mood better?", .dynamics, .spicy),

        // Playful (40) — normal + spicy
        ("Describe your partner in exactly one word", .playful, .normal),
        ("Say one thing you secretly admire about each other", .playful, .normal),
        ("Who would survive longer on a bad trip together?", .playful, .normal),
        ("Make up a cute nickname for each other right now", .playful, .normal),
        ("Rate each other's cooking on a scale of 1 to 10, honestly", .playful, .normal),
        ("Swap one thing about each other for a day, what would it be?", .playful, .normal),
        ("Give each other an honest star review", .playful, .normal),
        ("Name one thing you always want to do together on a Sunday", .playful, .normal),
        ("Write a one line review of the last movie you watched together", .playful, .normal),
        ("What is your couple superpower?", .playful, .normal),
        ("What would the title of your relationship sitcom be?", .playful, .normal),
        ("Choose a theme song for your relationship right now", .playful, .normal),
        ("What emoji describes your relationship today?", .playful, .normal),
        ("Invent a couple handshake in 30 seconds", .playful, .normal),
        ("Name a food combo that represents the two of you", .playful, .normal),
        ("If you were animals, what would you be?", .playful, .normal),
        ("Give each other a 15 second appreciation speech", .playful, .normal),
        ("Exchange one thing you love about each other right now", .playful, .normal),
        ("Make a fake ad for your partner in 20 seconds", .playful, .normal),
        ("Describe your love story as a movie genre", .playful, .normal),
        ("Give each other a trophy category for the night", .playful, .normal),
        ("Describe your first date in 3 words", .playful, .normal),
        ("If your love had a flavor, what would it be?", .playful, .normal),
        ("Name one tiny thing that always makes you both laugh", .playful, .normal),
        ("Whisper the last compliment you thought about each other", .playful, .spicy),
        ("Describe your partner with one flirty word", .playful, .spicy),
        ("Rate each other's kiss on a scale of 1 to 10", .playful, .spicy),
        ("Give each other a cheesy pickup line you would have used", .playful, .spicy),
        ("Share the first flirty text you sent each other, if you remember", .playful, .spicy),
        ("Say the cheesiest nickname you have for each other", .playful, .spicy),
        ("Share your favorite inside joke that makes you both blush", .playful, .spicy),
        ("Write a flirty caption you would post for your partner", .playful, .spicy),
        ("Describe the best kiss you've ever had together", .playful, .spicy),
        ("Give each other one flirty compliment right now", .playful, .spicy),
        ("Describe a fantasy you've kept to yourself until now", .playful, .spicy),
        ("Share one bold thing you want to do together this year", .playful, .spicy),
        ("Whisper a private compliment to each other", .playful, .spicy),
        ("Share the wildest memory you have together", .playful, .spicy),
        ("Describe the most intimate look you've shared", .playful, .spicy),
        ("Say one thing you miss most when you're alone", .playful, .spicy)
    ])

    // MARK: TALK — ICEBREAKER (128)
    private static let talkIcebreaker: [PartyCard] = make(.talk, [
        // Intro (30) — normal + spicy
        ("Say your name and one weird fact about yourself", .icebreaker, .normal),
        ("Tell us one thing people usually guess wrong about you", .icebreaker, .normal),
        ("What is one word your friends would use to describe you?", .icebreaker, .normal),
        ("Share one talent nobody here knows you have", .icebreaker, .normal),
        ("What was your nickname as a kid?", .icebreaker, .normal),
        ("Tell us one thing you are weirdly good at", .icebreaker, .normal),
        ("Share your name and the last thing that made you proud", .icebreaker, .normal),
        ("What is the most unusual job you've ever had?", .icebreaker, .normal),
        ("Say your name and your hometown in one sentence", .icebreaker, .normal),
        ("Tell us your name and one goal for the week", .icebreaker, .normal),
        ("What is something your name does not say about you?", .icebreaker, .normal),
        ("Introduce yourself as if you were a book title", .icebreaker, .normal),
        ("Say your name and one thing you are grateful for today", .icebreaker, .normal),
        ("Tell us your name and a fun fact from your phone camera roll", .icebreaker, .normal),
        ("What is a talent you inherited from your family?", .icebreaker, .normal),
        ("Introduce yourself with your name and a favorite hobby", .icebreaker, .normal),
        ("Share one dream you've had since childhood", .icebreaker, .normal),
        ("Say one thing that makes you different from everyone here", .icebreaker, .normal),
        ("Say your name and the best compliment you've ever received", .icebreaker, .spicy),
        ("Introduce yourself and share your ideal first date in one line", .icebreaker, .spicy),
        ("Share a flirty word that describes you in one sentence", .icebreaker, .spicy),
        ("Introduce yourself with a cheesy pickup line", .icebreaker, .spicy),
        ("Say your name and one thing that instantly attracts you to someone", .icebreaker, .spicy),
        ("Introduce yourself using your ideal type in one sentence", .icebreaker, .spicy),
        ("Share your name and the last crush fact you can reveal", .icebreaker, .spicy),
        ("Say your name like you're introducing yourself on a dating show", .icebreaker, .spicy),
        ("Introduce yourself with one bold truth about your love life", .icebreaker, .spicy),
        ("Say your name and the wildest place you've traveled", .icebreaker, .spicy),
        ("Share your name and the last risky decision you took", .icebreaker, .spicy),
        ("Introduce yourself like you're the lead of a romance novel", .icebreaker, .spicy),

        // Icebreaker Fun (35) — normal + spicy
        ("Introduce yourself like a celebrity on the red carpet", .icebreaker, .normal),
        ("Say what animal matches your personality today", .icebreaker, .normal),
        ("If your life was a show, what would the title be?", .icebreaker, .normal),
        ("Describe your day using a single movie title", .icebreaker, .normal),
        ("What is a skill you secretly want to show off?", .icebreaker, .normal),
        ("Say your name in the most dramatic way possible", .icebreaker, .normal),
        ("Introduce yourself like a wrestler entering the ring", .icebreaker, .normal),
        ("Describe your week in three emojis", .icebreaker, .normal),
        ("Say what superpower matches your mood today", .icebreaker, .normal),
        ("Describe your energy today as a song title", .icebreaker, .normal),
        ("Say what fictional character you would trade lives with", .icebreaker, .normal),
        ("Describe yourself using only food words", .icebreaker, .normal),
        ("Say what career you would choose if money wasn't real", .icebreaker, .normal),
        ("What is a very specific thing you get excited about?", .icebreaker, .normal),
        ("Say what would be in your survival kit for a weekend", .icebreaker, .normal),
        ("Describe your day using a weather metaphor", .icebreaker, .normal),
        ("Say which emoji you overuse the most", .icebreaker, .normal),
        ("Describe yourself using only the food you ate today", .icebreaker, .normal),
        ("Introduce yourself like you're starting a vlog", .icebreaker, .normal),
        ("Share one dance move that fits your current mood", .icebreaker, .normal),
        ("Say what your autobiography subtitle would be", .icebreaker, .normal),
        ("Describe your flirting style in three words", .icebreaker, .spicy),
        ("Introduce yourself like you're on a dating show", .icebreaker, .spicy),
        ("Describe your type in exactly 5 words", .icebreaker, .spicy),
        ("Say what would make you instantly blush", .icebreaker, .spicy),
        ("Describe your vibe on a first date in one sentence", .icebreaker, .spicy),
        ("What is a compliment that would get you every time?", .icebreaker, .spicy),
        ("Describe your love language in one word", .icebreaker, .spicy),
        ("Share one romantic habit you secretly love", .icebreaker, .spicy),
        ("Say what song would play if you entered a dating show", .icebreaker, .spicy),
        ("Say the boldest thing you've done for attention", .icebreaker, .spicy),
        ("Describe your most memorable date in one sentence", .icebreaker, .spicy),
        ("Share one thing that always makes you flirt back", .icebreaker, .spicy),
        ("Share your wildest travel story in one line", .icebreaker, .spicy),
        ("Introduce yourself with a daring truth most people don't know", .icebreaker, .spicy),

        // Quick Topic (35) — normal + spicy
        ("Morning person or night person?", .icebreaker, .normal),
        ("City life or nature?", .icebreaker, .normal),
        ("Coffee or tea, and why?", .icebreaker, .normal),
        ("Beach vacation or mountain trip?", .icebreaker, .normal),
        ("Texting or calling?", .icebreaker, .normal),
        ("Plans or surprise?", .icebreaker, .normal),
        ("Big party or small dinner?", .icebreaker, .normal),
        ("Books or movies?", .icebreaker, .normal),
        ("Sweet or salty?", .icebreaker, .normal),
        ("Summer or winter?", .icebreaker, .normal),
        ("Cats or dogs?", .icebreaker, .normal),
        ("Save or spend?", .icebreaker, .normal),
        ("Cook at home or eat out?", .icebreaker, .normal),
        ("Window seat or aisle seat?", .icebreaker, .normal),
        ("Early bird or last minute?", .icebreaker, .normal),
        ("Open plans or strict schedule?", .icebreaker, .normal),
        ("Comedy or drama?", .icebreaker, .normal),
        ("Pop or hip hop?", .icebreaker, .normal),
        ("Theme park or museum?", .icebreaker, .normal),
        ("Solo travel or group travel?", .icebreaker, .normal),
        ("Quiet night in or loud night out?", .icebreaker, .normal),
        ("Love at first sight or slow burn?", .icebreaker, .spicy),
        ("Flirty texts or voice notes?", .icebreaker, .spicy),
        ("Dinner date or adventure date?", .icebreaker, .spicy),
        ("First move or wait to be chased?", .icebreaker, .spicy),
        ("Classic romance or modern dating?", .icebreaker, .spicy),
        ("Cheesy compliments or subtle flirting?", .icebreaker, .spicy),
        ("Eye contact or sneaky smile?", .icebreaker, .spicy),
        ("Forehead kiss or hand kiss?", .icebreaker, .spicy),
        ("Morning cuddles or goodnight messages?", .icebreaker, .spicy),
        ("Long kisses or playful kisses?", .icebreaker, .spicy),
        ("Whispered secrets or bold confessions?", .icebreaker, .spicy),
        ("Candlelight or rooftop moonlight?", .icebreaker, .spicy),
        ("Slow dance or late night drive?", .icebreaker, .spicy),
        ("Say it out loud or write it in a note?", .icebreaker, .spicy),

        // Light Action (28) — normal + spicy
        ("Make everyone laugh in 10 seconds", .icebreaker, .normal),
        ("Show your current mood using only your face", .icebreaker, .normal),
        ("Do your most dramatic hello right now", .icebreaker, .normal),
        ("Give a five second hype for the person on your right", .icebreaker, .normal),
        ("Do a little dance move to introduce yourself", .icebreaker, .normal),
        ("Strike a power pose and hold it for 5 seconds", .icebreaker, .normal),
        ("Do your best handshake with the person on your left", .icebreaker, .normal),
        ("Give a cheer for the host in 5 seconds", .icebreaker, .normal),
        ("Do a quick victory dance for no reason", .icebreaker, .normal),
        ("Wave like a celebrity greeting fans", .icebreaker, .normal),
        ("Show your happiest smile and hold it", .icebreaker, .normal),
        ("Do a silly little walk across the room", .icebreaker, .normal),
        ("Make a fun sound that describes your mood", .icebreaker, .normal),
        ("Give everyone a warm high five one by one", .icebreaker, .normal),
        ("Take a deep breath together with the room", .icebreaker, .normal),
        ("Do a playful bow to the group", .icebreaker, .normal),
        ("Do your best imitation of a talk show host greeting the crowd", .icebreaker, .normal),
        ("Blow a friendly kiss to the group", .icebreaker, .spicy),
        ("Do your best slow motion hair flip", .icebreaker, .spicy),
        ("Strike your most flirty pose for 5 seconds", .icebreaker, .spicy),
        ("Give a playful wink to someone across the room", .icebreaker, .spicy),
        ("Do a sultry slow wave to the group", .icebreaker, .spicy),
        ("Walk like a runway model across the room", .icebreaker, .spicy),
        ("Do your boldest magazine cover pose", .icebreaker, .spicy),
        ("Share a slow wink with each player in order", .icebreaker, .spicy),
        ("Do a dramatic slow dance pose for 10 seconds", .icebreaker, .spicy),
        ("Give your best intense gaze to the group", .icebreaker, .spicy),
        ("Pretend to lower your sunglasses slowly and hold eye contact", .icebreaker, .spicy)
    ])
}
