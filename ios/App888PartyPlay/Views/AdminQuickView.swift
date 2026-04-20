import SwiftUI
import Supabase

struct AdminQuickView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isAdmin: Bool = false
    @State private var loading: Bool = true
    @State private var summary: [String: AnyJSON] = [:]
    @State private var searchQuery: String = ""
    @State private var users: [AdminUserRow] = []
    @State private var error: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !isAdmin {
                    ContentUnavailableView("Admin only",
                        systemImage: "lock.shield",
                        description: Text("Your account is not in the admin allow-list."))
                } else {
                    adminContent
                }
            }
            .navigationTitle("Admin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await checkAdmin() }
    }

    private var adminContent: some View {
        List {
            Section("Overview") {
                statRow("Total users", key: "total_users")
                statRow("New (24h)", key: "new_users_24h")
                statRow("DAU", key: "dau")
                statRow("Active subs", key: "active_subscriptions")
                statRow("AI calls 24h", key: "ai_calls_24h")
                statRow("Stars circulating", key: "total_stars_circulating")
            }
            Section("Find user") {
                TextField("username, email, id", text: $searchQuery)
                    .textInputAutocapitalization(.never)
                    .onSubmit { Task { await search() } }
                Button("Search") { Task { await search() } }
                ForEach(users) { u in
                    NavigationLink(value: u.id) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(u.username).font(.body.weight(.semibold))
                                Text("#\(u.publicID)").foregroundStyle(.secondary).font(.caption)
                                Spacer()
                                if u.isSubscribed { Text("SUB").font(.caption2.weight(.bold)).foregroundStyle(.green) }
                                if u.isBanned { Text("BANNED").font(.caption2.weight(.bold)).foregroundStyle(.red) }
                            }
                            Text(u.email ?? "—").font(.caption).foregroundStyle(.secondary)
                            Text("\(u.starsBalance) ⭐").font(.caption)
                        }
                    }
                }
            }
            if let error {
                Section { Text(error).foregroundStyle(.red) }
            }
            Section {
                Link("Open full admin dashboard →",
                     destination: AppConstants.URLs.adminDashboard)
            }
        }
        .navigationDestination(for: String.self) { id in
            AdminUserDetailView(userId: id, initialRow: users.first(where: { $0.id == id }))
        }
    }

    @ViewBuilder
    private func statRow(_ label: String, key: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(valueString(summary[key])).font(.body.weight(.semibold))
        }
    }

    private static let cachedAdminKey: String = "cachedIsAdmin"

    private func valueString(_ v: AnyJSON?) -> String {
        switch v {
        case .integer(let n): return "\(n)"
        case .double(let n): return "\(n)"
        case .string(let s): return s
        default: return "—"
        }
    }

    private func checkAdmin() async {
        let cached = UserDefaults.standard.bool(forKey: Self.cachedAdminKey)
        if cached {
            isAdmin = true
            loading = false
            await loadSummary()
        } else {
            loading = true
        }
        do {
            let res: Bool = try await SupabaseService.shared.client
                .rpc("current_user_is_admin").execute().value
            isAdmin = res
            UserDefaults.standard.set(res, forKey: Self.cachedAdminKey)
            if res && summary.isEmpty { await loadSummary() }
        } catch {
            if !cached { isAdmin = false }
        }
        loading = false
    }

    private func loadSummary() async {
        do {
            let dict: [String: AnyJSON] = try await SupabaseService.shared.client
                .rpc("admin_analytics_summary").execute().value
            summary = dict
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func search() async {
        do {
            let params: [String: AnyJSON] = [
                "p_query": .string(searchQuery),
                "p_limit": .integer(40),
                "p_offset": .integer(0)
            ]
            let rows: [AdminUserRow] = try await SupabaseService.shared.client
                .rpc("admin_search_users", params: params)
                .execute().value
            users = rows
        } catch {
            self.error = error.localizedDescription
        }
    }
}

nonisolated struct AdminUserRow: Codable, Identifiable, Sendable {
    let id: String
    let username: String
    let email: String?
    let publicID: Int
    let starsBalance: Int
    let isSubscribed: Bool
    let isBanned: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case publicID = "public_id"
        case starsBalance = "stars_balance"
        case isSubscribed = "is_subscribed"
        case isBanned = "is_banned"
    }
}

struct AdminUserDetailView: View {
    let userId: String
    let initialRow: AdminUserRow?
    @State private var delta: String = "50"
    @State private var reason: String = "Admin grant"
    @State private var status: String? = nil
    @State private var busy: Bool = false
    @State private var detail: AdminUserRow?
    @State private var loadingDetail: Bool = false

    init(userId: String, initialRow: AdminUserRow? = nil) {
        self.userId = userId
        self.initialRow = initialRow
        self._detail = State(initialValue: initialRow)
    }

    var body: some View {
        Form {
            Section("User") {
                if let d = detail {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(d.username).font(.headline)
                            Text("#\(d.publicID)").foregroundStyle(.secondary).font(.caption)
                            Spacer()
                            if d.isSubscribed { Text("SUB").font(.caption2.weight(.bold)).foregroundStyle(.green) }
                            if d.isBanned { Text("BANNED").font(.caption2.weight(.bold)).foregroundStyle(.red) }
                        }
                        Text(d.email ?? "—").font(.caption).foregroundStyle(.secondary)
                        Text("\(d.starsBalance) ⭐").font(.caption)
                    }
                } else if loadingDetail {
                    ProgressView()
                }
                Text(userId).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            Section("Stars") {
                TextField("Amount", text: $delta).keyboardType(.numberPad)
                TextField("Reason", text: $reason)
                HStack {
                    Button("Grant", systemImage: "plus.circle.fill") { Task { await adjust(sign: 1) } }
                        .buttonStyle(.borderedProminent)
                    Button("Deduct", systemImage: "minus.circle.fill") { Task { await adjust(sign: -1) } }
                        .buttonStyle(.bordered).tint(.red)
                }
            }
            Section("Subscription") {
                Button("Grant 30-day premium") { Task { await grantSub(true) } }
                Button("Revoke subscription", role: .destructive) { Task { await grantSub(false) } }
            }
            Section("Ban") {
                Button("Ban user", role: .destructive) { Task { await ban(true) } }
                Button("Unban user") { Task { await ban(false) } }
            }
            if let status {
                Section { Text(status).foregroundStyle(.secondary).font(.caption) }
            }
        }
        .disabled(busy)
        .navigationTitle("User actions")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDetail() }
    }

    private func loadDetail() async {
        guard detail == nil else { return }
        loadingDetail = true
        defer { loadingDetail = false }
        let params: [String: AnyJSON] = [
            "p_query": .string(userId),
            "p_limit": .integer(1),
            "p_offset": .integer(0)
        ]
        do {
            let rows: [AdminUserRow] = try await SupabaseService.shared.client
                .rpc("admin_search_users", params: params)
                .execute().value
            detail = rows.first
        } catch {
            status = "❌ \(error.localizedDescription)"
        }
    }

    private func adjust(sign: Int) async {
        guard let n = Int(delta) else { return }
        await run("admin_adjust_stars", params: [
            "p_user_id": AnyJSON.string(userId),
            "p_delta": AnyJSON.integer(sign * abs(n)),
            "p_reason": AnyJSON.string(reason)
        ])
    }

    private func grantSub(_ active: Bool) async {
        await run("admin_set_subscription", params: [
            "p_user_id": AnyJSON.string(userId),
            "p_active": AnyJSON.bool(active)
        ])
    }

    private func ban(_ banned: Bool) async {
        await run("admin_set_ban", params: [
            "p_user_id": AnyJSON.string(userId),
            "p_banned": AnyJSON.bool(banned),
            "p_reason": AnyJSON.string(banned ? "Admin ban" : "")
        ])
    }

    private func run(_ rpc: String, params: [String: AnyJSON]) async {
        busy = true
        defer { busy = false }
        do {
            try await SupabaseService.shared.client.rpc(rpc, params: params).execute()
            status = "✅ \(rpc) done"
            await loadDetailRefresh()
        } catch {
            status = "❌ \(error.localizedDescription)"
        }
    }

    private func loadDetailRefresh() async {
        let params: [String: AnyJSON] = [
            "p_query": .string(userId),
            "p_limit": .integer(1),
            "p_offset": .integer(0)
        ]
        if let rows: [AdminUserRow] = try? await SupabaseService.shared.client
            .rpc("admin_search_users", params: params)
            .execute().value {
            detail = rows.first
        }
    }
}
