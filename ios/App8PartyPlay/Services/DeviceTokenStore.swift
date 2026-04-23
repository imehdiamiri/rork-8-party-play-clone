import Foundation

@MainActor
final class DeviceTokenStore {
    static let shared = DeviceTokenStore()
    var latestToken: String?
    private init() {}
}
