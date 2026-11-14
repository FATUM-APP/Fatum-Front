//
//  ProfileScreen.swift
//  Fatum
//
//  Created by Camilo Castaño on 5/8/26.
//

import SwiftUI

/// Root of the Profile tab. Pushes onto `MainTabView`'s stack through `Router<ProfileRoute>`.
struct ProfileScreen: View {
    @Environment(UserProvider.self) private var userProvider
    @Environment(Router<ProfileRoute>.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showToast = false
    @State private var toastMessage = "Función en construcción"
    @State private var isUpgrading = false

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var isProfessional: Bool {
        userProvider.currentUser?.role == .professional
    }

    var body: some View {
        VStack(spacing: 0) {
            
            UserProfileHeader()

            Spacer()
                .frame(height: layout.externalSpacing)

            if !isProfessional {
                ProfileOptionView(icon: "dollarsign.circle", name: "Conviértete en profesional") {
                    becomeProfessional()
                }
                .disabled(isUpgrading)

                Spacer()
            }

            if isProfessional {
                // Professionals' second tab is "Mis servicios", so their favorites live here.
                ProfileOptionView(icon: "heart.fill", name: "Servicios favoritos") {
                    router.push(.favorites)
                }

                Spacer()
            }

            ProfileOptionView(icon: "person.circle", name: "Maneja tu perfil") {
                router.push(.manageProfile)
            }

            Spacer()

            // Received services are the ones the user hired, so professionals
            // also see them as a client.
            ProfileOptionView(icon: "hand.raised.fill", name: "Servicios recibidos") {
                router.push(.orders(.CUSTOMER))
            }

            Spacer()

            ProfileOptionView(icon: "house.fill", name: "Direcciones") {
                router.push(.addresses)
            }

            Spacer()

            ProfileOptionView(icon: "creditcard", name: "Métodos de pago") {
                showUnderConstruction()
            }

            Spacer()

            ProfileOptionView(icon: "rectangle.portrait.and.arrow.right", name: "Cerrar Sesión") {
                Task {
                    await userProvider.signOut()
                }
            }

            Spacer()

            if showToast {
                ToastMessageView(message: toastMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            withAnimation {
                                showToast = false
                            }
                        }
                    }
            }
        }
        .screenPadding()
        .animation(.easeInOut, value: showToast)
        .background(.brandSecondary)
    }

    private func showUnderConstruction() {
        toastMessage = "Función en construcción"
        showToast = true
    }

    /// Upgrades the user; on success `currentUser` is reloaded and the view
    /// switches to the professional options on its own.
    private func becomeProfessional() {
        guard !isUpgrading else { return }
        isUpgrading = true
        Task {
            let success = await userProvider.becomeProfessional()
            isUpgrading = false
            toastMessage = success
                ? "Ahora eres profesional"
                : userProvider.error ?? "No se pudo completar la solicitud"
            showToast = true
        }
    }
}

#Preview {
    NavigationStack {
        ProfileScreen()
            .profileDestinations()
    }
    .environment(Router<ProfileRoute>())
    .environment(UserProvider())
}
