import SwiftUI
import RevenueCat

struct PaywallView: View {
    var store: StoreViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPackage: Package?
    @State private var tab: PaywallTab = .subscription

    enum PaywallTab: String, CaseIterable, Identifiable {
        case subscription = "Premium"
        case stars = "Star Packs"
        case support = "Support"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                Group {
                    if store.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 22) {
                                heroSection
                                Picker("Section", selection: $tab) {
                                    ForEach(PaywallTab.allCases) { t in Text(t.rawValue).tag(t) }
                                }
                                .pickerStyle(.segmented)

                                switch tab {
                                case .subscription:
                                    subscriptionSection
                                case .stars:
                                    starsSection
                                case .support:
                                    supportSection
                                }

                                restoreButton
                                legalText
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 32)
                        }
                    }
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
            .onChange(of: store.isPremium) { _, isPremium in
                if isPremium && tab == .subscription { dismiss() }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.orange.opacity(0.4), .orange.opacity(0.08), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 55
                        )
                    )
                    .frame(width: 110, height: 110)
                Image(systemName: store.isPremium ? "crown.fill" : "sparkles")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: .orange.opacity(0.5), radius: 12, y: 4)
            }
            Text(store.isPremium ? "You're a Premium Member" : "Unlock All Premium Games")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            if !store.isPremium {
                Text("Plus cheap AI cards (1 ★ instead of 5) and all games unlocked")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        VStack(spacing: 16) {
            featuresBlock

            let subs = store.subscriptionPackages()
            if !subs.isEmpty {
                VStack(spacing: 10) {
                    ForEach(subs, id: \.identifier) { package in
                        planRow(package: package)
                    }
                }
            }

            if let lifetime = store.lifetimePackage() {
                lifetimeRow(package: lifetime)
            }

            Button {
                guard let pkg = selectedPackage ?? store.subscriptionPackages().first(where: { SubscriptionTier.detect(from: $0.storeProduct.productIdentifier) == .yearly }) ?? store.subscriptionPackages().first else { return }
                Task { await store.purchase(package: pkg) }
            } label: {
                HStack(spacing: 8) {
                    if store.isPurchasing {
                        ProgressView().tint(.white)
                    }
                    Text(ctaLabel)
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [.orange, .orange.opacity(0.8)], startPoint: .leading, endPoint: .trailing),
                    in: .rect(cornerRadius: 16)
                )
            }
            .buttonStyle(.plain)
            .disabled(store.isPurchasing || selectedPackage == nil)
            .opacity(selectedPackage == nil ? 0.6 : 1)
        }
        .onAppear {
            if selectedPackage == nil {
                selectedPackage = store.subscriptionPackages().first(where: { SubscriptionTier.detect(from: $0.storeProduct.productIdentifier) == .yearly })
                    ?? store.subscriptionPackages().first
                    ?? store.lifetimePackage()
            }
        }
    }

    private var ctaLabel: String {
        guard let pkg = selectedPackage else { return "Continue" }
        let tier = SubscriptionTier.detect(from: pkg.storeProduct.productIdentifier)
        switch tier {
        case .lifetime: return "Get Lifetime Access"
        default: return "Start \(tier.displayName)"
        }
    }

    private var featuresBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            featureRow(icon: "gamecontroller.fill", tint: .blue, text: "All 4 Premium games unlocked")
            featureRow(icon: "star.fill", tint: .orange, text: "Star bonus each billing period")
            featureRow(icon: "sparkles", tint: .yellow, text: "AI cards at 1 ★ (instead of 5)")
            featureRow(icon: "sparkles", tint: .purple, text: "Support ongoing development")
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.72), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.06))
        }
    }

    private func featureRow(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.14), in: .rect(cornerRadius: 10))
            Text(text).font(.subheadline.weight(.medium))
            Spacer(minLength: 0)
        }
    }

    private func planRow(package: Package) -> some View {
        let tier = SubscriptionTier.detect(from: package.storeProduct.productIdentifier)
        let isSelected = selectedPackage?.identifier == package.identifier
        let isBest = tier == .yearly

        return Button {
            withAnimation(.spring(duration: 0.25)) {
                selectedPackage = package
            }
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(tier.displayName)
                            .font(.headline.weight(.bold))
                        if isBest {
                            Text("BEST VALUE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green, in: .capsule)
                        }
                    }
                    Text("+\(tier.starsPerPeriod) Stars per period")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(package.storeProduct.localizedPriceString)
                    .font(.title3.weight(.bold))
            }
            .padding(16)
            .background(
                isSelected ? AnyShapeStyle(.orange.opacity(0.22)) : AnyShapeStyle(.white.opacity(0.05)),
                in: .rect(cornerRadius: 18)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        isSelected ? .orange.opacity(0.6) : (isBest ? .green.opacity(0.5) : .white.opacity(0.08)),
                        lineWidth: isSelected ? 2 : (isBest ? 1.5 : 1)
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func lifetimeRow(package: Package) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier
        return Button {
            withAnimation(.spring(duration: 0.25)) {
                selectedPackage = package
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "infinity.circle.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.pink)
                    .frame(width: 44, height: 44)
                    .background(.pink.opacity(0.14), in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Lifetime")
                        .font(.headline.weight(.bold))
                    Text("One-time purchase \u{2022} Forever access")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(package.storeProduct.localizedPriceString)
                    .font(.title3.weight(.bold))
            }
            .padding(16)
            .background(
                isSelected ? AnyShapeStyle(.pink.opacity(0.22)) : AnyShapeStyle(.white.opacity(0.05)),
                in: .rect(cornerRadius: 18)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isSelected ? .pink.opacity(0.6) : .white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stars

    private var starsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Star Packs")
                    .font(.title3.weight(.bold))
                Text("Stars power AI card generation. Subscribers spend just 1 ★ per card.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            let packs = store.starPackPackages()
            if packs.isEmpty {
                Text("Star packs are being loaded...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(packs, id: \.identifier) { package in
                        starPackRow(package: package)
                    }
                }
            }
        }
    }

    private func starPackRow(package: Package) -> some View {
        Button {
            Task { await store.purchase(package: package) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "star.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.orange)
                    .frame(width: 44, height: 44)
                    .background(.orange.opacity(0.14), in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(package.storeProduct.localizedTitle)
                        .font(.headline.weight(.semibold))
                    Text("One-time purchase")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(package.storeProduct.localizedPriceString)
                    .font(.headline.weight(.bold))
            }
            .padding(14)
            .background(.white.opacity(0.05), in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)) }
        }
        .buttonStyle(.plain)
        .disabled(store.isPurchasing)
    }

    // MARK: - Support / Donations

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Support Development")
                    .font(.title3.weight(.bold))
                Text("Love the game? Leave a tip to help us keep building.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            let donations = store.donationPackages()
            if donations.isEmpty {
                Text("Donation tiers are being loaded...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(donations, id: \.identifier) { package in
                        donationRow(package: package)
                    }
                }
            }
        }
    }

    private func donationRow(package: Package) -> some View {
        Button {
            Task { await store.purchase(package: package) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "heart.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.pink)
                    .frame(width: 44, height: 44)
                    .background(.pink.opacity(0.14), in: .rect(cornerRadius: 12))
                Text(package.storeProduct.localizedTitle)
                    .font(.headline.weight(.semibold))
                Spacer()
                Text(package.storeProduct.localizedPriceString)
                    .font(.headline.weight(.bold))
            }
            .padding(14)
            .background(.white.opacity(0.05), in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)) }
        }
        .buttonStyle(.plain)
        .disabled(store.isPurchasing)
    }

    // MARK: - Footer

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task { await store.restore() }
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(.secondary)
    }

    private var legalText: some View {
        VStack(spacing: 10) {
            Text("Subscriptions auto-renew unless cancelled 24h before period end. Payment is charged to your Apple ID. Stars remain in your wallet after subscription ends.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                Link("Privacy Policy", destination: LegalLinks.privacyPolicyURL)
                Text("•").foregroundStyle(.tertiary)
                Link("Terms of Service", destination: LegalLinks.termsOfServiceURL)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }
}
