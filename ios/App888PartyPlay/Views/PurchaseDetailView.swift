import SwiftUI
import RevenueCat

nonisolated enum PurchaseSelection: Identifiable, Hashable {
    case subscription(SubscriptionTier)
    case starPack(stars: Int)

    var id: String {
        switch self {
        case .subscription(let tier): return "sub-\(tier.rawValue)"
        case .starPack(let stars): return "pack-\(stars)"
        }
    }
}

struct PurchaseDetailView: View {
    let selection: PurchaseSelection
    var store: StoreViewModel
    @Environment(\.dismiss) private var dismiss

    private var resolvedPackage: Package? {
        switch selection {
        case .subscription(let tier):
            if tier == .lifetime { return store.lifetimePackage() }
            return store.subscriptionPackages().first {
                SubscriptionTier.detect(from: $0.storeProduct.productIdentifier) == tier
            }
        case .starPack(let stars):
            return store.starPackPackages().first {
                $0.storeProduct.productIdentifier.lowercased().contains("\(stars)")
            }
        }
    }

    private var accent: Color {
        switch selection {
        case .subscription(let tier): return tier.accentColor
        case .starPack: return .orange
        }
    }

    private var iconName: String {
        switch selection {
        case .subscription(let tier): return tier.icon
        case .starPack: return "star.fill"
        }
    }

    private var titleText: String {
        switch selection {
        case .subscription(let tier): return tier.displayName
        case .starPack(let stars): return "\(stars) Stars"
        }
    }

    private var subtitleText: String {
        switch selection {
        case .subscription(let tier):
            return tier == .lifetime ? "One-time \u{2022} Forever access" : "Auto-renews every \(tier.displayName.lowercased())"
        case .starPack:
            return "One-time purchase"
        }
    }

    private var priceText: String {
        if let pkg = resolvedPackage { return pkg.storeProduct.localizedPriceString }
        switch selection {
        case .subscription(let tier):
            switch tier {
            case .weekly: return "$4.99"
            case .monthly: return "$6.99"
            case .yearly: return "$29.99"
            case .lifetime: return "$49.99"
            }
        case .starPack(let stars):
            switch stars {
            case 50: return "$0.99"
            case 200: return "$2.99"
            case 400: return "$4.99"
            case 1000: return "$9.99"
            default: return "—"
            }
        }
    }

    private var benefits: [(String, Color, String)] {
        switch selection {
        case .subscription(let tier):
            var items: [(String, Color, String)] = []
            items.append(("star.fill", .orange, "+\(tier.starsPerPeriod) Stars \(tier == .lifetime ? "once" : "per period")"))
            items.append(("gamecontroller.fill", .blue, "All 4 Premium games unlocked"))
            items.append(("sparkles", .yellow, "AI cards cost just 1 Star instead of 5"))
            if tier == .yearly { items.append(("tag.fill", .green, "Best value \u{2014} save vs monthly")) }
            if tier == .lifetime { items.append(("infinity", .pink, "Pay once, keep forever")) }
            items.append(("sparkles", .purple, "Support ongoing development"))
            return items
        case .starPack(let stars):
            var items: [(String, Color, String)] = [
                ("star.fill", .orange, "+\(stars) Stars added to your wallet"),
                ("sparkles", .yellow, "Spend Stars on AI-generated cards"),
                ("bolt.fill", .blue, "Instant delivery after purchase")
            ]
            if let save = savePercent {
                items.append(("tag.fill", .green, "Save \(save)% vs the starter pack"))
            }
            return items
        }
    }

    private var savePercent: Int? {
        switch selection {
        case .starPack(let stars):
            switch stars {
            case 200: return 25
            case 400: return 37
            case 1000: return 50
            default: return nil
            }
        default: return nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                ScrollView {
                    VStack(spacing: 22) {
                        hero
                        benefitsCard
                        buyButton
                        restoreButton
                        legalText
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert("Error", isPresented: .init(
                get: { store.error != nil },
                set: { if !$0 { store.error = nil } }
            )) {
                Button("OK") { store.error = nil }
            } message: {
                Text(store.error ?? "")
            }
            .onChange(of: store.lastPurchaseMessage) { _, new in
                if new != nil { dismiss() }
            }
            .onChange(of: store.isPremium) { _, isPremium in
                if isPremium, case .subscription = selection { dismiss() }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [accent.opacity(0.45), accent.opacity(0.08), .clear], center: .center, startRadius: 10, endRadius: 60))
                    .frame(width: 120, height: 120)
                Image(systemName: iconName)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: accent.opacity(0.5), radius: 12, y: 4)
            }
            Text(titleText)
                .font(.largeTitle.weight(.bold))
            Text(subtitleText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Text(priceText)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                if case .subscription(let tier) = selection, tier != .lifetime {
                    Text("/ \(tier.displayName.lowercased())")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What you get")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            ForEach(Array(benefits.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 12) {
                    Image(systemName: item.0)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(item.1)
                        .frame(width: 34, height: 34)
                        .background(item.1.opacity(0.16), in: .rect(cornerRadius: 10))
                    Text(item.2)
                        .font(.subheadline.weight(.medium))
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial.opacity(0.72), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.06))
        }
    }

    private var buyButton: some View {
        Button {
            guard let pkg = resolvedPackage else {
                store.error = "This item is not available right now. Please try again later."
                return
            }
            Task { await store.purchase(package: pkg) }
        } label: {
            HStack(spacing: 8) {
                if store.isPurchasing {
                    ProgressView().tint(.white)
                }
                Text(buyLabel)
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [accent, accent.opacity(0.75)], startPoint: .leading, endPoint: .trailing),
                in: .rect(cornerRadius: 16)
            )
            .shadow(color: accent.opacity(0.35), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(store.isPurchasing || resolvedPackage == nil)
        .opacity(resolvedPackage == nil ? 0.55 : 1)
    }

    private var buyLabel: String {
        switch selection {
        case .subscription(let tier):
            return tier == .lifetime ? "Buy Lifetime \u{2014} \(priceText)" : "Subscribe \u{2014} \(priceText)"
        case .starPack:
            return "Buy \u{2014} \(priceText)"
        }
    }

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task { await store.restore() }
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(.secondary)
    }

    private var legalText: some View {
        VStack(spacing: 10) {
            Group {
                if case .subscription(let tier) = selection, tier != .lifetime {
                    Text("Subscriptions auto-renew unless cancelled 24h before period end. Payment is charged to your Apple ID. Stars remain in your wallet after subscription ends.")
                } else {
                    Text("Payment is charged to your Apple ID. Stars are non-refundable and can only be used in this app.")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                Link("Privacy Policy", destination: LegalLinks.privacyPolicyURL)
                Text("\u{2022}").foregroundStyle(.tertiary)
                Link("Terms of Service", destination: LegalLinks.termsOfServiceURL)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }
}
