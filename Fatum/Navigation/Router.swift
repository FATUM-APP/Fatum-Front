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
///
/// Modal flows (`fullScreenCover`) are not part of a stack, so they keep using
/// `@Environment(\.dismiss)`.
@MainActor
@Observable
final class Router<Route: Hashable> {
    var path = NavigationPath()

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeLast(path.count)
    }

   
    func replaceAll(with route: Route) {
        popToRoot()
        push(route)
    }
}
