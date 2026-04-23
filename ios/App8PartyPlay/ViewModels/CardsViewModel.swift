import Foundation
import SwiftUI
import Observation

// SAFETY NOTE:
// - This view model only reads the locally bundled `CardDeckSeed`.
// - No remote fetching, no feature flags, no server-side content switching.
// - No 18+ or adult content path exists. Only two tiers: normal and spicy.
@Observable
@MainActor
final class CardsViewModel {
    var savedCardIDs: Set<UUID> {
        didSet { persistSaved() }
    }

    private var recentIDsByCategory: [CardCategory: [UUID]] = [:]

    init() {
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

    func count(for category: CardCategory) -> Int {
        CardDeckSeed.cards(for: category).count
    }

    func randomCard(
        category: CardCategory,
        subtype: CardSubtype?,
        includeSpicy: Bool,
        excluding currentID: UUID?
    ) -> PartyCard? {
        let allowed = CardDeckSeed.cards(for: category).filter { card in
            if let subtype, card.subtype != subtype { return false }
            if includeSpicy {
                return true
            } else {
                return !card.isSpicy
            }
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
