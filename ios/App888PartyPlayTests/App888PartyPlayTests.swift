import Testing
import Foundation
@testable import App888PartyPlay

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

struct MultiplayerTimerTests {
    @Test func startProducesRunningSnapshot() {
        let now = Date(timeIntervalSince1970: 1000)
        let s = MultiplayerTimerSnapshot.start(duration: 30, now: now)
        #expect(!s.isPaused)
        #expect(s.durationSeconds == 30)
        #expect(s.remaining(now: now) == 30)
        #expect(s.remaining(now: now.addingTimeInterval(10)) == 20)
    }

    @Test func pauseFreezesRemaining() {
        let now = Date(timeIntervalSince1970: 2000)
        let s = MultiplayerTimerSnapshot.start(duration: 60, now: now)
        let at15 = now.addingTimeInterval(15)
        let paused = s.paused(now: at15)
        #expect(paused.isPaused)
        #expect(paused.pausedRemaining == 45)
        // Time passes while paused — remaining unchanged.
        #expect(paused.remaining(now: at15.addingTimeInterval(120)) == 45)
    }

    @Test func resumeRestartsCountdown() {
        let now = Date(timeIntervalSince1970: 3000)
        let s = MultiplayerTimerSnapshot.start(duration: 60, now: now).paused(now: now.addingTimeInterval(10))
        let resumedAt = now.addingTimeInterval(300)
        let resumed = s.resumed(now: resumedAt)
        #expect(!resumed.isPaused)
        #expect(resumed.remaining(now: resumedAt) == 50)
        #expect(resumed.remaining(now: resumedAt.addingTimeInterval(20)) == 30)
    }

    @Test func revisionIncrementsOnPauseAndResume() {
        let s0 = MultiplayerTimerSnapshot.start(duration: 10)
        let s1 = s0.paused()
        let s2 = s1.resumed()
        #expect(s1.revision == s0.revision + 1)
        #expect(s2.revision == s1.revision + 1)
    }
}

struct HostInactivityPolicyTests {
    private let base = Date(timeIntervalSince1970: 10_000)

    @Test func shortBackgroundIsHealthy() {
        let policy = HostInactivityPolicy.default
        let r = policy.evaluate(lastSeen: base, now: base.addingTimeInterval(5), phase: .inProgress)
        #expect(r == .healthy)
    }

    @Test func thirtySecondsIsSoftDegraded() {
        let policy = HostInactivityPolicy.default
        let r = policy.evaluate(lastSeen: base, now: base.addingTimeInterval(30), phase: .inProgress)
        #expect(r == .softDegraded)
    }

    @Test func twoMinutesPromotesInGame() {
        let policy = HostInactivityPolicy.default
        let r = policy.evaluate(lastSeen: base, now: base.addingTimeInterval(130), phase: .inProgress)
        #expect(r == .promoteNewHost)
    }

    @Test func twoMinutesInEmptyLobbyCloses() {
        let policy = HostInactivityPolicy.default
        let r = policy.evaluate(lastSeen: base, now: base.addingTimeInterval(130), phase: .lobby)
        #expect(r == .closeRoom)
    }

    @Test func killedAppEventuallyCloses() {
        let policy = HostInactivityPolicy.default
        let r = policy.evaluate(lastSeen: base, now: base.addingTimeInterval(900), phase: .inProgress)
        #expect(r == .closeRoom)
    }
}

@MainActor
struct MultiplayerTimerCoordinatorTests {
    @Test func hostStartSetsDisplay() {
        let t = MultiplayerTimerCoordinator()
        t.hostStart(duration: 20)
        #expect(t.snapshot != nil)
        #expect(t.displayRemaining == 20)
    }

    @Test func adoptAdvancesRevisionOnly() {
        let t = MultiplayerTimerCoordinator()
        let snap = MultiplayerTimerSnapshot.start(duration: 45)
        t.adopt(snap)
        #expect(t.snapshot?.revision == snap.revision)
        // Older revision should not replace.
        var older = snap
        older.revision = -1
        t.adopt(older)
        #expect(t.snapshot?.revision == snap.revision)
    }

    @Test func stopClearsSnapshot() {
        let t = MultiplayerTimerCoordinator()
        t.hostStart(duration: 10)
        t.stop()
        #expect(t.snapshot == nil)
        #expect(t.displayRemaining == 0)
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
        #expect(extract("https://www.888partyplay.com/invite?code=ABC123") == "ABC123")
    }

    @Test func acceptsCustomScheme() {
        #expect(extract("invite://redeem?code=XYZ789") == "XYZ789")
    }

    @Test func rejectsPhishingHost() {
        #expect(extract("https://888play.evil.com/invite?code=BAD") == nil)
        #expect(extract("https://888playfake.com/invite?code=BAD") == nil)
    }

    @Test func rejectsWrongPath() {
        #expect(extract("https://www.888partyplay.com/notinvite?code=X") == nil)
    }
}
