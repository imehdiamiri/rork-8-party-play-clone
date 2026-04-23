import Foundation
import SwiftUI

nonisolated struct PartyGameTutorial: Identifiable, Hashable, Sendable {
    let id: String
    let iconName: String
    let title: String
    let description: String
    let howToPlay: [String]
    let rules: [String]
    let tint: Color

    static let allGames: [PartyGameTutorial] = [
        PartyGameTutorial(
            id: "fast_categories",
            iconName: "bolt.fill",
            title: "Fast Categories",
            description: "Say a word in a category as fast as possible.",
            howToPlay: [
                "Choose a letter (example: \"M\")",
                "Choose a category (city, food, animal, etc.)",
                "Players must quickly say a word starting with that letter"
            ],
            rules: ["Delay = lose", "Repeating a word = lose"],
            tint: .orange
        ),
        PartyGameTutorial(
            id: "truth_or_lie",
            iconName: "eye.fill",
            title: "Truth or Lie",
            description: "Find the lie among statements.",
            howToPlay: [
                "Each player says 2 truths and 1 lie",
                "Other players guess which one is the lie"
            ],
            rules: ["Trick others to win"],
            tint: .pink
        ),
        PartyGameTutorial(
            id: "no_laugh",
            iconName: "face.smiling.fill",
            title: "No Laugh",
            description: "Try not to laugh challenge.",
            howToPlay: [
                "One player tries to make others laugh",
                "Others must keep a straight face"
            ],
            rules: ["If you laugh → you lose"],
            tint: .yellow
        ),
        PartyGameTutorial(
            id: "forbidden_word",
            iconName: "character.bubble.fill",
            title: "Forbidden Word",
            description: "Explain a word without using certain words.",
            howToPlay: [
                "Choose a target word",
                "Choose 2–3 forbidden words",
                "Player explains without using forbidden words"
            ],
            rules: ["Saying forbidden word = lose"],
            tint: .red
        ),
        PartyGameTutorial(
            id: "fast_answer",
            iconName: "hare.fill",
            title: "Fast Answer",
            description: "Answer instantly without thinking.",
            howToPlay: [
                "One player asks a question",
                "Next player must answer immediately"
            ],
            rules: ["Delay = lose"],
            tint: .cyan
        ),
        PartyGameTutorial(
            id: "story_chain",
            iconName: "book.closed.fill",
            title: "Story Chain",
            description: "Create a story together.",
            howToPlay: [
                "First player starts with a sentence",
                "Each player adds one sentence"
            ],
            rules: ["Keep the story going", "No long pauses"],
            tint: .green
        ),
        PartyGameTutorial(
            id: "who_am_i",
            iconName: "theatermasks.fill",
            title: "Who Am I",
            description: "Guess your hidden identity.",
            howToPlay: [
                "Each player gets a secret character",
                "They don't know who they are",
                "They ask yes/no questions"
            ],
            rules: ["Only yes/no questions allowed"],
            tint: .purple
        ),
        PartyGameTutorial(
            id: "wrong_answer_only",
            iconName: "xmark.circle.fill",
            title: "Wrong Answer Only",
            description: "Always give the wrong answer.",
            howToPlay: [
                "Ask a question",
                "Player must give an incorrect answer"
            ],
            rules: ["Correct answer = lose"],
            tint: .indigo
        ),
        PartyGameTutorial(
            id: "three_word_game",
            iconName: "textformat.size",
            title: "3 Word Game",
            description: "Say exactly three words.",
            howToPlay: [
                "Choose a topic",
                "Each player says exactly 3 related words"
            ],
            rules: ["More or less than 3 words = lose", "Delay = lose"],
            tint: .teal
        ),
        PartyGameTutorial(
            id: "funny_answer",
            iconName: "mic.fill",
            title: "Funny Answer",
            description: "Give the funniest answer.",
            howToPlay: [
                "Ask a normal question",
                "Players answer in a funny way"
            ],
            rules: ["The funniest answer wins"],
            tint: .mint
        ),
        PartyGameTutorial(
            id: "reverse_thinking",
            iconName: "arrow.2.circlepath.circle.fill",
            title: "Reverse Thinking",
            description: "Think the opposite way.",
            howToPlay: [
                "Ask a normal question",
                "Players must give the worst possible answer"
            ],
            rules: ["Logical or good answer = lose"],
            tint: .blue
        ),
        PartyGameTutorial(
            id: "one_letter_only",
            iconName: "a.circle.fill",
            title: "One Letter Only",
            description: "Speak using only one letter.",
            howToPlay: [
                "Choose a letter",
                "Players must form sentences mostly using that letter"
            ],
            rules: ["Using unrelated letters = lose"],
            tint: .brown
        ),
        PartyGameTutorial(
            id: "mixed_acting",
            iconName: "figure.walk.circle.fill",
            title: "Mixed Acting",
            description: "Act a funny combination.",
            howToPlay: [
                "Combine two things (animal + job)",
                "Example: \"Dog + Police\"",
                "Player acts it"
            ],
            rules: ["No speaking allowed"],
            tint: .orange
        ),
        PartyGameTutorial(
            id: "question_only",
            iconName: "questionmark.bubble.fill",
            title: "Question Only",
            description: "Only speak using questions.",
            howToPlay: [
                "Players must communicate using only questions"
            ],
            rules: ["Normal sentence = lose"],
            tint: .pink
        ),
        PartyGameTutorial(
            id: "word_chain",
            iconName: "link.circle.fill",
            title: "Word Chain",
            description: "Continue using the last letter.",
            howToPlay: [
                "One player says a word",
                "Next player must say a word starting with last letter"
            ],
            rules: ["Repeating words = lose", "Delay = lose"],
            tint: .cyan
        ),
        PartyGameTutorial(
            id: "forbidden_number",
            iconName: "number.circle.fill",
            title: "Forbidden Number",
            description: "Avoid saying a specific number.",
            howToPlay: [
                "Count numbers in order",
                "Replace forbidden number with an action (clap, jump, etc.)"
            ],
            rules: ["Saying forbidden number = lose"],
            tint: .red
        ),
        PartyGameTutorial(
            id: "what_if",
            iconName: "lightbulb.fill",
            title: "What If",
            description: "Answer creative hypothetical questions.",
            howToPlay: [
                "Ask \"What if…\" questions",
                "Players give creative answers"
            ],
            rules: ["Be creative", "No boring answers"],
            tint: .purple
        ),
        PartyGameTutorial(
            id: "one_word_answer",
            iconName: "1.circle.fill",
            title: "One Word Answer",
            description: "Answer using only one word.",
            howToPlay: [
                "Ask a question",
                "Players must answer with one word"
            ],
            rules: ["More than one word = lose"],
            tint: .green
        )
    ]
}
