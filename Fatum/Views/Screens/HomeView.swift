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

    /// Home reuses `ProfileRoute` so "Administrar direcciones" can push the same `AddressesScreen`.
    @State private var router = Router<ProfileRoute>()
    /// Root category whose sub-categories are listed and whose services "Todas" shows.
    @State private var catalogProvider = CatalogProvider(root: "Belleza")
    @State private var addressProvider = AddressProvider()

    /// The address the user is requesting services for. Starts as the one saved on
    /// the device (or the principal one), but picking another here does not change the principal.
    @State private var selectedAddress: FatumAddress? = nil
    @State private var searchText: String = ""

    @State private var showAllCategories = false
    @State private var showAddAddress = false
    @State private var showToast = false
    @State private var toastMessage: String = ""

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var name: String {
        userProvider.currentUser?.name ?? "Usuario"
    }

    /// Only categories the backend marks as enabled are shown.
    private var availableCategories: [FatumCategory] {
        catalogProvider.categories.filter(\.isAble)
    }

    /// Services of the selected filter that match the search text.
    private var visibleServices: [FatumItem] {
        catalogProvider.services.filter { $0.matches(searchText) }
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            ZStack {
                Color.brandSecondary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: layout.externalSpacing) {
                        HomeAddressSelector(
                            addresses: addressProvider.addresses,
                            principal: addressProvider.principal,
                            selected: $selectedAddress,
                            isLoading: addressProvider.isLoading,
                            errorMessage: addressProvider.loadFailed ? addressProvider.error : nil,
                            onMakePrincipal: makePrincipal,
                            onAdd: { showAddAddress = true },
                            onManage: { router.push(.addresses) },
                            onRetry: { Task { await addressProvider.loadAddresses() } }
                        )

                        greetingCard

                        categoriesSection

                        servicesSection
                    }
                    .screenPadding()
                }
                .scrollDismissesKeyboard(.interactively)
            }
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
            // Runs again when coming back from `AddressesScreen`, which has its own provider.
            .task {
                await addressProvider.loadAddresses()
            }
            .task {
                if catalogProvider.categories.isEmpty {
                    await catalogProvider.loadCategories()
                }
                if catalogProvider.selectedFilter == nil {
                    await catalogProvider.selectFilter(.all)
                }
            }
            .onChange(of: addressProvider.addresses) {
                syncSelectedAddress()
            }
            .onChange(of: selectedAddress) { _, address in
                saveSelectedAddress(address)
            }
            .sheet(isPresented: $showAllCategories) {
                AllCategoriesSheet(
                    categories: availableCategories,
                    selectedFilter: catalogProvider.selectedFilter,
                    onSelect: select
                )
            }
            // Same flow as in `AddressesScreen`; `createAddress` reloads this provider's list.
            .fullScreenCover(isPresented: $showAddAddress) {
                AddAddressScreen { message in
                    showMessage(message)
                }
                .environment(addressProvider)
            }
            .profileDestinations()
        }
        .environment(router)
    }

    // MARK: - Greeting

    /// Greeting and search box inside a `.primaryContainer` card.
    private var greetingCard: some View {
        VStack(alignment: .leading, spacing: layout.internalSpacing) {
            Text("Hola \(name),")
                .fatumStyle(.body)
                .foregroundStyle(.brandPrimary)

            Text("¿Qué servicio estas buscando el día de hoy?")
                .fatumStyle(.header)
                .foregroundStyle(.brandPrimary)

            ExpandingSearchField(
                placeholder: "Ej. Corte de cabello, manicure…",
                text: $searchText,
                style: .onContainer
            )
            .padding(.top, layout.spacingSmall)
        }
        .padding(layout.internalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.primaryContainer)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Categories

    /// "Categorías" header with "Ver todas", then a horizontal row of chips:
    /// "Todas" first, then every enabled sub-category. Tapping one loads its services.
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: layout.internalSpacing) {
            HStack {
                Text("Categorías")
                    .fatumStyle(.subheader)
                    .foregroundStyle(.text)

                Spacer()

                Button("Ver todas") {
                    showAllCategories = true
                }
                .fatumStyle(.footer)
                .foregroundStyle(.text)
                .disabled(availableCategories.isEmpty)
            }

            if catalogProvider.isLoadingCategories {
                ProgressView()
                    .tint(.brandPrimary)
                    .frame(maxWidth: .infinity)
            } else if catalogProvider.categoriesLoadFailed {
                VStack(spacing: layout.internalSpacing) {
                    Image(systemName: "exclamationmark.triangle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .foregroundStyle(.brandPrimary.opacity(0.5))

                    Text("No pudimos cargar las categorías")
                        .fatumStyle(.subheader)
                        .foregroundStyle(.text)
                        .multilineTextAlignment(.center)

                    Text(catalogProvider.error ?? "Revisa tu conexión e inténtalo de nuevo")
                        .fatumStyle(.body)
                        .foregroundStyle(.text.opacity(0.7))
                        .multilineTextAlignment(.center)

                    Button("Reintentar") {
                        Task { await catalogProvider.loadCategories() }
                    }
                    .buttonStyle(.fatumButton(variant: .outlined))
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: layout.internalSpacing) {
                        chip(for: .all)

                        ForEach(availableCategories) { category in
                            chip(for: .category(category))
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
    }

    private func chip(for filter: CatalogProvider.ServiceFilter) -> some View {
        Button {
            select(filter)
        } label: {
            CategoryChipView(filter: filter, isSelected: catalogProvider.selectedFilter == filter)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Services

    /// Services of the selected filter: a spinner while loading, the list,
    /// or an empty state when there are none or none match the search.
    @ViewBuilder
    private var servicesSection: some View {
        if catalogProvider.isLoadingServices {
            ProgressView()
                .tint(.brandPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, layout.externalSpacing)
        } else if catalogProvider.services.isEmpty {
            emptyState(
                icon: "tray",
                title: catalogProvider.selectedFilter == nil
                    ? "Selecciona una categoría"
                    : "No hay servicios disponibles",
                message: catalogProvider.selectedFilter == nil ? nil : "Intenta con otra categoría"
            )
        } else if visibleServices.isEmpty {
            emptyState(
                icon: "magnifyingglass",
                title: "Sin resultados",
                message: "Ningún servicio coincide con tu búsqueda"
            )
        } else {
            // Placeholder rows until the service card is designed.
            VStack(alignment: .leading, spacing: layout.internalSpacing) {
                ForEach(visibleServices, id: \.self) { service in
                    VStack(alignment: .leading, spacing: layout.tiny) {
                        Text(service.title)
                            .fatumStyle(.body)
                            .fontWeight(.bold)
                            .foregroundStyle(.text)

                        Text(service.providerName)
                            .fatumStyle(.footer)
                            .foregroundStyle(.text.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func emptyState(icon: String, title: String, message: String?) -> some View {
        VStack(spacing: layout.internalSpacing) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundStyle(.brandPrimary.opacity(0.5))

            Text(title)
                .fatumStyle(.subheader)
                .foregroundStyle(.text)

            if let message {
                Text(message)
                    .fatumStyle(.body)
                    .foregroundStyle(.text.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, layout.externalSpacing)
    }

    // MARK: - Actions

    private func select(_ filter: CatalogProvider.ServiceFilter) {
        Task { await catalogProvider.selectFilter(filter) }
    }

    /// `UserDefaults` key for the address picked on Home. Scoped by user so two
    /// accounts on the same device don't share a selection.
    private var selectedAddressKey: String? {
        userProvider.currentUser.map { "home.selectedAddress.\($0.userId)" }
    }

    /// Keeps the selection valid whenever the list changes: the same address if it
    /// still exists, then the one saved on the device, otherwise the principal one.
    private func syncSelectedAddress() {
        let addresses = addressProvider.addresses
        if let selectedAddress, addresses.contains(selectedAddress) { return }

        if let key = selectedAddressKey,
           let savedIdentifier = UserDefaults.standard.string(forKey: key),
           let saved = addresses.first(where: { $0.identifier == savedIdentifier }) {
            selectedAddress = saved
            return
        }
        selectedAddress = addressProvider.principal
    }

    /// Stores the selected address's `identifier` (the alias the backend uses as its id).
    private func saveSelectedAddress(_ address: FatumAddress?) {
        guard let key = selectedAddressKey else { return }
        if let address {
            UserDefaults.standard.set(address.identifier, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func makePrincipal(_ address: FatumAddress) {
        Task {
            if await addressProvider.makePrincipal(alias: address.identifier) {
                showMessage("Dirección principal actualizada")
            } else {
                showMessage(addressProvider.error ?? "Error al actualizar la dirección principal")
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
    let provider = UserProvider()
    HomeView()
        .environment(provider)
}
