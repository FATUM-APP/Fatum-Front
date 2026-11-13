//
//  OrdersScreen.swift
//  Fatum
//

import SwiftUI

/// The signed-in user's orders from one side: `.PROVIDER` the ones they
/// provide, `.CUSTOMER` the ones they hired. Opened from the orders icon on
/// Home (professionals pick the side by holding it) and, as `.CUSTOMER`, after
/// hiring a service. A segmented control filters them by "Pendientes",
/// "Completados" and "Revisión".
///
/// While it's open it listens to `/realtime/orders`, so new orders and changes
/// made by the other party show up without reloading. Each card's slider and
/// cancel button come from its status and both parties' confirmations
/// (`slider(for:)` and `canCancel(_:)`).
///
/// `Route` is the route type of the stack that pushed it (`ProfileRoute` from Home).
struct OrdersScreen<Route: Hashable>: View {
    let side: ConfirmingParty

    @Environment(Router<Route>.self) private var router
    @Environment(UserProvider.self) private var userProvider
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var orderProvider = OrderProvider()
    @State private var filter: OrderFilter = .pending
    @State private var reasonRequest: ReasonRequest? = nil
    /// The order being accepted, waiting for its estimated time in `OrderAcceptSheet`.
    @State private var orderToAccept: FatumOrder? = nil
    /// The order whose reason is shown in the "Ver razón" alert.
    @State private var reasonToShow: FatumOrder? = nil
    @State private var showToast = false
    @State private var toastMessage: String = ""

    /// Something the user can do on an order card.
    private enum OrderAction: Hashable {
        case accept
        case reject
        case cancel
        case confirm(OrderStage)
        case deny(OrderStage)
        /// "Iniciar" while the provider hasn't answered: shown to the client but never runs.
        case startPreview
    }

    /// The slider of an order card: the right side runs `positive`, the left `negative`.
    private struct SliderSpec {
        let positiveTitle: String
        let positive: OrderAction
        var negativeTitle: String? = nil
        var negative: OrderAction? = nil
        var isEnabled: Bool = true
    }

    /// An action waiting for its reason in `OrderReasonSheet`.
    private struct ReasonRequest: Identifiable {
        let id = UUID()
        let order: FatumOrder
        let action: OrderAction
        let title: String
        let options: [String]
    }

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var isProvider: Bool {
        side == .PROVIDER
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
        .animation(.easeInOut, value: orderProvider.orders)
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
                VStack(spacing: 0) {
                    Text("Mis órdenes")
                        .fatumStyle(.subheader)
                        .foregroundStyle(.text)

                    // Only professionals have both sides, so only they need the reminder.
                    if userProvider.currentUser?.role == .professional {
                        Text(isProvider ? "Como profesional" : "Como cliente")
                            .fatumStyle(.footer)
                            .foregroundStyle(.text)
                    }
                }
            }
        }
        .task {
            await loadOrders()
        }
        // Cancelled when the screen goes away, which closes the stream.
        .task {
            await orderProvider.listenForEvents()
        }
        .sheet(item: $reasonRequest) { request in
            OrderReasonSheet(
                title: request.title,
                options: request.options,
                // A cancellation's reason gets the prefix later, so it has less room.
                maxLength: OrderProvider.reasonMaxLength - (request.action == .cancel ? cancelPrefix.count : 0),
                onConfirm: { reason in run(request.action, on: request.order, reason: reason) }
            )
        }
        .sheet(item: $orderToAccept) { order in
            OrderAcceptSheet(initialMinutes: order.estimatedTime) { minutes in
                run(.accept, on: order, estimatedTime: minutes)
            }
        }
        .alert(
            "Razón",
            isPresented: Binding(
                get: { reasonToShow != nil },
                set: { if !$0 { reasonToShow = nil } }
            ),
            presenting: reasonToShow
        ) { _ in
            Button("Cerrar", role: .cancel) {}
        } message: { order in
            Text(order.reason ?? "")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if orderProvider.isLoading && orderProvider.orders.isEmpty {
            ProgressView()
                .tint(.brandPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, layout.padding)
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
                ForEach(visibleOrders) { order in
                    card(for: order)
                }
            }
        }
    }

    @ViewBuilder
    private func card(for order: FatumOrder) -> some View {
        let isBusy = order.id.map(orderProvider.busyOrderIds.contains) ?? false
        let onCancel: (() -> Void)? = canCancel(order) ? { tap(.cancel, on: order) } : nil
        let onShowReason: (() -> Void)? = hasReason(order) ? { reasonToShow = order } : nil

        if let spec = slider(for: order) {
            OrderCardView(
                order: order,
                onInfo: { showInfo(for: order) },
                onCancel: onCancel,
                isCancelEnabled: !isBusy,
                onShowReason: onShowReason
            ) {
                SlideToActionView(
                    positiveTitle: spec.positiveTitle,
                    negativeTitle: spec.negativeTitle,
                    isEnabled: spec.isEnabled && !isBusy,
                    onPositive: { tap(spec.positive, on: order) },
                    onNegative: { spec.negative.map { tap($0, on: order) } }
                )
            }
        } else {
            OrderCardView(
                order: order,
                onInfo: { showInfo(for: order) },
                onCancel: onCancel,
                isCancelEnabled: !isBusy,
                onShowReason: onShowReason
            ) {
                EmptyView()
            }
        }
    }

    private func placeholder(icon: String, title: String, message: String?) -> some View {
        VStack(spacing: layout.internalSpacing) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundStyle(.brandPrimary)

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

    // MARK: - Order Flow

    /// The slider of an order for the signed-in user (right = positive, left = negative):
    /// - PENDING: the provider accepts or rejects; the client sees "Iniciar",
    ///   which can't slide yet.
    /// - ACCEPTED: both confirm the start or report it wasn't delivered.
    /// - DELIVERING: both confirm the delivery or report it wasn't delivered.
    /// - COMPLETED: both confirm the payment or report a problem, until both confirmed.
    /// - Every other status: none.
    ///
    /// Once the user answered a stage, the slider stays visible but disabled
    /// until the other party answers too.
    private func slider(for order: FatumOrder) -> SliderSpec? {
        guard let status = order.orderStatus else { return nil }

        switch status {
        case .PENDING:
            return isProvider
                ? SliderSpec(positiveTitle: "Aceptar", positive: .accept, negativeTitle: "Rechazar", negative: .reject)
                : SliderSpec(positiveTitle: "Iniciar", positive: .startPreview, isEnabled: false)
        case .ACCEPTED:
            return SliderSpec(
                positiveTitle: "Empieza la entrega",
                positive: .confirm(.START),
                negativeTitle: "No entregado",
                negative: .deny(.START),
                isEnabled: canAnswer(order, stage: .START)
            )
        case .DELIVERING:
            return SliderSpec(
                positiveTitle: "Entregado",
                positive: .confirm(.COMPLETION),
                negativeTitle: "No entregado",
                negative: .deny(.COMPLETION),
                isEnabled: canAnswer(order, stage: .COMPLETION)
            )
        case .COMPLETED:
            guard !isPaymentConfirmed(order) else { return nil }
            return SliderSpec(
                positiveTitle: "Confirmar pago",
                positive: .confirm(.PAYMENT),
                negativeTitle: "Problema con el pago",
                negative: .deny(.PAYMENT),
                isEnabled: canAnswer(order, stage: .PAYMENT)
            )
        case .REJECTED, .NOT_DELIVERED, .CANCELLED, .DISPUTED, .SOLVED, .REFUNDED:
            return nil
        }
    }

    /// The client can cancel while the order waits for the provider; both can
    /// once it's accepted. From DELIVERING on, nobody can.
    private func canCancel(_ order: FatumOrder) -> Bool {
        switch order.orderStatus {
        case .PENDING: !isProvider
        case .ACCEPTED: true
        default: false
        }
    }

    /// Any order with a reason (rejected, cancelled, not delivered…) shows the "see reason" icon.
    private func hasReason(_ order: FatumOrder) -> Bool {
        !(order.reason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    /// `false` once the user confirmed or denied `stage`, so they can't answer twice.
    private func canAnswer(_ order: FatumOrder, stage: OrderStage) -> Bool {
        order.answer(of: side, for: stage) == nil
    }

    private func isPaymentConfirmed(_ order: FatumOrder) -> Bool {
        order.paymentConfirmation.byCustomer == true && order.paymentConfirmation.byProvider == true
    }

    // MARK: - Actions

    /// Confirming runs right away; accepting asks for the estimated time, and
    /// rejecting, cancelling and denying ask for the reason first.
    private func tap(_ action: OrderAction, on order: FatumOrder) {
        switch action {
        case .accept:
            orderToAccept = order
        case .confirm:
            run(action, on: order)
        case .reject:
            reasonRequest = ReasonRequest(
                order: order,
                action: action,
                title: "Rechazar orden",
                options: ["No tengo disponibilidad ese día", "No atiendo en esa zona", "La solicitud no se ajusta al servicio"]
            )
        case .cancel:
            reasonRequest = ReasonRequest(
                order: order,
                action: action,
                title: "Cancelar orden",
                options: isProvider
                    ? ["No tengo disponibilidad", "Tuve una emergencia", "No puedo llegar al lugar"]
                    : ["Ya no necesito el servicio", "Cambié de fecha u hora", "Encontré otra opción"]
            )
        case .deny(let stage):
            reasonRequest = ReasonRequest(
                order: order,
                action: action,
                title: denyTitle(for: stage),
                options: denyOptions(for: stage)
            )
        case .startPreview:
            break
        }
    }

    /// `estimatedTime` is only used when accepting, `reason` when rejecting, cancelling or denying.
    private func run(_ action: OrderAction, on order: FatumOrder, reason: String? = nil, estimatedTime: Int? = nil) {
        Task {
            let success: Bool
            switch action {
            case .accept:
                guard let estimatedTime else { return }
                success = await orderProvider.accept(order, estimatedTime: estimatedTime)
            case .reject:
                success = await orderProvider.reject(order, reason: reason ?? "")
            case .cancel:
                success = await orderProvider.cancel(order, reason: cancelPrefix + (reason ?? ""))
            case .confirm(let stage):
                success = await orderProvider.confirm(stage, for: order)
            case .deny(let stage):
                success = await orderProvider.deny(stage, for: order, reason: reason ?? "")
            case .startPreview:
                return
            }

            // The card already reflects the change; only errors get a toast.
            if !success {
                showMessage(orderProvider.error ?? "No se pudo actualizar la orden")
            }
        }
    }

    /// Tells the backend who cancelled: "CLIENT: …" or "PROFESSIONAL: …".
    private var cancelPrefix: String {
        isProvider ? "PROFESSIONAL: " : "CLIENT: "
    }

    private func denyTitle(for stage: OrderStage) -> String {
        switch stage {
        case .START, .COMPLETION: "No entregado"
        case .PAYMENT: "Problema con el pago"
        }
    }

    private func denyOptions(for stage: OrderStage) -> [String] {
        switch (stage, isProvider) {
        case (.START, true): ["El cliente no estaba disponible", "No pude acceder al lugar"]
        case (.START, false): ["El profesional no llegó", "El profesional llegó muy tarde"]
        case (.COMPLETION, true): ["El cliente no permitió terminar", "Faltaron condiciones para terminar"]
        case (.COMPLETION, false): ["El servicio no se terminó", "El resultado no fue el acordado"]
        case (.PAYMENT, true): ["No recibí el pago", "El monto no es el acordado"]
        case (.PAYMENT, false): ["Hubo un problema con el pago", "El monto no es el acordado"]
        }
    }

    private func loadOrders() async {
        guard let user = userProvider.currentUser else { return }
        await orderProvider.loadOrders(userId: user.userId, side: side)
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
        OrdersScreen<ProfileRoute>(side: .CUSTOMER)
    }
    .environment(Router<ProfileRoute>())
    .environment(UserProvider())
}
