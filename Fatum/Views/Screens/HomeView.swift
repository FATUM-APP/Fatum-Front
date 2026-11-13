//
//  HomeView.swift
//  Fatum
//
//  Created by Camilo Castaño on 5/8/26.
//

import SwiftUI

/// Root of the Home tab for non-professional users. Owns its own `NavigationStack`.
struct HomeView: View {
    /// Home reuses `ProfileRoute` so "Administrar direcciones" can push the same `AddressesScreen`.
    @State private var router = Router<ProfileRoute>()

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeContentView(
                addressesRoute: ProfileRoute.addresses,
                ordersRoute: ProfileRoute.orders,
                serviceRoute: ProfileRoute.serviceDetail
            )
            .profileDestinations()
        }
        .environment(router)
    }
}

/// Content of Home without its own `NavigationStack`, so the same screen works
/// as the root of the Home tab and pushed onto another stack.
///
/// `Route` is the route type of the stack it lives in: navigation goes through
/// `Router<Route>` from the environment: `addressesRoute` is pushed for
/// "Administrar direcciones", `ordersRoute` from the orders icon next to the
/// address selector (with the side to list), and `serviceRoute` when a service card is tapped.
/// When pushed, `showsBackButton` adds a back button that pops the router.
struct HomeContentView<Route: Hashable>: View {
    let addressesRoute: Route
    let ordersRoute: (ConfirmingParty) -> Route
    let serviceRoute: (FatumItem) -> Route
    var showsBackButton: Bool = false

    @Environment(Router<Route>.self) private var router
    @Environment(UserProvider.self) private var userProvider
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Root category whose sub-categories are listed and whose services "Todas" shows.
    @State private var catalogProvider = CatalogProvider(root: "Belleza")
    @State private var addressProvider = AddressProvider()

    /// The address the user is requesting services for. Starts as the one saved on
    /// the device (or the principal one), but picking another here does not change the principal.
    @State private var selectedAddress: FatumAddress? = nil
    @State private var searchText: String = ""

    @State private var showAllCategories = false
    @State private var showAddAddress = false
    @State private var showVoiceSearch = false
    @State private var showToast = false
    @State private var toastMessage: String = ""

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var name: String {
        userProvider.currentUser?.name.capitalized ?? "Usuario"
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
        ZStack {
            Color.brandSecondary
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: layout.externalSpacing) {
                    HStack(alignment: .top, spacing: layout.internalSpacing) {
                        HomeAddressSelector(
                            addresses: addressProvider.addresses,
                            principal: addressProvider.principal,
                            selected: $selectedAddress,
                            isLoading: addressProvider.isLoading,
                            errorMessage: addressProvider.loadFailed ? addressProvider.error : nil,
                            onMakePrincipal: makePrincipal,
                            onAdd: { showAddAddress = true },
                            onManage: { router.push(addressesRoute) },
                            onRetry: { Task { await addressProvider.loadAddresses() } }
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)

                        headerActions
                    }

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
        .navigationBarBackButtonHidden(showsBackButton)
        .toolbar {
            if showsBackButton {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        router.pop()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(.text)
                    }
                }
            }
        }
        // Runs again when coming back from `AddressesScreen`, which has its own provider.
        .task {
            await addressProvider.loadAddresses()
        }
        // Downloads the Spanish speech model ahead of time so voice search is ready.
        .task {
            await VoiceRecorder.prepareSpeechModel()
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
    }

    // MARK: - Header Actions

    private var isProfessional: Bool {
        userProvider.currentUser?.role == .professional
    }

    /// Orders and notifications icons at the top-right, on the address selector's line.
    /// Professionals open the orders they provide; holding the icon lets them
    /// pick the ones they hired instead.
    private var headerActions: some View {
        HStack(spacing: layout.spacingMedium) {
            Button {
                router.push(ordersRoute(isProfessional ? .PROVIDER : .CUSTOMER))
            } label: {
                Image(systemName: "bubble.left.and.bubble.right")
                    .foregroundStyle(.text)
            }
            .accessibilityLabel("Mis órdenes")
            .contextMenu {
                if isProfessional {
                    Button {
                        router.push(ordersRoute(.PROVIDER))
                    } label: {
                        Label("Como profesional", systemImage: "briefcase")
                    }

                    Button {
                        router.push(ordersRoute(.CUSTOMER))
                    } label: {
                        Label("Como cliente", systemImage: "bag")
                    }
                }
            }

            Button {
                showMessage("Función en construcción")
            } label: {
                Image(systemName: "bell")
                    .foregroundStyle(.text)
            }
            .accessibilityLabel("Notificaciones")
        }
        .padding(.top, layout.tiny)
    }

    // MARK: - Greeting

    /// Greeting and search box inside a clean, transparent glass card.
    private var greetingCard: some View {
        VStack(alignment: .leading, spacing: layout.internalSpacing) {
            Text("Hola \(name),")
                .fatumStyle(.premiumHeader)
                .foregroundStyle(.text)

            Text("¿Qué servicio estas buscando el día de hoy?")
                .fatumStyle(.subheader)
                .foregroundStyle(.text)

            ExpandingSearchField(
                placeholder: "Ej. Corte de cabello, manicure…",
                text: $searchText,
                style: .onContainer,
                onMicTapped: { showVoiceSearch = true }
            )
            .padding(.top, layout.spacingSmall)
            .fullScreenCover(isPresented: $showVoiceSearch) {
                VoiceSearchScreen(onAudioRecorded: handleVoiceSearch)
                    .presentationBackground(Color.brandSecondary)
            }
        }
        .padding(layout.internalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
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
                        .foregroundStyle(.text)
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
            VStack(spacing: layout.internalSpacing) {
                ForEach(visibleServices, id: \.self) { service in
                    Button {
                        router.push(serviceRoute(service))
                    } label: {
                        ServiceCardView(
                            service: service,
                            imageURL: service.id.flatMap { catalogProvider.coverImageURLs[$0] }
                        )
                    }
                    .buttonStyle(.plain)
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
                    .foregroundStyle(.text)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, layout.externalSpacing)
    }

    // MARK: - Actions

    /// Receives the voice note recorded by the search field.
    /// TODO: upload the file once the backend endpoint exists, then delete it.
    private func handleVoiceSearch(_ recording: VoiceRecording) {
        let fileURL = recording.fileURL
        let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
        print("Voice search recorded: \(fileURL.lastPathComponent) (\(size) bytes), transcript: \(recording.transcript ?? "none")")
    }

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
            if await !addressProvider.makePrincipal(alias: address.identifier) {
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
