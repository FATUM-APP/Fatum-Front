//
//  HomeView.swift
//  Fatum
//
//  Created by Camilo Castaño on 5/8/26.
//

import SwiftUI

struct HomeView: View {
    @Environment(UserProvider.self) private var userProvider
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var name: String {
        userProvider.currentUser?.name ?? "Usuario"
    }

    private var isProfessional: Bool {
        userProvider.currentUser?.role == .professional
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandSecondary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: layout.externalSpacing) {

                        // Logo
                        Image(isProfessional ? "FatumPro" : "FatumLogin")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 48)

                        // Greeting
                        VStack(spacing: layout.spacingSmall) {
                            Text("Hola \(name),")
                                .fatumStyle(.body)
                                .foregroundStyle(.loginText)

                            Text("¿Qué servicio estas buscando el día de hoy?")
                                .fatumStyle(.header)
                                .foregroundStyle(.loginText)
                                .multilineTextAlignment(.center)
                        }

                        // Recommendations header
                        HStack(spacing: layout.spacingSmall) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.brandPrimary)

                            Text("PreferencIA te recomienda")
                                .fatumStyle(.subheader)
                                .foregroundStyle(.loginText)
                                .lineLimit(2)

                            Spacer()
                        }

                        // Placeholder for recommendations
                        VStack(spacing: layout.internalSpacing) {
                            Image(systemName: "tray")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .foregroundStyle(.brandPrimary.opacity(0.5))

                            Text("No hay servicios disponibles")
                                .fatumStyle(.subheader)
                                .foregroundStyle(.loginText)

                            Text("Intenta con otra categoría")
                                .fatumStyle(.body)
                                .foregroundStyle(.loginText.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, layout.externalSpacing)
                    }
                    .screenPadding()
                }
            }
        }
    }
}

#Preview {
    let provider = UserProvider()
    HomeView()
        .environment(provider)
}
