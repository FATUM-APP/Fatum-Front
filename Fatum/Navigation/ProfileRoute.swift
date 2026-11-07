//
//  ProfileRoute.swift
//  Fatum
//

import SwiftUI

/// Destinations reachable from the Profile tab after the user signs in.
/// Home reuses it to push `.addresses`.
enum ProfileRoute: Hashable {
    case manageProfile
    case addresses
    case updateUser(UserFieldType)
}

extension View {
    /// Registers every `ProfileRoute` destination. Apply once to the root of each
    /// `NavigationStack` that uses `Router<ProfileRoute>` (`ProfileScreen`, `HomeView`).
    func profileDestinations() -> some View {
        navigationDestination(for: ProfileRoute.self) { route in
            switch route {
            case .manageProfile:
                ManageProfileScreen()
            case .addresses:
                AddressesScreen()
            case .updateUser(let fieldType):
                UpdateUserScreen(fieldType: fieldType)
            }
        }
    }
}
