//
//  ProfileRoute.swift
//  Fatum
//

import SwiftUI

/// Destinations reachable from the Profile tab after the user signs in.
enum ProfileRoute: Hashable {
    case manageProfile
    case addresses
    case updateUser(UserFieldType)
}

extension View {
    /// Registers every `ProfileRoute` destination. Apply once to the root of the
    /// `NavigationStack` owned by `ProfileScreen`.
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
