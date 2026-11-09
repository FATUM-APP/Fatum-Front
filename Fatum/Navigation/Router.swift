//
//  Router.swift
//  Fatum
//

import SwiftUI

/// Owns the `NavigationPath` of one `NavigationStack` and exposes typed
/// push / pop operations for a single route enum.
///
/// The view that owns the stack creates the router as `@State`, binds it with
/// `NavigationStack(path: $router.path)` and injects it with `.environment(router)`.
/// Every screen inside that stack reads it with `@Environment(Router<Route>.self)`
/// and never touches the path directly.
///
/// There is one router per stack:
/// - `Router<AuthRoute>` in `ContentView` (before sign-in).
/// - `Router<ProfileRoute>` in `ProfileScreen` (after sign-in).
/// - `Router<ProfileRoute>` in `HomeView`, to reach `AddressesScreen` from the address selector.
/// - `Router<ProviderRoute>` in `ProviderScreen` (the professional's "Mis servicios" tab).
///
/// Modal flows (`fullScreenCover`) are not part of a stack, so they keep using
/// `@Environment(\.dismiss)`.
///
/// Routes are `Hashable` and can't carry callbacks, so a screen that finishes a
/// task calls `pop(message:)`; the root of the stack observes `message`, shows it
/// in a toast and clears it.
@MainActor
@Observable
final class Router<Route: Hashable> {
    var path = NavigationPath()
    /// Result to show on the screen revealed by `pop(message:)`, e.g. "Servicio creado exitosamente".
    var message: String? = nil

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func pop(message: String) {
        self.message = message
        pop()
    }

    func popToRoot() {
        path.removeLast(path.count)
    }

    func replaceAll(with route: Route) {
        popToRoot()
        push(route)
    }
}
