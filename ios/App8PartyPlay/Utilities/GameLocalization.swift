import Foundation

nonisolated enum GameLocalizer {

    static func gameName(_ game: GameType, language: AppLanguage) -> String {
        game.name
    }

    static func gameDescription(_ game: GameType, language: AppLanguage) -> String {
        game.shortDescription
    }

    static func gameInstructions(_ game: GameType, language: AppLanguage) -> [String] {
        _ = language
        if game.rawValue == GameType.reverseSinging.rawValue {
            return [
                "Player 1 records anything — a word, a sound, a melody.",
                "Player 2 listens to the reversed version.",
                "Player 2 records their best mimic of what they heard.",
                "Hit Result and hear how close they got!"
            ]
        }

        if game.rawValue == GameType.guessTheSeconds.rawValue {
            return [
                "Pick players and rounds, then choose a target time.",
                "Press Start to hide the target and begin counting mentally.",
                "Press Stop when you think the exact time has passed.",
                "Lowest total difference across all rounds wins."
            ]
        }

        if game.rawValue == GameType.tenTangle.rawValue {
            return [
                "Each round, one player is the Guesser. Others get a secret number 1–10.",
                "A scenario is shown. Players act based on their number (1 = Disaster, 10 = Perfect).",
                "The Guesser watches and tries to guess each player's secret number.",
                "Exact match = +1 point. Most points after all rounds wins!"
            ]
        }

        if game.rawValue == GameType.imposter.rawValue {
            return [
                "Each player secretly sees their role — one is the Imposter.",
                "A secret word is revealed to everyone except the Imposter.",
                "Discuss or give clues to figure out who the Imposter is.",
                "Vote on the suspect. Majority catches the Imposter!"
            ]
        }

        if game.rawValue == GameType.memoryPath.rawValue {
            return [
                "A hidden path exists from Start to End on the grid.",
                "Tap tiles to discover the path — wrong tile resets your progress!",
                "Memorize the path and complete it faster than everyone else.",
                "Use your one-time hint to reveal the full path for 5 seconds."
            ]
        }

        if game.rawValue == GameType.passGuess.rawValue {
            return [
                "A question is shown — each player writes their answer in turn.",
                "Pass the phone to the next player so they can write theirs.",
                "Once everyone has answered, all answers are revealed and players guess who wrote what.",
                "Correct guess = points! Most points wins."
            ]
        }

        if game.rawValue == GameType.memoryGrid.rawValue {
            return [
                "A grid of face-down tiles is shown.",
                "Tap two tiles to flip them — if they match, they stay open.",
                "If they don't match, they flip back — use your memory!",
                "Find all pairs as fast as possible to win."
            ]
        }

        if game.rawValue == GameType.tapInOrder.rawValue {
            return [
                "Two memory modes: Number Memory and Pattern Memory.",
                "You get 5 seconds to memorize the board.",
                "Number Memory: tap the tiles in order (1 → N) from memory.",
                "Pattern Memory: tap every highlighted tile — order doesn't matter.",
                "Most correct taps with the fewest mistakes wins."
            ]
        }

        if game.rawValue == GameType.spinBottle.rawValue {
            return [
                "Add player names — they sit around in a circle on screen.",
                "Tap Spin to send the bottle spinning. It will randomly stop at one player.",
                "That player picks Truth or Dare. A full-screen card is revealed.",
                "Up to 2 rerolls if the prompt doesn't fit. Tap Done and spin again."
            ]
        }

        if game.rawValue == GameType.colorTrap.rawValue {
            return [
                "A forbidden color is shown before you start.",
                "Tap every colored tile EXCEPT the forbidden one.",
                "Three wrong taps and you're out.",
                "Survive longest and score the most hits to win."
            ]
        }

        return [
            "This slot is ready for a new game module.",
            "Each new game can bring its own setup, prompts, and dedicated flow.",
            "For now, use this screen as a clean template for the next game addition."
        ]
    }

    static func modeName(_ mode: GameMode, language: AppLanguage) -> String {
        _ = language
        return mode.title
    }

    static func modeSubtitle(_ mode: GameMode, language: AppLanguage) -> String {
        _ = language
        return mode.subtitle
    }

    static func chooseMode(language: AppLanguage) -> String {
        _ = language
        return "Select Mode"
    }

    static func howItWorks(language: AppLanguage) -> String {
        _ = language
        return "How to Play"
    }

    static func playerCountText(_ game: GameType, language: AppLanguage) -> String {
        _ = language
        return game.playerCountText
    }
}
