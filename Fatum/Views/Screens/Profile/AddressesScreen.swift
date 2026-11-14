//
//  AddressesScreen.swift
//  Fatum
//

import SwiftUI

/// Lists the current user's saved addresses, split into the principal address
/// and the rest, with a bottom button to add a new one.
///
/// All loading and creation goes through `AddressProvider`, which this screen
/// owns and shares with `AddAddressScreen` through the environment.
///
/// `Route` is the route type of the stack that pushed it (`ProfileRoute` from the
/// Profile and Home tabs).
struct AddressesScreen<Route: Hashable>: View {
    @Environment(Router<Route>.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var addressProvider = AddressProvider()
    @State private var searchText: String = ""

    @State private var showAddAddress = false
    @State private var addressToDelete: FatumAddress? = nil
    @State private var showToast = false
    @State private var toastMessage: String = ""

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    /// Principal address, hidden while the search text does not match it.
    private var visiblePrincipal: FatumAddress? {
        guard let principal = addressProvider.principal, principal.matches(searchText) else { return nil }
        return principal
    }

    /// Every non-principal address that matches the search text.
    private var otherAddresses: [FatumAddress] {
        addressProvider.addresses.filter { $0 != addressProvider.principal && $0.matches(searchText) }
    }

    private var hasSearchResults: Bool {
        visiblePrincipal != nil || !otherAddresses.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if addressProvider.isLoading {
                Spacer()
                ProgressView()
                    .tint(.brandPrimary)
                Spacer()
            } else if addressProvider.loadFailed {
                Spacer()
                placeholder(
                    icon: "exclamationmark.triangle",
                    title: "No pudimos cargar tus direcciones",
                    message: addressProvider.error ?? "Revisa tu conexión e inténtalo de nuevo"
                )
                Button("Reintentar") {
                    Task { await addressProvider.loadAddresses() }
                }
                .buttonStyle(.fatumButton(variant: .outlined))
                Spacer()
            } else if addressProvider.addresses.isEmpty {
                Spacer()
                placeholder(
                    icon: "mappin.slash",
                    title: "No tienes direcciones guardadas",
                    message: "Agrega una dirección para que los profesionales sepan dónde atenderte"
                )
                Spacer()
            } else {
                addressList
            }

            // Add button
            Button {
                showAddAddress = true
            } label: {
                HStack(spacing: layout.internalSpacing) {
                    Image(systemName: "plus")
                    Text("Agregar nueva dirección")
                }
            }
            .buttonStyle(.fatumButton(variant: .third))
            .disabled(addressProvider.isLoading)
            .screenPadding([.horizontal, .bottom])
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    router.pop()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.text)
                }
            }

            ToolbarItem(placement: .principal) {
                Text("Mis direcciones")
                    .fatumStyle(.subheader)
                    .foregroundStyle(.text)
            }
        }
        .task {
            await addressProvider.loadAddresses()
        }
        // Slides up from the bottom and covers the whole screen; the X inside dismisses it.
        .fullScreenCover(isPresented: $showAddAddress) {
            AddAddressScreen { errorMessage in
                if let errorMessage { showMessage(errorMessage) }
            }
            .environment(addressProvider)
        }
        .confirmationDialog(
            "¿Eliminar esta dirección?",
            isPresented: Binding(
                get: { addressToDelete != nil },
                set: { if !$0 { addressToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: addressToDelete
        ) { address in
            Button("Eliminar", role: .destructive) {
                confirmDelete(address)
            }
            Button("Cancelar", role: .cancel) {}
        } message: { address in
            Text("\(address.displayName) se eliminará de tus direcciones.")
        }
    }

    // MARK: - List

    private var addressList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layout.spacingMedium) {
                // Search
                FatumTextField(
                    placeholder: "Buscar por alias o dirección",
                    text: $searchText,
                    style: .standard,
                    prefixIcon: "magnifyingglass",
                    submitLabel: .search
                )

                if let visiblePrincipal {
                    sectionHeader("Dirección principal")
                    

                    AddressCardView(
                        address: visiblePrincipal,
                        isPrincipal: true,
                        onMakePrincipal: { makePrincipal(visiblePrincipal) },
                        onDelete: { delete(visiblePrincipal) }
                    )
                }

                if !otherAddresses.isEmpty {
                    sectionHeader("Otras direcciones")
                        .padding(.top, visiblePrincipal == nil ? 0 : layout.internalSpacing)

                    VStack(spacing: layout.internalSpacing) {
                        ForEach(otherAddresses, id: \.self) { address in
                            AddressCardView(
                                address: address,
                                isPrincipal: false,
                                onMakePrincipal: { makePrincipal(address) },
                                onDelete: { delete(address) }
                            )
                        }
                    }
                }

                if !hasSearchResults {
                    placeholder(
                        icon: "magnifyingglass",
                        title: "Sin resultados",
                        message: "Ninguna dirección coincide con tu búsqueda"
                    )
                }
            }
            .screenPadding()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .fatumStyle(.footer)
            .fontWeight(.bold)
            .foregroundStyle(.text)
    }

    /// Centered icon + title + message block, mirroring the empty state in `HomeView`.
    private func placeholder(icon: String, title: String, message: String) -> some View {
        VStack(spacing: layout.spacingMedium) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundStyle(.brandPrimary.opacity(0.5))

            Text(title)
                .fatumStyle(.subheader)
                .foregroundStyle(.text)
                .multilineTextAlignment(.center)

            Text(message)
                .fatumStyle(.body)
                .foregroundStyle(.text)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(layout.externalSpacing)
    }

    // MARK: - Actions

    private func makePrincipal(_ address: FatumAddress) {
        Task {
            if await !addressProvider.makePrincipal(alias: address.identifier) {
                showMessage(addressProvider.error ?? "Error al actualizar la dirección principal")
            }
        }
    }

    /// Asks for confirmation first; the request happens in `confirmDelete`.
    private func delete(_ address: FatumAddress) {
        addressToDelete = address
    }

    private func confirmDelete(_ address: FatumAddress) {
        Task {
            if await !addressProvider.deleteAddress(alias: address.identifier) {
                showMessage(addressProvider.error ?? "Error al eliminar la dirección")
            }
        }
    }

    private func showMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
    }
}

#Preview {
    NavigationStack {
        AddressesScreen<ProfileRoute>()
    }
    .environment(Router<ProfileRoute>())
}
