//
//  ProfileScreen.swift
//  Fatum
//
//  Created by Camilo Castaño on 5/8/26.
//

import SwiftUI

/// Root of the Profile tab. Owns the `Router<ProfileRoute>` and shares it with
/// every screen pushed in this tab.
struct ProfileScreen: View {
    @Environment(UserProvider.self) private var userProvider
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showToast = false
    @State private var toastMessage = "Función en construcción"
    @State private var isUpgrading = false
    @State private var router = Router<ProfileRoute>()

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var isProfessional: Bool {
        userProvider.currentUser?.role == .professional
    }

    var body: some View {
        NavigationStack(path: $router.path) {
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
                    ProfileOptionView(icon: "heart.fill", name: "Servicios favoritos") {
                        showUnderConstruction()
                    }

                    Spacer()
                }

                ProfileOptionView(icon: "person.circle", name: "Maneja tu perfil") {
                    router.push(.manageProfile)
                }

                Spacer()

                ProfileOptionView(icon: "hand.raised.fill", name: "Servicios recibidos") {
                    showUnderConstruction()
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
            .toolbar(.visible, for: .tabBar)
            .profileDestinations()
        }
        .environment(router)
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
    let provider = UserProvider()
    ProfileScreen()
        .environment(provider)
}
