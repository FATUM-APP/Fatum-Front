//
//  ProfileRoute.swift
//  Fatum
//

import SwiftUI

/// Destinations reachable from the Profile tab after the user signs in.
/// Home reuses it to push `.addresses` and `.serviceDetail`.
enum ProfileRoute: Hashable {
    case manageProfile
    case addresses
    case updateUser(UserFieldType)
    /// A service opened from Home, as clients see it.
    case serviceDetail(FatumItem)
}

extension View {
    /// Registers every `ProfileRoute` destination. Apply once to the root of each
    /// `NavigationStack` that uses `Router<ProfileRoute>` (`ProfileScreen`, `HomeView`).
    func profileDestinations() -> some View {
        navigationDestination(for: ProfileRoute.self) { route in
            switch route {
            case .manageProfile:
                ManageProfileScreen()
                    .toolbar(.hidden, for: .tabBar)
            case .addresses:
                AddressesScreen<ProfileRoute>()
                    .toolbar(.hidden, for: .tabBar)
            case .updateUser(let fieldType):
                UpdateUserScreen(fieldType: fieldType)
                    .toolbar(.hidden, for: .tabBar)
            case .serviceDetail(let service):
                ServiceDetailScreen<ProfileRoute>(service: service, mode: .client)
                    .toolbar(.hidden, for: .tabBar)
            }
        }
    }
}
