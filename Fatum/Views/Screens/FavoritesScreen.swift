//
//  FavoritesScreen.swift
//  Fatum
//

import SwiftUI

/// The signed-in user's favorite services, laid out like "Mis servicios": a
/// "Todas" chip plus one per category on top, and the services as
/// `ServiceCardView`s below. Tapping a card opens the service; a full swipe to
/// the left removes it from favorites.
///
/// Clients have it as their second tab; professionals open it from Profile
/// ("Servicios favoritos"), where `showsBackButton` adds the back button.
///
/// The favorites come from the shared `FavoritesProvider`, already grouped by
/// category by the backend, so the chips filter them here without new requests.
struct FavoritesScreen: View {
    var showsBackButton: Bool = false

    @Environment(Router<ProfileRoute>.self) private var router
    @Environment(UserProvider.self) private var userProvider
    @Environment(FavoritesProvider.self) private var favoritesProvider
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Chips (sub-categories of the root) and the cover photos of the cards.
    @State private var catalogProvider = CatalogProvider(root: "Belleza")
    @State private var selectedFilter: CatalogProvider.ServiceFilter = .all
    @State private var showToast = false
    @State private var toastMessage = ""

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    /// Only categories the backend marks as enabled are shown.
    private var availableCategories: [FatumCategory] {
        catalogProvider.categories.filter(\.isAble)
    }

    private var visibleFavorites: [FatumItem] {
        switch selectedFilter {
        case .all: favoritesProvider.favorites
        case .category(let category): favoritesProvider.favorites(inCategorySlug: category.slug)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layout.externalSpacing) {
                Text("Mis favoritos")
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

                content
            }
            .screenPadding()
        }
        .favoriteSwipeContainer()
        .background(.brandSecondary)
        .refreshable {
            await loadFavorites()
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
        .animation(.easeInOut, value: visibleFavorites)
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
        .task {
            if catalogProvider.categories.isEmpty {
                await catalogProvider.loadCategories()
            }
        }
        // Each time the list changes (new favorite on Home, a removal…), only the missing covers load.
        .task(id: favoritesProvider.favorites.compactMap(\.id)) {
            await catalogProvider.loadCoverImages(for: favoritesProvider.favorites)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if favoritesProvider.isLoading && favoritesProvider.favorites.isEmpty {
            ProgressView()
                .tint(.brandPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, layout.externalSpacing)
        } else if favoritesProvider.loadFailed {
            VStack(spacing: layout.internalSpacing) {
                placeholder(
                    icon: "exclamationmark.triangle",
                    title: "No pudimos cargar tus favoritos",
                    message: favoritesProvider.error ?? "Revisa tu conexión e inténtalo de nuevo"
                )

                Button("Reintentar") {
                    Task { await loadFavorites() }
                }
                .buttonStyle(.fatumButton(variant: .outlined))
            }
            .frame(maxWidth: .infinity)
        } else if visibleFavorites.isEmpty {
            placeholder(
                icon: "heart",
                title: selectedFilter == .all
                    ? "Aún no tienes favoritos"
                    : "No tienes favoritos en esta categoría",
                message: "Desliza un servicio hacia la derecha en Inicio para guardarlo aquí"
            )
        } else {
            VStack(spacing: layout.internalSpacing) {
                ForEach(visibleFavorites, id: \.self) { service in
                    // A tap gesture, not a `Button`: a cancelled swipe would leave a button dimmed.
                    ServiceCardView(
                        service: service,
                        imageURL: service.id.flatMap { catalogProvider.coverImageURLs[$0] },
                        isFavorite: true
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        router.push(.serviceDetail(service))
                    }
                    .accessibilityAddTraits(.isButton)
                    .favoriteSwipeActions(
                        isFavorite: true,
                        // Removing here takes the card out of the list.
                        removesCard: true,
                        onAdd: {},
                        onRemove: { remove(service) }
                    )
                }
            }
        }
    }

    private func chip(for filter: CatalogProvider.ServiceFilter) -> some View {
        Button {
            selectedFilter = filter
        } label: {
            CategoryChipView(filter: filter, isSelected: selectedFilter == filter)
        }
        .buttonStyle(.plain)
    }

    private func placeholder(icon: String, title: String, message: String?) -> some View {
        VStack(spacing: layout.internalSpacing) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundStyle(.brandPrimary.opacity(0.5))

            Text(title)
                .fatumStyle(.subheader)
                .foregroundStyle(.text)
                .multilineTextAlignment(.center)

            if let message {
                Text(message)
                    .fatumStyle(.body)
                    .foregroundStyle(.text)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, layout.padding)
    }

    // MARK: - Actions

    private func loadFavorites() async {
        guard let clientId = userProvider.currentUser?.userId else { return }
        await favoritesProvider.loadFavorites(clientId: clientId)
    }

    /// The card leaves the list right away; only errors get a toast (and bring it back).
    private func remove(_ service: FatumItem) {
        guard let clientId = userProvider.currentUser?.userId else { return }
        Task {
            if await !favoritesProvider.remove(service, clientId: clientId) {
                showMessage(favoritesProvider.error ?? "No se pudo quitar de favoritos")
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
        FavoritesScreen()
            .profileDestinations()
    }
    .environment(Router<ProfileRoute>())
    .environment(UserProvider())
    .environment(FavoritesProvider())
}
