import Testing
import Foundation
@testable import App8PartyPlay

@MainActor
struct MemoryGridViewModelTests {
    @Test func startGameInitializesBoard() async throws {
        let vm = MemoryGridViewModel()
        vm.startGame(size: .small4x4)
        #expect(vm.tiles.count == 16)
        #expect(vm.totalPairs == 8)
        #expect(vm.matchedPairs == 0)
        #expect(vm.isGameActive)
        #expect(!vm.isGameComplete)
        vm.cleanup()
    }

    @Test func pairsAreValid() async throws {
        let vm = MemoryGridViewModel()
        vm.startGame(size: .small4x4)
        let grouped = Dictionary(grouping: vm.tiles, by: { $0.pairId })
        for (_, pair) in grouped {
            #expect(pair.count == 2)
            #expect(pair[0].symbol == pair[1].symbol)
        }
        vm.cleanup()
    }

    @Test func resetClearsBoard() async throws {
        let vm = MemoryGridViewModel()
        vm.startGame(size: .small4x4)
        vm.resetGame()
        #expect(vm.tiles.isEmpty)
        #expect(!vm.isGameActive)
        #expect(vm.matchedPairs == 0)
    }
}

@MainActor
struct TapInOrderViewModelTests {
    @Test func startsInPreviewPhase() async throws {
        let vm = TapInOrderViewModel()
        vm.start(variant: .numberMemory, gridSize: 4, tileCount: 6, seed: 42)
        #expect(vm.phase == .preview)
        #expect(vm.selectedCells.count == 6)
        #expect(vm.numberForCell.count == 6)
        #expect(vm.correctCount == 0)
        vm.cleanup()
    }

    @Test func patternMemoryHasNoNumberMapping() async throws {
        let vm = TapInOrderViewModel()
        vm.start(variant: .patternMemory, gridSize: 4, tileCount: 5, seed: 1)
        #expect(vm.numberForCell.isEmpty)
        #expect(vm.selectedCells.count == 5)
        vm.cleanup()
    }

    @Test func resetClearsState() async throws {
        let vm = TapInOrderViewModel()
        vm.start(variant: .numberMemory, gridSize: 4, tileCount: 6, seed: 7)
        vm.reset()
        #expect(vm.selectedCells.isEmpty)
        #expect(vm.correctCount == 0)
        #expect(vm.missTaps == 0)
        #expect(vm.elapsedSeconds == 0)
    }

    @Test func giveUpCompletesWithoutWin() async throws {
        let vm = TapInOrderViewModel()
        vm.start(variant: .numberMemory, gridSize: 4, tileCount: 6, seed: 3)
        vm.giveUp()
        #expect(vm.phase == .complete)
        #expect(vm.didWin == false)
        vm.cleanup()
    }
}

struct InviteURLMatchingTests {
    private func extract(_ s: String) -> String? {
        guard let url = URL(string: s) else { return nil }
        let host = url.host?.lowercased() ?? ""
        let scheme = url.scheme?.lowercased() ?? ""
        let path = url.path.lowercased()
        let isHTTPInvite = (scheme == "https" || scheme == "http")
            && AppConstants.Invite.allowedHosts.contains(host)
            && path.hasPrefix("/invite")
        let isCustomScheme = scheme == AppConstants.Invite.inviteScheme
        guard isHTTPInvite || isCustomScheme else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name.lowercased() == "code" })?.value
    }

    @Test func acceptsValidHost() {
        #expect(extract("https://www.8partyplay.com/invite?code=ABC123") == "ABC123")
    }

    @Test func acceptsCustomScheme() {
        #expect(extract("invite://redeem?code=XYZ789") == "XYZ789")
    }

    @Test func rejectsPhishingHost() {
        #expect(extract("https://8partyplay.evil.com/invite?code=BAD") == nil)
        #expect(extract("https://8partyplayfake.com/invite?code=BAD") == nil)
    }

    @Test func rejectsWrongPath() {
        #expect(extract("https://www.8partyplay.com/notinvite?code=X") == nil)
    }
}
