//
//  ConfirmationView.swift
//  Fatum
//

import SwiftUI

/// Asks for the e-mail code Cognito sent after sign-up.
///
/// On a valid code the account is signed in right away, so `FatumApp` swaps
/// the root to `MainTabView`. If that automatic sign-in fails, a dialog shows
/// the error and "Aceptar" returns to the welcome screen.
struct ConfirmationView: View {
    let email: String
    /// Kept in memory only, to sign in automatically after confirming.
    let password: String

    @Environment(Router<AuthRoute>.self) private var router
    @Environment(UserProvider.self) private var userProvider
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var confirmationCode: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    /// Set when the code was accepted but the automatic sign-in failed.
    @State private var signInErrorMessage: String? = nil

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        ZStack {
            AppGradient.mainBackground
                .ignoresSafeArea()

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: layout.externalSpacing) {

                        // Header
                        VStack(spacing: layout.internalSpacing) {
                            Image(systemName: "envelope.badge.shield.half.filled")
                                .resizable()
                                .scaledToFit()
                                .frame(width: geometry.size.width * 0.2)
                                .foregroundStyle(.brandPrimary)

                            Text("Confirma tu correo")
                                .fatumStyle(.subheader)
                                .foregroundStyle(.loginText)

                            Text("Hemos enviado un código de verificación a \(email)")
                                .fatumStyle(.body)
                                .foregroundStyle(.loginText)
                                .multilineTextAlignment(.center)
                        }

                        // Form
                        VStack(spacing: layout.spacingMedium) {
                            FatumTextField(
                                placeholder: "Código de verificación",
                                text: $confirmationCode,
                                prefixIcon: "number",
                                keyboardType: .numberPad,
                                maxLength: 6,
                                allowedCharacters: { _, newValue in
                                    newValue.filter { $0.isNumber }
                                }
                            )

                            if let errorMessage {
                                Text(errorMessage)
                                    .fatumStyle(.footer)
                                    .foregroundStyle(.errorBorderLogin)
                                    .multilineTextAlignment(.center)
                            }

                            Button {
                                confirmSignUp()
                            } label: {
                                if isLoading {
                                    ProgressView()
                                        .tint(.brandPrimary)
                                } else {
                                    Text("Confirmar")
                                }
                            }
                            .buttonStyle(.fatumButton(variant: .primary))
                            .disabled(isLoading)

                            Button("Reenviar código") {
                                resendCode()
                            }
                            .fatumStyle(.body)
                            .fontWeight(.bold)
                            .foregroundStyle(.loginText)
                            .disabled(isLoading)
                        }

                        Spacer()
                    }
                    .screenPadding()
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            if let signInErrorMessage {
                RequiredActionDialog(description: "Tu cuenta fue confirmada, pero no pudimos iniciar sesión") {
                    VStack(spacing: layout.spacingMedium) {
                        Text(signInErrorMessage)
                            .fatumStyle(.body)
                            .foregroundStyle(.text)
                            .multilineTextAlignment(.center)

                        Button("Aceptar") {
                            returnToWelcome()
                        }
                        .buttonStyle(.fatumButton(variant: .third))
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    router.pop()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.brandPrimary)
                }
                .disabled(isLoading)
            }
        }
    }

    // MARK: - Actions

    private func confirmSignUp() {
        guard !confirmationCode.isEmpty else {
            errorMessage = "Ingresa el código de verificación"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            // Step 1: confirm the code. A wrong code keeps the user on this screen.
            guard await userProvider.confirmSignUp(email: email, code: confirmationCode) else {
                isLoading = false
                errorMessage = userProvider.error ?? "No se pudo confirmar el código"
                return
            }

            // Step 2: sign in. On success FatumApp shows MainTabView on its own.
            let signedIn = await userProvider.signIn(email: email, password: password, isNewAccount: true)
            isLoading = false
            if !signedIn {
                signInErrorMessage = userProvider.error ?? "Inicia sesión con tu correo y contraseña."
            }
        }
    }

    private func resendCode() {
        errorMessage = nil
        Task {
            if !(await userProvider.resendSignUpCode(email: email)) {
                errorMessage = userProvider.error ?? "No se pudo reenviar el código"
            }
        }
    }

    /// Clears any half-open session and goes back to the welcome screen.
    private func returnToWelcome() {
        Task {
            await userProvider.signOut()
            signInErrorMessage = nil
            router.popToRoot()
        }
    }
}

#Preview {
    NavigationStack {
        ConfirmationView(email: "test@example.com", password: "")
    }
    .environment(Router<AuthRoute>())
    .environment(UserProvider())
}
