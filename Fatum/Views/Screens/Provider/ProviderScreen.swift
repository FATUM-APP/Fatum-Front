//
//  ProviderScreen.swift
//  Fatum
//

import SwiftUI

/// Root of the "Mis servicios" tab for professionals. Owns the `Router<ProviderRoute>`
/// and shares it with every screen pushed in this tab.
///
/// "Contratar" opens Home, "Mis Favoritos" is not available yet, and
/// "+ Ofrecer Servicio" starts `CreateServiceScreen`.
struct ProviderScreen: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var router = Router<ProviderRoute>()
    @State private var showToast = false
    @State private var toastMessage = "Función en construcción"

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            VStack(alignment: .leading, spacing: layout.externalSpacing) {
                HStack(spacing: layout.internalSpacing) {
                    ProviderChipView(title: "Contratar", icon: "bag") {
                        router.push(.home)
                    }

                    ProviderChipView(title: "Mis Favoritos", icon: "heart") {
                        showMessage("Función en construcción")
                    }
                }

                Button("+ Ofrecer Servicio") {
                    router.push(.createService)
                }
                .buttonStyle(.fatumButton(variant: .third))

                Spacer()
            }
            .screenPadding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.brandSecondary)
            .overlay(alignment: .bottom) {
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
            .animation(.easeInOut, value: showToast)
            // Results sent back with `router.pop(message:)`, e.g. after creating a service.
            .onChange(of: router.message) { _, message in
                guard let message else { return }
                showMessage(message)
                router.message = nil
            }
            .providerDestinations()
        }
        .environment(router)
    }

    private func showMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
    }
}

#Preview {
    ProviderScreen()
        .environment(UserProvider())
}
