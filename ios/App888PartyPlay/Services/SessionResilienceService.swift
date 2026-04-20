import Foundation
import Supabase

@MainActor
final class SessionResilienceService {
    private let supabase: SupabaseService
    private let databaseService: SupabaseDatabaseService
    private var connectionMonitorTask: Task<Void, Never>?
    private var reconnectRetryCount: Int = 0
    private let maxReconnectRetries: Int = 5

    private(set) var connectionState: ConnectionState = .connected
    private(set) var lastSyncError: String?

    var onConnectionStateChanged: ((ConnectionState) -> Void)?
    var onSessionRestored: ((GameSessionRecord) -> Void)?
    var onHostDisconnected: (() -> Void)?
    var onSyncError: ((String) -> Void)?

    nonisolated enum ConnectionState: String, Sendable {
        case connected
        case reconnecting
        case disconnected
    }

    init(supabase: SupabaseService = .shared, databaseService: SupabaseDatabaseService = SupabaseDatabaseService()) {
        self.supabase = supabase
        self.databaseService = databaseService
    }

    func storeActiveSession(sessionID: UUID, roomCode: String?) {
        UserDefaults.standard.set(sessionID.uuidString, forKey: "active_session_id")
        if let roomCode {
            UserDefaults.standard.set(roomCode, forKey: "active_session_room_code")
        }
    }

    func clearActiveSession() {
        UserDefaults.standard.removeObject(forKey: "active_session_id")
        UserDefaults.standard.removeObject(forKey: "active_session_room_code")
    }

    func storedSessionID() -> UUID? {
        guard let str = UserDefaults.standard.string(forKey: "active_session_id") else { return nil }
        return UUID(uuidString: str)
    }

    func storedRoomCode() -> String? {
        UserDefaults.standard.string(forKey: "active_session_room_code")
    }

    func fetchLatestSessionState(sessionID: UUID) async throws -> GameSessionRecord {
        try await databaseService.fetchSession(sessionID: sessionID)
    }

    func checkForActiveSession() async -> GameSessionRecord? {
        guard let sessionID = storedSessionID() else { return nil }
        do {
            let record = try await databaseService.fetchSession(sessionID: sessionID)
            guard record.status == "active" else {
                clearActiveSession()
                return nil
            }
            return record
        } catch {
            clearActiveSession()
            return nil
        }
    }

    func attemptReconnect(roomCode: String, realtimeService: SupabaseRealtimeService, onRoomUpdate: @escaping @MainActor (String) -> Void, onSessionUpdate: @escaping @MainActor (GameSessionRecord) -> Void) async {
        guard reconnectRetryCount < maxReconnectRetries else {
            updateConnectionState(.disconnected)
            onSyncError?("Unable to reconnect after multiple attempts.")
            return
        }

        updateConnectionState(.reconnecting)
        reconnectRetryCount += 1

        let delay = min(pow(2.0, Double(reconnectRetryCount)), 16.0)
        try? await Task.sleep(for: .seconds(delay))

        realtimeService.subscribeToRoom(code: roomCode, onRoomUpdate: onRoomUpdate, onSessionUpdate: onSessionUpdate)

        if let sessionID = storedSessionID() {
            do {
                let record = try await fetchLatestSessionState(sessionID: sessionID)
                onSessionUpdate(record)
                updateConnectionState(.connected)
                reconnectRetryCount = 0
                lastSyncError = nil
            } catch {
                onSyncError?("Failed to sync session: \(error.localizedDescription)")
                if reconnectRetryCount < maxReconnectRetries {
                    await attemptReconnect(roomCode: roomCode, realtimeService: realtimeService, onRoomUpdate: onRoomUpdate, onSessionUpdate: onSessionUpdate)
                } else {
                    updateConnectionState(.disconnected)
                }
            }
        } else {
            updateConnectionState(.connected)
            reconnectRetryCount = 0
        }
    }

    func resetReconnectCount() {
        reconnectRetryCount = 0
    }

    func detectHostDisconnect(session: GameSessionRecord, currentPlayerID: UUID?) -> Bool {
        guard let state = session.sessionState else { return false }
        let hostPlayer = state.players.first(where: { $0.isHost })
        guard let hostPlayer else { return true }
        if hostPlayer.id == currentPlayerID { return false }
        return !hostPlayer.isOnline
    }

    private func updateConnectionState(_ state: ConnectionState) {
        connectionState = state
        onConnectionStateChanged?(state)
    }
}
