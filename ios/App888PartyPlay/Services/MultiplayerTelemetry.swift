import Foundation
import Supabase
import UIKit

// MARK: - Wire payload

nonisolated struct MPEventRecord: Codable, Sendable {
    let event: String
    let session_id: String?
    let room_id: String?
    let match_id: String?
    let player_id: String?
    let device_id: String?
    let user_role: String?
    let game_type: String?
    let app_version: String?
    let platform: String?
    let room_status: String?
    let session_phase: String?
    let state_version: Int?
    let active_player_id: String?
    let active_turn_index: Int?
    let player_count: Int?
    let source: String?
    let network_state: String?
    let success: Bool?
    let failure_reason: String?
    let latency_ms: Int?
    let session_duration_ms: Int64?
    let turn_duration_ms: Int64?
    let turn_rpc_latency_ms: Int?
    let phase_at_exit: String?
    let session_outcome: String?
    let session_token_hash: String?
    let props: [String: String]
    let created_at: String
}

// MARK: - Session outcome

nonisolated enum MPSessionOutcome: String, Sendable {
    case completed_normally
    case closed_by_host
    case abandoned_by_players
    case failed_to_start
    case sync_failure
    case reconnect_failure
    case results_delivery_failure
    case rematch_abandoned
    case kicked_player_exit
    case unknown_failure
}

// MARK: - Context

nonisolated struct MPContext: Sendable {
    var session_id: String?
    var room_id: String?
    var match_id: String?
    var player_id: String?
    var user_role: String?
    var game_type: String?
    var room_status: String?
    var session_phase: String?
    var state_version: Int?
    var active_player_id: String?
    var active_turn_index: Int?
    var player_count: Int?
    var session_token_hash: String?
}

// MARK: - Service

@MainActor
final class MultiplayerTelemetry {
    static let shared = MultiplayerTelemetry()

    private let supabase: SupabaseService
    private var buffer: [MPEventRecord] = []
    private var flushTask: Task<Void, Never>?
    private var bgObserver: NSObjectProtocol?

    private var context = MPContext()
    private var sessionStartAt: Date?
    private var turnStartAt: Date?

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init(supabase: SupabaseService = .shared) {
        self.supabase = supabase
        start()
    }

    // MARK: Lifecycle

    private func start() {
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                await self?.flush()
            }
        }
        bgObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await MultiplayerTelemetry.shared.flush()
            }
        }
    }

    // MARK: Public API

    func setContext(
        session_id: String? = nil,
        room_id: String? = nil,
        match_id: String? = nil,
        player_id: String? = nil,
        user_role: String? = nil,
        game_type: String? = nil,
        room_status: String? = nil,
        session_phase: String? = nil,
        state_version: Int? = nil,
        active_player_id: String? = nil,
        active_turn_index: Int? = nil,
        player_count: Int? = nil,
        session_token_hash: String? = nil
    ) {
        if let v = session_id { context.session_id = v }
        if let v = room_id { context.room_id = v }
        if let v = match_id { context.match_id = v }
        if let v = player_id { context.player_id = v }
        if let v = user_role { context.user_role = v }
        if let v = game_type { context.game_type = v }
        if let v = room_status { context.room_status = v }
        if let v = session_phase { context.session_phase = v }
        if let v = state_version { context.state_version = v }
        if let v = active_player_id { context.active_player_id = v }
        if let v = active_turn_index { context.active_turn_index = v }
        if let v = player_count { context.player_count = v }
        if let v = session_token_hash { context.session_token_hash = v }
    }

    func clearContext() {
        context = MPContext()
        sessionStartAt = nil
        turnStartAt = nil
    }

    /// Call when a new multiplayer session begins (match_start_succeeded or similar).
    func markSessionStarted() {
        sessionStartAt = Date()
    }

    /// Call when a player's own turn begins (turn_start_confirmed / turn_active).
    func markTurnStarted() {
        turnStartAt = Date()
    }

    /// Classify and emit session_ended. Resets session clock.
    func classify(outcome: MPSessionOutcome, phaseAtExit: String? = nil, extra: [String: String] = [:]) {
        var props = extra
        if let phase = phaseAtExit { props["phase_at_exit"] = phase }
        log(
            event: "session_ended",
            session_duration_ms: elapsedSessionMs(),
            phase_at_exit: phaseAtExit,
            session_outcome: outcome.rawValue,
            props: props
        )
        sessionStartAt = nil
        turnStartAt = nil
    }

    func log(
        event: String,
        source: String? = nil,
        success: Bool? = nil,
        failure_reason: String? = nil,
        latency_ms: Int? = nil,
        turn_rpc_latency_ms: Int? = nil,
        turn_duration_ms: Int64? = nil,
        session_duration_ms: Int64? = nil,
        phase_at_exit: String? = nil,
        session_outcome: String? = nil,
        props: [String: String] = [:]
    ) {
        let record = MPEventRecord(
            event: event,
            session_id: context.session_id,
            room_id: context.room_id,
            match_id: context.match_id,
            player_id: context.player_id,
            device_id: DeviceIdentity.deviceID,
            user_role: context.user_role,
            game_type: context.game_type,
            app_version: DeviceIdentity.appVersion,
            platform: DeviceIdentity.platform,
            room_status: context.room_status,
            session_phase: context.session_phase,
            state_version: context.state_version,
            active_player_id: context.active_player_id,
            active_turn_index: context.active_turn_index,
            player_count: context.player_count,
            source: source,
            network_state: nil,
            success: success,
            failure_reason: failure_reason,
            latency_ms: latency_ms,
            session_duration_ms: session_duration_ms,
            turn_duration_ms: turn_duration_ms,
            turn_rpc_latency_ms: turn_rpc_latency_ms,
            phase_at_exit: phase_at_exit,
            session_outcome: session_outcome,
            session_token_hash: context.session_token_hash,
            props: props,
            created_at: isoFormatter.string(from: Date())
        )
        buffer.append(record)
        if buffer.count >= 40 {
            Task { await self.flush() }
        }
    }

    // MARK: Helpers

    func elapsedTurnMs() -> Int64? {
        guard let start = turnStartAt else { return nil }
        return Int64(Date().timeIntervalSince(start) * 1000)
    }

    func elapsedSessionMs() -> Int64? {
        guard let start = sessionStartAt else { return nil }
        return Int64(Date().timeIntervalSince(start) * 1000)
    }

    /// Safe token identifier (first 8 chars of stable hash-ish representation).
    static func safeTokenHash(_ token: String?) -> String? {
        guard let token, !token.isEmpty else { return nil }
        var hash: UInt64 = 14695981039346656037
        for byte in token.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(format: "%016llx", hash)
    }

    // MARK: Flush

    func flush() async {
        guard !buffer.isEmpty else { return }
        let batch = buffer
        buffer.removeAll(keepingCapacity: true)
        do {
            _ = try await supabase.client
                .from("mp_events")
                .insert(batch)
                .execute()
        } catch {
            // Drop silently — telemetry must never affect gameplay.
            // We don't requeue to avoid unbounded growth on prolonged outages.
        }
    }
}
