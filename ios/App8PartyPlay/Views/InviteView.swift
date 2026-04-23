import SwiftUI

struct InviteView: View {
    let appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedToast: Bool = false
    @State private var redeemCode: String = ""

    private var code: String { appModel.inviteCode }
    private var shareMessage: String { appModel.inviteShareMessage }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        heroCard
                        shareActions
                        statsCard
                        redeemCard
                        rulesCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay(alignment: .top) {
                if showCopiedToast {
                    Text("Code Copied")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: .capsule)
                        .padding(.top, 8)
                        .transition(.opacity)
                }
            }
        }
    }

    private var heroCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "gift.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.pink)
                        .frame(width: 44, height: 44)
                        .background(.pink.opacity(0.16), in: .rect(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Invite a friend")
                            .font(.headline.weight(.bold))
                        Text("Earn +30 \u{2605} when a new friend joins.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                VStack(spacing: 8) {
                    Text("YOUR CODE")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.secondary)
                    Text(code.isEmpty ? "——————" : code)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .tracking(6)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(.white.opacity(0.06), in: .rect(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08))
                        }
                }
            }
        }
    }

    private var shareActions: some View {
        HStack(spacing: 10) {
            Button {
                UIPasteboard.general.string = code
                withAnimation { showCopiedToast = true }
                Task {
                    try? await Task.sleep(for: .seconds(1.4))
                    withAnimation { showCopiedToast = false }
                }
            } label: {
                actionLabel(title: "Copy Code", systemImage: "doc.on.doc.fill", tint: .blue)
            }
            .buttonStyle(.plain)
            .disabled(code.isEmpty)

            ShareLink(item: shareMessage) {
                actionLabel(title: "Share Link", systemImage: "square.and.arrow.up", tint: .purple)
            }
            .buttonStyle(.plain)
            .disabled(code.isEmpty)
        }
    }

    private func actionLabel(title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
            Text(title)
                .font(.subheadline.weight(.bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(tint, in: .rect(cornerRadius: 14))
    }

    private var statsCard: some View {
        SurfaceCard {
            HStack(spacing: 14) {
                statCell(title: "Friends Joined", value: "\(appModel.inviteTotalCount)", tint: .green, systemImage: "person.2.fill")
                Divider().frame(height: 40).background(.white.opacity(0.08))
                statCell(title: "Stars Earned", value: "\(appModel.inviteStarsEarned)", tint: .orange, systemImage: "star.fill")
            }
        }
    }

    private func statCell(title: String, value: String, tint: Color, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.16), in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.bold))
                    .contentTransition(.numericText())
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var redeemCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Got an invite code?", subtitle: "New accounts can redeem for +10 \u{2605}.")
                HStack(spacing: 10) {
                    TextField("ABC123", text: $redeemCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.headline.monospaced())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.06), in: .rect(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.08))
                        }

                    Button("Redeem") {
                        let trimmed = redeemCode.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        appModel.redeemInviteCode(trimmed)
                        redeemCode = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(appModel.isRedeemingInvite || redeemCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Text("Codes can only be redeemed once, within 7 days of signing up.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var rulesCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeaderView(title: "How it works", subtitle: nil)
                ruleRow(icon: "1.circle.fill", text: "Share your code or link with a friend.")
                ruleRow(icon: "2.circle.fill", text: "They sign up and enter your code.")
                ruleRow(icon: "3.circle.fill", text: "You earn +30 \u{2605}. They get +10 \u{2605}.")
                ruleRow(icon: "lock.shield.fill", text: "Rewards are granted server-side only after a verified signup.")
            }
        }
    }

    private func ruleRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }
}
