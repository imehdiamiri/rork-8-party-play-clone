import SwiftUI

struct AuthView: View {
    let appModel: AppViewModel
    var showCloseButton: Bool = true
    @State private var isLogin: Bool = true
    @State private var username: String = ""
    @State private var password: String = ""
    @FocusState private var focusedField: AuthField?
    @Environment(\.dismiss) private var dismiss

    nonisolated enum AuthField: Hashable, Sendable {
        case username
        case password
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                VStack(spacing: 0) {
                    if showCloseButton {
                        HStack {
                            Spacer()
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 32, height: 32)
                                    .background(.white.opacity(0.08), in: .circle)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }

                    Spacer()

                    VStack(spacing: 28) {
                        VStack(spacing: 10) {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundStyle(.blue)
                                .frame(width: 72, height: 72)
                                .background(.blue.opacity(0.14), in: .rect(cornerRadius: 22))

                            Text("8PartyPlay")
                                .viralTitleStyle(size: 32, weight: .black)

                            Text("Sign in to claim 100 \u{2605},\nfriends, and AI cards.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }

                        VStack(spacing: 12) {
                            TextField("Username", text: $username)
                                .textInputAutocapitalization(.never)
                                .textContentType(.username)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .username)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .password
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(.white.opacity(0.06), in: .rect(cornerRadius: 14))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(.white.opacity(0.08))
                                }

                            SecureField("Password", text: $password)
                                .textContentType(isLogin ? .password : .newPassword)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit {
                                    submitAuth()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(.white.opacity(0.06), in: .rect(cornerRadius: 14))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(.white.opacity(0.08))
                                }
                        }

                        VStack(spacing: 10) {
                            Button(isLogin ? "Login" : "Create Account") {
                                submitAuth()
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                            .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appModel.isBusy)

                            Button {
                                appModel.signInWithApple()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "apple.logo")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Continue with Apple")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.white.opacity(0.09), in: .rect(cornerRadius: 14))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(.white.opacity(0.06))
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(appModel.isBusy)

                            Button {
                                appModel.signInWithGoogle()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "globe")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Continue with Google")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.white.opacity(0.065), in: .rect(cornerRadius: 14))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(.white.opacity(0.05))
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(appModel.isBusy)

                            if let errorMessage = appModel.errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                            }
                        }

                        Button {
                            withAnimation(.spring(duration: 0.25)) {
                                isLogin.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(isLogin ? "Don't have an account?" : "Already have an account?")
                                    .foregroundStyle(.secondary)
                                Text(isLogin ? "Sign Up" : "Login")
                                    .foregroundStyle(.blue)
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 28)

                    Spacer()

                    VStack(spacing: 12) {
                        Button("Continue as Guest") {
                            appModel.continueAsGuest()
                            dismiss()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)

                        Text("You can log in anytime later from your profile.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        HStack(spacing: 12) {
                            Link("Privacy Policy", destination: LegalLinks.privacyPolicyURL)
                            Text("•").foregroundStyle(.tertiary)
                            Link("Terms of Service", destination: LegalLinks.termsOfServiceURL)
                        }
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
        .dismissKeyboardOnTap()
        .onChange(of: appModel.currentProvider) { _, newValue in
            if newValue != .guest {
                focusedField = nil
                if showCloseButton {
                    dismiss()
                }
            }
        }
        .overlay {
            if appModel.isBusy {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                        .padding(24)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
                }
            }
        }
    }

    private func submitAuth() {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty, !trimmedPassword.isEmpty, !appModel.isBusy else { return }
        focusedField = nil
        if isLogin {
            appModel.signIn(username: trimmedUsername, password: trimmedPassword)
        } else {
            appModel.signUp(username: trimmedUsername, password: trimmedPassword)
        }
    }
}
