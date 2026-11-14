//
//  ProfileRoute.swift
//  Fatum
//

import SwiftUI

/// Destinations reachable from the Profile tab after the user signs in.
/// Home reuses it to push `.addresses`, `.serviceDetail` and `.orders`.
enum ProfileRoute: Hashable {
    case manageProfile
    case addresses
    case updateUser(UserFieldType)
    /// A service opened from Home, as clients see it.
    case serviceDetail(FatumItem)
    /// The user's orders from one side: `.PROVIDER` the ones they provide,
    /// `.CUSTOMER` the ones they hired.
    case orders(ConfirmingParty)
    /// "Servicios favoritos" from Profile. Clients have it as a tab instead.
    case favorites
}

extension View {
    /// Registers every `ProfileRoute` destination. Applied once in `MainTabView`,
    /// whose stack wraps the tab bar, so these screens cover it without hiding it.
    func profileDestinations() -> some View {
        navigationDestination(for: ProfileRoute.self) { route in
            switch route {
            case .manageProfile:
                ManageProfileScreen()
            case .addresses:
                AddressesScreen<ProfileRoute>()
            case .updateUser(let fieldType):
                UpdateUserScreen(fieldType: fieldType)
            case .serviceDetail(let service):
                // After hiring, the user lands on the orders they hired.
                ServiceDetailScreen<ProfileRoute>(service: service, mode: .client, ordersRoute: .orders(.CUSTOMER))
            case .orders(let side):
                OrdersScreen<ProfileRoute>(side: side)
            case .favorites:
                FavoritesScreen(showsBackButton: true)
            }
        }
    }
}
