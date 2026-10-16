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
                    // The become-professional flow is being rebuilt; placeholder for now.
                    ProfileOptionView(icon: "dollarsign.circle", name: "Conviértete en profesional") {
                        showToast = true
                    }

                    Spacer()
                }

                if isProfessional {
                    ProfileOptionView(icon: "heart.fill", name: "Servicios favoritos") {
                        showToast = true
                    }

                    Spacer()
                }

                ProfileOptionView(icon: "person.circle", name: "Maneja tu perfil") {
                    router.push(.manageProfile)
                }

                Spacer()

                ProfileOptionView(icon: "hand.raised.fill", name: "Servicios recibidos") {
                    showToast = true
                }

                Spacer()

                ProfileOptionView(icon: "house.fill", name: "Direcciones") {
                    router.push(.addresses)
                }

                Spacer()

                ProfileOptionView(icon: "creditcard", name: "Métodos de pago") {
                    showToast = true
                }

                Spacer()

                ProfileOptionView(icon: "rectangle.portrait.and.arrow.right", name: "Cerrar Sesión") {
                    Task {
                        await userProvider.signOut()
                    }
                }

                Spacer()

                if showToast {
                    ToastMessageView(message: "Función en construcción")
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
            .animation(.easeInOut, value: showToast)
            .background(.brandSecondary)
            .profileDestinations()
        }
        .environment(router)
    }
}

#Preview {
    let provider = UserProvider()
    ProfileScreen()
        .environment(provider)
}
