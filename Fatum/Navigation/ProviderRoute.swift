//
//  ProviderRoute.swift
//  Fatum
//

import SwiftUI

/// Destinations reachable from the Provider ("Mis servicios") tab.
enum ProviderRoute: Hashable {
    case createService
    /// One of the provider's own services, editable.
    case editService(FatumItem)
}

extension View {
    /// Registers every `ProviderRoute` destination. Apply once to the root of the
    /// `NavigationStack` owned by `MyServicesScreen`.
    func providerDestinations() -> some View {
        navigationDestination(for: ProviderRoute.self) { route in
            switch route {
            case .createService:
                CreateServiceScreen()
                    .toolbar(.hidden, for: .tabBar)
            case .editService(let service):
                ServiceDetailScreen<ProviderRoute>(service: service, mode: .edit)
                    .toolbar(.hidden, for: .tabBar)
            }
        }
    }
}
