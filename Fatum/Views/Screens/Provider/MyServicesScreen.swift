//
//  MyServicesScreen.swift
//  Fatum
//

import SwiftUI

/// Root of the "Mis servicios" tab for professionals. Owns the `Router<ProviderRoute>`
/// and shares it with every screen pushed in this tab.
///
/// "Contratar" opens Home, "Mis Favoritos" is not available yet, and
/// "+ Ofrecer Servicio" starts `CreateServiceScreen`. Below them, category chips
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
                    HStack {
                        Button {
                            router.push(.home)
                        } label: {
                            Label("Contratar", systemImage: "bag")
                        }
                        .buttonStyle(.fatumButton(variant: .borderedExpanded))

                        Spacer()

                        Button {
                            showMessage("Función en construcción")
                        } label: {
                            Label("Mis Favoritos", systemImage: "heart")
                        }
                        .buttonStyle(.fatumButton(variant: .borderedExpanded))
                    }
                    

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
            Text("Mis servicios")
                .fatumStyle(.subheader)
                .foregroundStyle(.text)

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
                            imageURL: service.id.flatMap { catalogProvider.coverImageURLs[$0] }
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

            Text(catalogProvider.selectedFilter == .all
                 ? "Aún no ofreces servicios"
                 : "No tienes servicios en esta categoría")
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

    // MARK: - Actions

    private func select(_ filter: CatalogProvider.ServiceFilter) {
        guard let providerId else { return }
        Task { await catalogProvider.selectProviderFilter(filter, providerId: providerId) }
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
