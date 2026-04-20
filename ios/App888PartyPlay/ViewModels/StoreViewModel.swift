import Foundation
import Observation
import RevenueCat

@Observable
@MainActor
class StoreViewModel {
    var offerings: Offerings?
    var isPremium: Bool = false
    var isLifetime: Bool = false
    var currentTier: SubscriptionTier?
    var isLoading: Bool = false
    var isPurchasing: Bool = false
    var error: String?
    var didJustSubscribe: Bool = false
    var lastPurchaseMessage: String?

    var onStarsGranted: ((Int, String, String, Date?) -> Void)?
    var onStarPackPurchased: ((Int, String) -> Void)?

    func start() {
        Task { await listenForUpdates() }
        Task { await fetchOfferings() }
    }

    private func listenForUpdates() async {
        for await info in Purchases.shared.customerInfoStream {
            applyCustomerInfo(info)
        }
    }

    func fetchOfferings() async {
        isLoading = true
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func purchase(package: Package) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                applyCustomerInfo(result.customerInfo)
                let productId = package.storeProduct.productIdentifier
                if isStarPack(productId) {
                    let stars = starsFor(productId: productId)
                    if stars > 0 {
                        onStarPackPurchased?(stars, productId)
                        lastPurchaseMessage = "+\(stars) Stars added"
                    }
                } else if isDonation(productId) {
                    lastPurchaseMessage = "Thanks for your support!"
                } else if isPremium {
                    didJustSubscribe = true
                }
            }
        } catch ErrorCode.purchaseCancelledError {
        } catch ErrorCode.paymentPendingError {
        } catch {
            self.error = error.localizedDescription
        }
    }

    func restore() async {
        do {
            let info = try await Purchases.shared.restorePurchases()
            applyCustomerInfo(info)
            if isPremium { didJustSubscribe = true }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func applyCustomerInfo(_ info: CustomerInfo) {
        let premium = info.entitlements["premium"]?.isActive == true
        let lifetime = info.entitlements["lifetime"]?.isActive == true || info.nonSubscriptions.contains { $0.productIdentifier.lowercased().contains("lifetime") }
        isPremium = premium || lifetime
        isLifetime = lifetime
        if let entitlement = info.entitlements["premium"], entitlement.isActive {
            currentTier = SubscriptionTier.detect(from: entitlement.productIdentifier)
            triggerStarGrant(productId: entitlement.productIdentifier, expiration: entitlement.expirationDate)
        } else if lifetime {
            currentTier = .lifetime
            let lifetimeProduct = info.nonSubscriptions.first(where: { $0.productIdentifier.lowercased().contains("lifetime") })?.productIdentifier ?? "lifetime"
            triggerStarGrant(productId: lifetimeProduct, expiration: nil)
        }
    }

    private func triggerStarGrant(productId: String, expiration: Date?) {
        let tier = SubscriptionTier.detect(from: productId)
        let amount = tier.starsPerPeriod
        let periodKey: String
        if let expiration {
            periodKey = "\(productId):\(Int(expiration.timeIntervalSince1970))"
        } else {
            periodKey = "\(productId):lifetime"
        }
        onStarsGranted?(amount, tier.rawValue, periodKey, expiration)
    }

    private func isStarPack(_ id: String) -> Bool {
        let lower = id.lowercased()
        return lower.contains("stars_") || lower.contains("starpack") || lower.contains("_stars")
    }

    private func isDonation(_ id: String) -> Bool {
        id.lowercased().contains("donation") || id.lowercased().contains("tip")
    }

    private func starsFor(productId: String) -> Int {
        let lower = productId.lowercased()
        if lower.contains("1000") { return 1000 }
        if lower.contains("400") { return 400 }
        if lower.contains("200") { return 200 }
        if lower.contains("50") { return 50 }
        return 0
    }

    func checkStatus() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            applyCustomerInfo(info)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Offering helpers

    func subscriptionPackages() -> [Package] {
        guard let packages = offerings?.current?.availablePackages else { return [] }
        return packages.filter { pkg in
            let id = pkg.storeProduct.productIdentifier.lowercased()
            return !id.contains("lifetime") && !isStarPack(id) && !isDonation(id) && pkg.storeProduct.subscriptionPeriod != nil
        }
    }

    func lifetimePackage() -> Package? {
        offerings?.current?.availablePackages.first { $0.storeProduct.productIdentifier.lowercased().contains("lifetime") }
    }

    func starPackPackages() -> [Package] {
        guard let packages = offerings?.current?.availablePackages else { return [] }
        return packages.filter { isStarPack($0.storeProduct.productIdentifier) }
            .sorted { $0.storeProduct.price < $1.storeProduct.price }
    }

    func donationPackages() -> [Package] {
        guard let packages = offerings?.current?.availablePackages else { return [] }
        return packages.filter { isDonation($0.storeProduct.productIdentifier) }
            .sorted { $0.storeProduct.price < $1.storeProduct.price }
    }
}
