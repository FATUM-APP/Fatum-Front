//
//  ProviderRoute.swift
//  Fatum
//

import SwiftUI

/// Destinations reachable from the Provider ("Mis servicios") tab.
/// `.home` and `.addresses` let a professional hire services with the same
/// Home flow clients use in their Home tab.
enum ProviderRoute: Hashable {
    case home
    case addresses
    case createService
}

extension View {
    /// Registers every `ProviderRoute` destination. Apply once to the root of the
    /// `NavigationStack` owned by `MyServicesScreen`.
    func providerDestinations() -> some View {
        navigationDestination(for: ProviderRoute.self) { route in
            switch route {
            case .home:
                HomeContentView(addressesRoute: ProviderRoute.addresses, showsBackButton: true)
                    .toolbar(.hidden, for: .tabBar)
            case .addresses:
                AddressesScreen<ProviderRoute>()
                    .toolbar(.hidden, for: .tabBar)
            case .createService:
                CreateServiceScreen()
                    .toolbar(.hidden, for: .tabBar)
            }
        }
    }
}
