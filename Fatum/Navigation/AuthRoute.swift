//
//  AuthRoute.swift
//  Fatum
//

import SwiftUI

/// Destinations reachable from the welcome screen before the user signs in.
enum AuthRoute: Hashable {
    case login
    case register
    /// The password is kept only in memory so the account can be signed in
    /// automatically right after the e-mail is confirmed.
    case confirmEmail(email: String, password: String)
    case passwordReset
}

extension View {
    /// Registers every `AuthRoute` destination. Apply once to the root of the
    /// `NavigationStack` owned by `ContentView`.
    func authDestinations() -> some View {
        navigationDestination(for: AuthRoute.self) { route in
            switch route {
            case .login:
                LoginView()
            case .register:
                RegisterView()
            case .confirmEmail(let email, let password):
                ConfirmationView(email: email, password: password)
            case .passwordReset:
                BuildingView(name: "Password Reset")
            }
        }
    }
}
