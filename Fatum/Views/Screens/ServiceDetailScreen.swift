//
//  ServiceDetailScreen.swift
//  Fatum
//

import SwiftUI

/// Opens a published service in `ServiceReviewScreen`. It downloads the photos
/// and builds a `ServiceDraft` first.
///
/// - `.edit`: the provider tapped one of their services in "Mis servicios".
///   "Guardar cambios" sends `PUT /catalog/item/update` and goes back, where the list reloads.
/// - `.client`: a client tapped a service on Home. Nothing can be edited.
///
/// `Route` is the route type of the stack that pushed it (`ProviderRoute` or `ProfileRoute`).
struct ServiceDetailScreen<Route: Hashable>: View {
    let service: FatumItem
    let mode: ServiceReviewScreen.Mode

    @Environment(Router<Route>.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Root category whose sub-categories are matched against the service's category.
    @State private var catalogProvider = CatalogProvider(root: "Belleza")
    @State private var draft = ServiceDraft()
    @State private var isLoading = true
    @State private var isSubmitting = false

    @State private var showToast = false
    @State private var toastMessage: String = ""

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(.brandPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.brandSecondary)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                router.pop()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .foregroundStyle(.text)
                            }
                        }
                    }
            } else {
                ServiceReviewScreen(
                    draft: $draft,
                    rootName: catalogProvider.root,
                    categories: catalogProvider.categories.filter(\.isAble),
                    mode: mode,
                    providerName: service.providerName,
                    isSubmitting: isSubmitting,
                    onBack: { router.pop() },
                    onPublish: save
                )
            }
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
        .navigationBarBackButtonHidden(true)
        .task {
            await load()
        }
    }

    // MARK: - Actions

    /// Downloads the photos and the categories in parallel, then fills the draft.
    private func load() async {
        async let images = loadImages()
        async let categoriesLoaded: Void = catalogProvider.loadCategories()
        let (downloadedImages, _) = await (images, categoriesLoaded)

        // The service stores the category name; the chip needs the full category (slug and logo).
        let category = catalogProvider.categories.first {
            $0.name.caseInsensitiveCompare(service.category) == .orderedSame
        }
        draft = ServiceDraft(item: service, category: category, images: downloadedImages)
        isLoading = false
    }

    private func loadImages() async -> [UIImage] {
        guard let id = service.id else { return [] }
        return await catalogProvider.loadImages(itemId: id)
    }

    private func save() {
        guard let id = service.id else {
            showMessage("No se encontró el servicio")
            return
        }
        guard let request = draft.updateRequest(id: id) else {
            showMessage("Revisa la información del servicio: necesita título y al menos \(ServiceDraft.minPhotos) foto")
            return
        }

        isSubmitting = true

        Task {
            // Scaling and encoding up to 10 photos takes a moment, so it runs after the spinner shows.
            let images = draft.imageData
            let success = await catalogProvider.updateItem(request, images: images)
            isSubmitting = false

            if success {
                // Back to "Mis servicios", which reloads its list.
                router.pop()
            } else {
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
    NavigationStack {
        ServiceDetailScreen<ProviderRoute>(
            service: FatumItem(
                id: "1",
                title: "Corte y cepillado profesional",
                description: "Corte personalizado con lavado y cepillado.",
                providerName: "Camilo Castaño",
                providerUsername: "camilo",
                basePrice: "28000",
                priceType: "HOURLY",
                isNegotiable: true,
                defaultEstimatedTime: 90,
                jobType: "PRESENCIAL",
                category: "Peluquería"
            ),
            mode: .client
        )
    }
    .environment(Router<ProviderRoute>())
    .environment(UserProvider())
}
