//
//  ProviderRoute.swift
//  Fatum
//

import SwiftUI

/// Destinations reachable from the Provider ("Mis servicios") tab.
/// `.home`, `.addresses` and `.serviceDetail` let a professional hire services
/// with the same Home flow clients use in their Home tab.
enum ProviderRoute: Hashable {
    case home
    case addresses
    case createService
    /// One of the provider's own services, editable.
    case editService(FatumItem)
    /// A service opened from Home, as clients see it.
    case serviceDetail(FatumItem)
}

extension View {
    /// Registers every `ProviderRoute` destination. Apply once to the root of the
    /// `NavigationStack` owned by `MyServicesScreen`.
    func providerDestinations() -> some View {
        navigationDestination(for: ProviderRoute.self) { route in
            switch route {
            case .home:
                HomeContentView(
                    addressesRoute: ProviderRoute.addresses,
                    serviceRoute: ProviderRoute.serviceDetail,
                    showsBackButton: true
                )
                .toolbar(.hidden, for: .tabBar)
            case .addresses:
                AddressesScreen<ProviderRoute>()
                    .toolbar(.hidden, for: .tabBar)
            case .createService:
                CreateServiceScreen()
                    .toolbar(.hidden, for: .tabBar)
            case .editService(let service):
                ServiceDetailScreen<ProviderRoute>(service: service, mode: .edit)
                    .toolbar(.hidden, for: .tabBar)
            case .serviceDetail(let service):
                ServiceDetailScreen<ProviderRoute>(service: service, mode: .client)
                    .toolbar(.hidden, for: .tabBar)
            }
        }
    }
}
