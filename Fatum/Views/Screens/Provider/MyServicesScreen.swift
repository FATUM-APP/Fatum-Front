//
//  MyServicesScreen.swift
//  Fatum
//

import SwiftUI

/// Root of the "Mis servicios" tab for professionals. Owns the `Router<ProviderRoute>`
/// and shares it with every screen pushed in this tab.
///
/// "Contratar" opens Home, "Mis Favoritos" is not available yet, and
/// "+ Ofrecer Servicio" starts `CreateServiceScreen`. The content scrolls
/// vertically so more sections can be added below.
struct MyServicesScreen: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var router = Router<ProviderRoute>()
    @State private var showToast = false
    @State private var toastMessage = "Función en construcción"

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: layout.externalSpacing) {
                    HStack(spacing: layout.smallPadding) {
                        Button {
                            router.push(.home)
                        } label: {
                            Label("Contratar", systemImage: "bag")
                        }
                        .buttonStyle(.fatumButton(variant: .bordered))

                        Spacer()

                        Button {
                            showMessage("Función en construcción")
                        } label: {
                            Label("Mis Favoritos", systemImage: "heart")
                        }
                        .buttonStyle(.fatumButton(variant: .bordered))
                    }
                    .padding(.horizontal, layout.internalPadding)

                    Button("+ Ofrecer Servicio") {
                        router.push(.createService)
                    }
                    .buttonStyle(.fatumButton(variant: .third))
                }
                .screenPadding()
            }
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
    MyServicesScreen()
        .environment(UserProvider())
}
