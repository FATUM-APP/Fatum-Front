//
//  MyServicesScreen.swift
//  Fatum
//

import SwiftUI

/// Root of the "Mis servicios" tab for professionals. Owns the `Router<ProviderRoute>`
/// and shares it with every screen pushed in this tab.
///
/// "+ Ofrecer Servicio" starts `CreateServiceScreen`. Below it, category chips
/// filter the provider's own services, shown as `ServiceCardView`s; tapping one
/// opens it for editing.
struct MyServicesScreen: View {
    @Environment(UserProvider.self) private var userProvider
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var router = Router<ProviderRoute>()
    /// Root category whose sub-categories are the chips.
    @State private var catalogProvider = CatalogProvider(root: "Belleza")
    @State private var showToast = false
    @State private var toastMessage = "Función en construcción"

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var providerId: String? {
        userProvider.currentUser?.userId
    }

    /// Only categories the backend marks as enabled are shown.
    private var availableCategories: [FatumCategory] {
        catalogProvider.categories.filter(\.isAble)
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: layout.internalSpacing) {
                    Button("+ Ofrecer Servicio") {
                        router.push(.createService)
                    }
                    .buttonStyle(.fatumButton(variant: .third))

                    myServicesSection
                        .padding(.top, layout.spacingMedium)
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
            .task {
                if catalogProvider.categories.isEmpty {
                    await catalogProvider.loadCategories()
                }
                if catalogProvider.selectedFilter == nil {
                    select(.all)
                }
            }
            // Back on this screen (e.g. after creating a service): refresh the list.
            .onChange(of: router.path.count) { _, count in
                if count == 0, let filter = catalogProvider.selectedFilter {
                    select(filter)
                }
            }
            .providerDestinations()
        }
        .environment(router)
    }

    // MARK: - My Services

    private var myServicesSection: some View {
        VStack(alignment: .leading, spacing: layout.spacingMedium) {
            HStack {
                Text("Mis servicios")
                    .fatumStyle(.subheader)
                    .foregroundStyle(.text)

                Spacer()

                statusFilterMenu
            }

            if !availableCategories.isEmpty {
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

            servicesList
        }
    }

    /// Shop-style "Filtrar" control in the section header: a menu with a single
    /// choice of status. When a status is picked, the label shows it and the icon fills.
    private var statusFilterMenu: some View {
        let selection = Binding<ServiceStatus?>(
            get: { catalogProvider.statusFilter },
            set: { select(catalogProvider.selectedFilter ?? .all, status: $0) }
        )
        let isFiltering = catalogProvider.statusFilter != nil

        return Menu {
            Picker("Estado", selection: selection) {
                Text("Todos").tag(ServiceStatus?.none)
                ForEach(ServiceStatus.allCases, id: \.self) { status in
                    Text(status.filterName).tag(Optional(status))
                }
            }
        } label: {
            Label(
                catalogProvider.statusFilter?.filterName ?? "Filtrar",
                systemImage: isFiltering
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
            .fatumStyle(.footer)
            .foregroundStyle(isFiltering ? .brandSecondary : .brandPrimary)
            .padding(layout.smallPadding)
            .background(
                Capsule().fill(isFiltering ? Color.brandPrimary : Color.clear)
            )
            .overlay(
                Capsule().stroke(Color.brandPrimary, lineWidth: 1)
            )
        }
        .accessibilityLabel("Filtrar por estado")
        .accessibilityValue(catalogProvider.statusFilter?.filterName ?? "Todos")
    }

    private func chip(for filter: CatalogProvider.ServiceFilter) -> some View {
        Button {
            select(filter)
        } label: {
            CategoryChipView(filter: filter, isSelected: catalogProvider.selectedFilter == filter)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var servicesList: some View {
        if catalogProvider.isLoadingServices {
            ProgressView()
                .tint(.brandPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, layout.externalSpacing)
        } else if catalogProvider.services.isEmpty {
            emptyState
        } else {
            VStack(spacing: layout.internalSpacing) {
                ForEach(catalogProvider.services, id: \.self) { service in
                    Button {
                        router.push(.editService(service))
                    } label: {
                        ServiceCardView(
                            service: service,
                            imageURL: service.id.flatMap { catalogProvider.coverImageURLs[$0] },
                            onSetActive: { active in setActive(active, for: service) }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: layout.internalSpacing) {
            Image(systemName: "briefcase")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundStyle(.brandPrimary.opacity(0.5))

            Text(emptyStateTitle)
                .fatumStyle(.subheader)
                .foregroundStyle(.text)
                .multilineTextAlignment(.center)

            Text("Toca \"+ Ofrecer Servicio\" para publicar uno")
                .fatumStyle(.body)
                .foregroundStyle(.text)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, layout.externalSpacing)
    }

    private var emptyStateTitle: String {
        if catalogProvider.statusFilter != nil {
            "No tienes servicios con este estado"
        } else if catalogProvider.selectedFilter == .all {
            "Aún no ofreces servicios"
        } else {
            "No tienes servicios en esta categoría"
        }
    }

    // MARK: - Actions

    /// Loads the services of `filter`, keeping the current status filter.
    private func select(_ filter: CatalogProvider.ServiceFilter) {
        select(filter, status: catalogProvider.statusFilter)
    }

    private func select(_ filter: CatalogProvider.ServiceFilter, status: ServiceStatus?) {
        guard let providerId else { return }
        Task { await catalogProvider.selectProviderFilter(filter, status: status, providerId: providerId) }
    }

    private func setActive(_ active: Bool, for service: FatumItem) {
        Task {
            // The card's status tag already shows the change; only errors get a toast.
            if await !catalogProvider.setActive(active, for: service) {
                showMessage(catalogProvider.error ?? "No se pudo actualizar el servicio")
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
    MyServicesScreen()
        .environment(UserProvider())
}
