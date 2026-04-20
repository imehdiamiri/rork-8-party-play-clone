import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class CardsViewModel {
    var show18Plus: Bool {
        didSet { UserDefaults.standard.set(show18Plus, forKey: "cards.show18Plus") }
    }
    var savedCardIDs: Set<UUID> {
        didSet { persistSaved() }
    }

    private var recentIDsByCategory: [CardCategory: [UUID]] = [:]

    init() {
        self.show18Plus = UserDefaults.standard.bool(forKey: "cards.show18Plus")
        if let data = UserDefaults.standard.data(forKey: "cards.saved"),
           let ids = try? JSONDecoder().decode([UUID].self, from: data) {
            self.savedCardIDs = Set(ids)
        } else {
            self.savedCardIDs = []
        }
    }

    private func persistSaved() {
        if let data = try? JSONEncoder().encode(Array(savedCardIDs)) {
            UserDefaults.standard.set(data, forKey: "cards.saved")
        }
    }

    func cards(for category: CardCategory) -> [PartyCard] {
        CardDeckSeed.cards(for: category)
    }

    func count(for category: CardCategory, include18Plus: Bool) -> Int {
        CardDeckSeed.cards(for: category).filter { include18Plus || !$0.is18Plus }.count
    }

    /// Whether the category has any 18+ content at all.
    func has18PlusContent(in category: CardCategory) -> Bool {
        CardDeckSeed.cards(for: category).contains { $0.is18Plus }
    }

    func randomCard(
        category: CardCategory,
        subtype: CardSubtype?,
        includeSpicy: Bool,
        include18Plus: Bool,
        excluding currentID: UUID?
    ) -> PartyCard? {
        let matchesContentLayer: (PartyCard) -> Bool = { card in
            switch (includeSpicy, include18Plus) {
            case (false, false):
                return !card.isSpicy && !card.is18Plus
            case (true, false):
                return card.isSpicy && !card.is18Plus
            case (false, true):
                return card.is18Plus
            case (true, true):
                return card.isSpicy || card.is18Plus
            }
        }
        let allowed = CardDeckSeed.cards(for: category).filter { card in
            if let subtype, card.subtype != subtype { return false }
            return matchesContentLayer(card)
        }
        return pickAvoidingRecent(from: allowed, category: category, excluding: currentID)
    }

    private func pickAvoidingRecent(from pool: [PartyCard], category: CardCategory, excluding currentID: UUID?) -> PartyCard? {
        guard !pool.isEmpty else { return nil }
        let recents = recentIDsByCategory[category] ?? []
        var fresh = pool.filter { !recents.contains($0.id) && $0.id != currentID }
        if fresh.isEmpty { fresh = pool.filter { $0.id != currentID } }
        if fresh.isEmpty { fresh = pool }
        guard let pick = fresh.randomElement() else { return nil }
        var updated = recents
        updated.append(pick.id)
        let cap = min(12, max(1, pool.count - 1))
        if updated.count > cap {
            updated.removeFirst(updated.count - cap)
        }
        recentIDsByCategory[category] = updated
        return pick
    }

    func toggleSaved(_ card: PartyCard) {
        if savedCardIDs.contains(card.id) {
            savedCardIDs.remove(card.id)
        } else {
            savedCardIDs.insert(card.id)
        }
    }

    func isSaved(_ card: PartyCard) -> Bool {
        savedCardIDs.contains(card.id)
    }

    func isLocked(_ card: PartyCard, isPremium: Bool) -> Bool {
        if isPremium { return false }
        return card.isPremium
    }
}
