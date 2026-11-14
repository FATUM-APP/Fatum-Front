//
//  MainTabView.swift
//  Fatum
//
//  Created by Camilo Castaño on 5/8/26.
//

import SwiftUI

struct MainTabView: View {
    @Environment(UserProvider.self) private var userProvider
    @State private var selectedTab = 0
    /// Which calendar a professional sees, picked with `CalendarSideMenu`.
    @State private var calendarSide: ConfirmingParty = .PROVIDER
    /// The stack around the `TabView`: whatever any tab pushes slides in over
    /// the tab bar, so it never has to be hidden or shown again.
    @State private var navigation: NavigationStore
    @State private var profileRouter: Router<ProfileRoute>
    @State private var providerRouter: Router<ProviderRoute>
    /// Shared by Home, "Favoritos" and the service page.
    @State private var favoritesProvider = FavoritesProvider()

    private var isProfessional: Bool {
        userProvider.currentUser?.role == .professional
    }

    var body: some View {
        NavigationStack(path: $navigation.path) {
            tabs
                .profileDestinations()
                .providerDestinations()
        }
        .environment(profileRouter)
        .environment(providerRouter)
        .environment(favoritesProvider)
        // Loaded once up front so Home's cards know which services are favorites.
        .task(id: userProvider.currentUser?.userId) {
            guard let clientId = userProvider.currentUser?.userId else { return }
            await favoritesProvider.loadFavorites(clientId: clientId)
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            // Clients and professionals share the same Home.
            Tab(value: 0) {
                HomeView()
            } label: {
                Image(systemName: "house")
                Text("Inicio")
            }

            Tab(value: 1) {
                if isProfessional {
                    MyServicesScreen()
                } else {
                    FavoritesScreen()
                }
            } label: {
                Image(systemName: isProfessional ? "briefcase" : "heart")
                Text(isProfessional ? "Mis servicios" : "Favoritos")
            }

            Tab(value: 2) {
                // Professionals switch sides with the menu; clients only have their own calendar.
                if !isProfessional {
                    ClientCalendarScreen()
                } else if calendarSide == .PROVIDER {
                    CalendarScreen(side: $calendarSide)
                } else {
                    ClientCalendarScreen(side: $calendarSide)
                }
            } label: {
                Image(systemName: "calendar")
                Text("Calendario")
            }

            Tab(value: 3) {
                ProfileScreen()
            } label: {
                Image(systemName: "person")
                Text("Perfil")
            }
        }
        .tint(.fatumAccent)
    }

    /// The appearance proxy must be configured before the `UITabBar` is created,
    /// so this runs in `init` rather than `onAppear` (which is too late).
    init() {
        // Both routers push onto the same path.
        let store = NavigationStore()
        _navigation = State(initialValue: store)
        _profileRouter = State(initialValue: Router(store: store))
        _providerRouter = State(initialValue: Router(store: store))

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor(.brandPrimary)
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(.brandPrimary)]
        itemAppearance.selected.iconColor = UIColor(.fatumAccent)
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(.fatumAccent)]

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(.brandSecondary)
        appearance.shadowColor = UIColor(.border)

        // Stacked = iPhone portrait; inline / compactInline = iPad and iPhone landscape.
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    MainTabView()
        .environment(UserProvider())
}
