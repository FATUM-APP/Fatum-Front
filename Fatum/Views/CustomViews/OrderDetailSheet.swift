//
//  OrderDetailSheet.swift
//  Fatum
//

import SwiftUI

/// Everything about one order from `GET /order/{id}`: service, status, booking,
/// price, both parties, delivery address, answers, requirements, the three
/// confirmations and the reason. Opened from the info button of `OrderCardView`
/// and from the calendar's `BookedSlotCard`s.
///
/// `initialDetail` shows right away (e.g. the calendar already loaded it) and
/// the order still reloads; without it the sheet shows a spinner first.
struct OrderDetailSheet: View {
    let orderId: String
    var initialDetail: FatumOrderDetail? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var orderProvider = OrderProvider()
    @State private var detail: FatumOrderDetail? = nil
    @State private var loadFailed = false

    private let locale = CalendarDate.locale

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .screenPadding()
            }
            .background(.brandSecondary)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Detalle de la orden")
                        .fatumStyle(.subheader)
                        .foregroundStyle(.text)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.text)
                    }
                    .accessibilityLabel("Cerrar")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            if detail == nil { detail = initialDetail }
            await load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let detail {
            details(detail)
        } else if loadFailed {
            VStack(spacing: layout.internalSpacing) {
                Image(systemName: "exclamationmark.triangle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .foregroundStyle(.brandPrimary)

                Text("No pudimos cargar la orden")
                    .fatumStyle(.subheader)
                    .foregroundStyle(.text)
                    .multilineTextAlignment(.center)

                Button("Reintentar") {
                    Task { await load() }
                }
                .buttonStyle(.fatumButton(variant: .outlined))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, layout.padding)
        } else {
            ProgressView()
                .tint(.brandPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, layout.padding)
        }
    }

    // MARK: - Details

    private func details(_ detail: FatumOrderDetail) -> some View {
        VStack(alignment: .leading, spacing: layout.spacingMedium) {
            VStack(alignment: .leading,spacing : layout.spacingSmall){
                Text(detail.serviceTitle)
                    .fatumStyle(.subheader)
                    .foregroundStyle(.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
    
                statusTag(detail.status)
            }
           

            section("Reserva") {
                row("calendar", "Fecha", dateTime(detail.booking))
                if let duration = FatumFormat.estimatedTime(minutes: detail.estimatedTime) {
                    row("clock", "Tiempo estimado", duration)
                }
                row("dollarsign.circle", "Precio", "$\(price(detail.negotiatedPrice))")
                if let started = detail.deliveryStartedAt {
                    row("play.circle", "Entrega iniciada", dateTime(started))
                }
            }

            section("Personas") {
                row("person", "Cliente", "\(detail.clientName) · @\(detail.clientUsername)")
                row("briefcase", "Profesional", "\(detail.providerName) · @\(detail.providerUsername)")
            }

            section("Dirección") {
                row("mappin.and.ellipse", detail.deliveryResidence, [detail.deliveryCity, detail.deliveryState, detail.deliveryCountry]
                    .filter { !$0.isEmpty }
                    .joined(separator: ", "))
            }

            if !detail.answers.isEmpty {
                section("Respuestas") {
                    ForEach(detail.answers.sorted { $0.question < $1.question }, id: \.self) { answer in
                        row("questionmark.bubble", answer.question, answer.answer.sorted().joined(separator: ", "))
                    }
                }
            }

            if let requirements = nonEmpty(detail.requirements) {
                section("Requerimientos") {
                    Text(requirements)
                        .fatumStyle(.body)
                        .foregroundStyle(.text)
                }
            }

            section("Confirmaciones") {
                confirmationRow("Inicio", detail.startConfirmation)
                confirmationRow("Entrega", detail.completionConfirmation)
                confirmationRow("Pago", detail.paymentConfirmation)
            }

            if let reason = nonEmpty(detail.reason) {
                section("Razón") {
                    Text(reason)
                        .fatumStyle(.body)
                        .foregroundStyle(.text)
                }
            }

            Text("Creada el \(dateTime(detail.createdAt)) · Actualizada el \(dateTime(detail.updatedAt))")
                .fatumStyle(.footer)
                .foregroundStyle(.text.opacity(0.6))
        }
    }

    // MARK: - Parts

    /// A bordered group with its title above, like `OrderCardView`.
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: layout.internalSpacing) {
            Text(title)
                .fatumStyle(.body)
                .fontWeight(.medium)
                .foregroundStyle(.text)

            VStack(alignment: .leading, spacing: layout.internalSpacing) {
                content()
            }
            .padding(layout.internalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
                    .stroke(Color.border, lineWidth: 1)
            )
        }
    }

    private func row(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(alignment: .center, spacing: layout.internalSpacing) {
            Image(systemName: icon)
                .foregroundStyle(.text)
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .fatumStyle(.footer)
                    .foregroundStyle(.text.opacity(0.7))
                Text(value)
                    .fatumStyle(.caption)
                    .foregroundStyle(.text)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func confirmationRow(_ stage: String, _ confirmation: FatumOrder.DualConfirmation) -> some View {
        HStack(spacing: layout.internalSpacing) {
            Text(stage)
                .fatumStyle(.body)
                .foregroundStyle(.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            answer("Cliente", confirmation.byCustomer)
            answer("Profesional", confirmation.byProvider)
        }
    }

    /// Confirmed, denied or not answered yet.
    private func answer(_ party: String, _ value: Bool?) -> some View {
        let (icon, text): (String, String) = switch value {
        case true?: ("checkmark.circle.fill", "confirmó")
        case false?: ("xmark.circle.fill", "negó")
        case nil: ("clock", "pendiente")
        }
        return Label(party, systemImage: icon)
            .fatumStyle(.footer)
            .foregroundStyle(value == true ? Color.fatumAccent : Color.text)
            .accessibilityLabel("\(party) \(text)")
    }

    private func statusTag(_ status: String) -> some View {
        let name = OrderStatus(rawValue: status)?.displayName ?? status
        return Text(name)
            .fatumStyle(.footer)
            .foregroundStyle(.brandPrimary)
            .lineLimit(1)
            .padding(layout.smallPadding)
            .background(.secondaryContainer, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("Estado \(name)")
    }

    // MARK: - Helpers

    /// "25 de noviembre de 2026, 2:30 p. m.", or the raw value if it can't be read.
    private func dateTime(_ value: String) -> String {
        guard let date = CalendarDate.date(from: value) else { return value }
        return date.formatted(.dateTime.day().month(.wide).year().hour().minute().locale(locale))
    }

    private func price(_ value: String) -> String {
        Decimal(string: value).map(FatumFormat.price) ?? value
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// A failure with a detail already shown keeps it instead of the error state.
    private func load() async {
        loadFailed = false
        do {
            detail = try await orderProvider.fetchDetail(id: orderId)
        } catch {
            guard !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return }
            print("DEBUG order detail \(orderId) error: \(error)")
            loadFailed = detail == nil
        }
    }
}

#Preview {
    Color.brandSecondary
        .sheet(isPresented: .constant(true)) {
            OrderDetailSheet(orderId: "preview")
        }
}
