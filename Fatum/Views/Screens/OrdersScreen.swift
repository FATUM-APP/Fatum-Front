//
//  OrdersScreen.swift
//  Fatum
//

import SwiftUI

/// The signed-in user's orders, opened from the orders icon on Home.
/// Professionals see the orders they provide and clients the ones they
/// requested (`OrderProvider`). A segmented control filters them by
/// "Pendientes", "Completados" and "Revisión".
///
/// `Route` is the route type of the stack that pushed it (`ProfileRoute` from Home).
struct OrdersScreen<Route: Hashable>: View {
    @Environment(Router<Route>.self) private var router
    @Environment(UserProvider.self) private var userProvider
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var orderProvider = OrderProvider()
    @State private var filter: OrderFilter = .pending
    @State private var showToast = false
    @State private var toastMessage: String = ""

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var isProfessional: Bool {
        userProvider.currentUser?.role == .professional
    }

    private var visibleOrders: [FatumOrder] {
        orderProvider.orders(in: filter)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layout.spacingMedium) {
                Picker("Filtro", selection: $filter) {
                    ForEach(OrderFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                content
            }
            .screenPadding()
        }
        .background(.brandSecondary)
        .refreshable {
            await loadOrders()
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
                Text("Mis órdenes")
                    .fatumStyle(.subheader)
                    .foregroundStyle(.text)
            }
        }
        .task {
            await loadOrders()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if orderProvider.isLoading && orderProvider.orders.isEmpty {
            ProgressView()
                .tint(.brandPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, layout.externalSpacing)
        } else if orderProvider.loadFailed {
            VStack(spacing: layout.internalSpacing) {
                placeholder(
                    icon: "exclamationmark.triangle",
                    title: "No pudimos cargar tus órdenes",
                    message: orderProvider.error ?? "Revisa tu conexión e inténtalo de nuevo"
                )

                Button("Reintentar") {
                    Task { await loadOrders() }
                }
                .buttonStyle(.fatumButton(variant: .outlined))
            }
            .frame(maxWidth: .infinity)
        } else if visibleOrders.isEmpty {
            placeholder(
                icon: "tray",
                title: "No tienes órdenes \(filter.rawValue.lowercased())",
                message: nil
            )
        } else {
            VStack(spacing: layout.internalSpacing) {
                ForEach(visibleOrders, id: \.self) { order in
                    card(for: order)
                }
            }
        }
    }

    /// For now every order shows the same buttons per role: "Aceptar" and
    /// "Rechazar" for professionals; "Entregado" (disabled) and "Cancelar" for clients.
    /// TODO: pick them from the status and the orders' `DualConfirmation`s.
    private func card(for order: FatumOrder) -> some View {
        OrderCardView(order: order, onInfo: { showInfo(for: order) }) {
            if isProfessional {
                actionButton("Aceptar")
                actionButton("Rechazar")
            } else {
                actionButton("Entregado")
                    .disabled(true)
                    .opacity(0.5)
                actionButton("Cancelar")
            }
        }
    }

    private func actionButton(_ title: String) -> some View {
        Button(title) {
            // TODO: call the backend once the order actions exist.
            showMessage("Función en construcción")
        }
        .buttonStyle(.fatumButton(variant: .compact))
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
        .padding(.vertical, layout.externalSpacing)
    }

    // MARK: - Actions

    private func loadOrders() async {
        guard let user = userProvider.currentUser else { return }
        await orderProvider.loadOrders(userId: user.userId, role: user.role)
    }

    /// TODO: show the order's details.
    private func showInfo(for order: FatumOrder) {}

    private func showMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
    }
}

#Preview {
    NavigationStack {
        OrdersScreen<ProfileRoute>()
    }
    .environment(Router<ProfileRoute>())
    .environment(UserProvider())
}
