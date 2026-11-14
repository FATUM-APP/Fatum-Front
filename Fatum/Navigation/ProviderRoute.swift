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
    /// Registers every `ProviderRoute` destination. Applied once in `MainTabView`,
    /// whose stack wraps the tab bar, so these screens cover it without hiding it.
    func providerDestinations() -> some View {
        navigationDestination(for: ProviderRoute.self) { route in
            switch route {
            case .createService:
                CreateServiceScreen()
            case .editService(let service):
                ServiceDetailScreen<ProviderRoute>(service: service, mode: .edit)
            }
        }
    }
}
