//
//  OrderCardView.swift
//  Fatum
//

import SwiftUI

/// A bordered card for one order. The top part has the service title and the
/// other person's username on the left, the price and an info button on the
/// right, and the order's action buttons below; a divider separates the footer
/// with the booking date, time and estimated time, and the status tag.
/// Styled like `ServiceCardView`.
struct OrderCardView<Actions: View>: View {
    let order: FatumOrder
    var onInfo: () -> Void
    /// Buttons shown under the title; use `.fatumButton(variant: .compact)`.
    @ViewBuilder var actions: Actions

    @Environment(\.horizontalSizeClass) private var sizeClass

    private let tagCornerRadius: CGFloat = 12
    private let dotSize: CGFloat = 8

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    /// "25 de noviembre de 2026", or the raw value if it can't be read.
    private var dateText: String {
        guard let date = order.bookingDate else { return order.booking }
        return date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "es_CO")))
    }

    /// "2:30 p. m. · 1h 30m"; the estimated time is left out when there is none.
    private var timeText: String? {
        let time = order.bookingDate?.formatted(.dateTime.hour().minute().locale(Locale(identifier: "es_CO")))
        let parts = [time, order.estimatedTimeDisplay].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: layout.internalSpacing) {
                HStack(alignment: .top, spacing: layout.internalSpacing) {
                    VStack(alignment: .leading, spacing: layout.internalSpacing) {
                        Text(order.catalogItemTitle)
                            .fatumStyle(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.text)
                            .lineLimit(2)

                        Text(order.counterpartUsername)
                            .fatumStyle(.footer)
                            .foregroundStyle(.text)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("$\(order.formattedPrice)")
                        .fatumStyle(.body)
                        .foregroundStyle(.text)

                    Button(action: onInfo) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.text)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Información de la orden")
                }

                // Left out with `EmptyView` so it doesn't add spacing under the title.
                if Actions.self != EmptyView.self {
                    HStack(spacing: layout.internalSpacing) {
                        actions
                    }
                }
            }
            .padding(layout.internalPadding)

            Divider()
                .overlay(Color.border)

            HStack(spacing: layout.internalSpacing) {
                VStack(alignment: .leading, spacing: layout.internalSpacing) {
                    Label(dateText, systemImage: "calendar")
                        .fatumStyle(.footer)
                        .foregroundStyle(.text)
                        .lineLimit(1)

                    if let timeText {
                        Label(timeText, systemImage: "clock")
                            .fatumStyle(.footer)
                            .foregroundStyle(.text)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let status = order.orderStatus {
                    statusTag(status)
                }
            }
            .padding(layout.internalPadding)
        }
        .clipShape(RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    /// Same look as `ServiceStatusTag`: a dot and a tinted background in the status color.
    private func statusTag(_ status: OrderStatus) -> some View {
        HStack(spacing: layout.spacingSmall) {
            Circle()
                .fill(status.color)
                .frame(width: dotSize, height: dotSize)
                .accessibilityHidden(true)

            Text(status.displayName)
                .fatumStyle(.footer)
                .foregroundStyle(.text)
                .lineLimit(1)
        }
        .padding(layout.smallPadding)
        .background(status.color.opacity(0.18), in: RoundedRectangle(cornerRadius: tagCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estado \(status.displayName)")
    }
}

#Preview {
    VStack(spacing: 15) {
        OrderCardView(
            order: FatumOrder(
                id: "1",
                counterpartUsername: "camilo",
                catalogItemTitle: "Maquillaje profesional",
                booking: "2026-11-25T14:30:00",
                negotiatedPrice: "50000",
                estimatedTime: 50,
                status: "PENDING"
            ),
            onInfo: {}
        ) {
            Button("Aceptar") {}
                .buttonStyle(.fatumButton(variant: .compact))
            Button("Rechazar") {}
                .buttonStyle(.fatumButton(variant: .compact))
        }

        OrderCardView(
            order: FatumOrder(
                id: "2",
                counterpartUsername: "laura",
                catalogItemTitle: "Manicure",
                booking: "2026-11-20T09:00:00.123456",
                negotiatedPrice: "35000",
                estimatedTime: nil,
                status: "COMPLETED"
            ),
            onInfo: {}
        ) {
            EmptyView()
        }
    }
    .padding(20)
    .background(.brandSecondary)
}
