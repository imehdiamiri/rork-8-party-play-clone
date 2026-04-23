import Foundation

/// Stable per-install device identifier for telemetry.
/// Persists in UserDefaults; resets only if the app is uninstalled.
nonisolated enum DeviceIdentity {
    private static let key: String = "mp.device_id.v1"

    static var deviceID: String {
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }

    static var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(short)(\(build))"
    }

    static let platform: String = "iOS"
}
