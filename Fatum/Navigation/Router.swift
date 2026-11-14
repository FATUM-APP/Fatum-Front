//
//  Router.swift
//  Fatum
//

import SwiftUI

/// The `NavigationPath` of one `NavigationStack`. Several routers share it
/// when the stack mixes route types.
@MainActor
@Observable
final class NavigationStore {
    var path = NavigationPath()
}

/// Exposes typed push / pop operations for a single route enum on top of a
/// `NavigationStore`.
///
/// The view that owns the stack creates the router as `@State`, binds it with
/// `NavigationStack(path: $router.path)` and injects it with `.environment(router)`.
/// Every screen inside that stack reads it with `@Environment(Router<Route>.self)`
/// and never touches the path directly.
///
/// The stacks:
/// - `Router<AuthRoute>` in `ContentView` (before sign-in).
/// - After sign-in, `MainTabView` owns one stack around the `TabView`, so pushed
///   screens cover the tab bar instead of hiding it. `Router<ProfileRoute>` (Home
///   and Profile tabs) and `Router<ProviderRoute>` ("Mis servicios") share its store.
///
/// Modal flows (`fullScreenCover`) are not part of a stack, so they keep using
/// `@Environment(\.dismiss)`.
@MainActor
@Observable
final class Router<Route: Hashable> {
    private let store: NavigationStore

    /// A router with its own path.
    init() {
        self.store = NavigationStore()
    }

    /// A router that pushes onto `store`, shared with other routers.
    init(store: NavigationStore) {
        self.store = store
    }

    var path: NavigationPath {
        get { store.path }
        set { store.path = newValue }
    }

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
