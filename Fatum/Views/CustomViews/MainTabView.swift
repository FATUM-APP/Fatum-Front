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

    private var isProfessional: Bool {
        userProvider.currentUser?.role == .professional
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: 0) {
                if isProfessional {
                    BuildingView(name: "Inicio")
                } else {
                    HomeView()
                }
            } label: {
                Image(systemName: "house")
                Text("Inicio")
            }

            Tab(value: 1) {
                if isProfessional {
                    MyServicesScreen()
                } else {
                    BuildingView(name: "Favoritos")
                }
            } label: {
                Image(systemName: isProfessional ? "briefcase" : "heart")
                Text(isProfessional ? "Mis servicios" : "Favoritos")
            }

            Tab(value: 2) {
                BuildingView(name: "Calendario")
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
