//
//  ServiceCardView.swift
//  Fatum
//

import SwiftUI

/// A bordered card for one service: its cover photo on the left and, on the
/// right, the title, rating, price and a "job type · estimated time" line; the
/// tags run below both. Styled like `AddressCardView`.
///
/// Passing `onSetActive` marks the card as one of the provider's own services:
/// it adds a colored status tag and a trailing "more" menu to activate or
/// deactivate the service (only for active or inactive services).
struct ServiceCardView: View {
    let service: FatumItem
    /// First photo of the service (`CatalogProvider.coverImageURLs`); a placeholder shows while it's `nil`.
    var imageURL: String? = nil
    /// Called with `true` to activate and `false` to deactivate the service.
    var onSetActive: ((Bool) -> Void)? = nil
    /// Shows a filled heart at the top right (clients only; the provider's own cards have the menu there).
    var isFavorite: Bool = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    /// Optional so the card still works (with a dash) where no provider is injected, like previews.
    @Environment(ScoreProvider.self) private var scoreProvider: ScoreProvider?

    private let imageSize: CGFloat = 110
    private let imageCornerRadius: CGFloat = 12
    private let tagCornerRadius: CGFloat = 12

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    /// "Presencial · 1h 30m", or "Presencial · N/A" when there is no estimated time.
    private var detailsLine: String {
        "\(service.jobTypeDisplay) · \(service.estimatedTimeDisplay ?? "N/A")"
    }

    /// The service's average rating, or a dash until it loads.
    private var ratingText: String {
        guard let serviceId = service.id, let average = scoreProvider?.serviceAverages[serviceId] else { return "—" }
        return average.formatted(.number.precision(.fractionLength(1)))
    }

    /// The status tag shows only on the provider's own services.
    private var status: ServiceStatus? {
        onSetActive == nil ? nil : service.serviceStatus
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.internalSpacing) {
            HStack(alignment: .center, spacing: layout.internalSpacing) {
                coverImage

                VStack(alignment: .leading, spacing: layout.tiny) {
                    Text(service.title)
                        .fatumStyle(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.text)
                        .lineLimit(2)

                    Label(ratingText, systemImage: "star.fill")
                        .fatumStyle(.footer)
                        .fontWeight(.bold)
                        .foregroundStyle(.text)
                        .accessibilityLabel("Calificación \(ratingText) de 5")

                    HStack(alignment: .firstTextBaseline, spacing: layout.tiny) {
                        // Same text style as the price, so the icon scales with it.
                        Image(systemName: "dollarsign")
                            .fatumStyle(.caption)
                            .foregroundStyle(.text)
                            .accessibilityHidden(true)

                        Text(service.formattedPrice)
                            .fatumStyle(.caption)
                            .foregroundStyle(.text)

                        Text(service.priceUnitLabel)
                            .fatumStyle(.caption)
                            .foregroundStyle(.text)
                    }

                    Text(detailsLine)
                        .fatumStyle(.footer)
                        .foregroundStyle(.text)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if onSetActive != nil {
                    actionsMenu
                        .frame(maxHeight: .infinity, alignment: .top)
                } else if isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.fatumAccent)
                        .padding(layout.smallPadding)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityLabel("Favorito")
                }
            }
            // As tall as the photo (or the text, if longer), so the menu sits at the top.
            .fixedSize(horizontal: false, vertical: true)
            .animation(.spring, value: isFavorite)

            // Tags span the whole card width, below the photo and the information.
            FlowLayout(spacing: layout.tiny) {
                tag(service.category, foreground: .brandPrimary, background: .secondaryContainer)

                if let status {
                    ServiceStatusTag(status: status)
                }
            }
        }
        .padding(layout.internalPadding)
        // Opaque, so swipe actions don't show through the card while it slides.
        .background(.brandSecondary)
        .clipShape(RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
                .stroke(Color.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        // The menu is merged into the card for VoiceOver, so its action is exposed here too.
        .accessibilityActions {
            if let onSetActive, let status, status.canToggleActive {
                let activate = status == .INACTIVE
                Button(activate ? "Activar" : "Desactivar") { onSetActive(activate) }
            }
        }
        // Fetched once per service; later appearances reuse the cached score.
        .task(id: service.id) {
            guard let serviceId = service.id else { return }
            await scoreProvider?.loadServiceScore(serviceId: serviceId)
        }
    }

    private func tag(_ text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .fatumStyle(.footer)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(layout.smallPadding)
            .background(background, in: RoundedRectangle(cornerRadius: tagCornerRadius))
    }

    /// "Activar" for inactive services, "Desactivar" for active ones. Services in
    /// review or suspended can't be changed, so the menu is disabled for them.
    private var actionsMenu: some View {
        let canToggle = status?.canToggleActive ?? false
        return Menu {
            if status == .INACTIVE {
                Button {
                    onSetActive?(true)
                } label: {
                    Label("Activar", systemImage: "checkmark.circle")
                }
            } else if status == .ACTIVE {
                Button(role: .destructive) {
                    onSetActive?(false)
                } label: {
                    Label("Desactivar", systemImage: "pause.circle")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .foregroundStyle(.text)
                .opacity(canToggle ? 1 : 0.3)
                .padding(layout.smallPadding)
                .contentShape(Rectangle())
        }
        .disabled(!canToggle)
    }

    private var coverImage: some View {
        AsyncImage(url: imageURL.flatMap(URL.init(string:))) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.primaryContainer.opacity(0.25))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.brandPrimary.opacity(0.5))
                    )
            }
        }
        .frame(width: imageSize, height: imageSize)
        .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius))
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 15) {
        ServiceCardView(
            service: FatumItem(
                id: "1",
                title: "Corte y cepillado profesional",
                description: nil,
                providerId: "p1",
                providerName: "Camilo Castaño",
                providerUsername: "camilo",
                basePrice: "28000",
                priceType: "HOURLY",
                isNegotiable: true,
                defaultEstimatedTime: 90,
                jobType: "PRESENCIAL",
                category: "Peluquería",
                status: "ACTIVE"
            ),
            onSetActive: { _ in }
        )

        ServiceCardView(
            service: FatumItem(
                id: "2",
                title: "Manicure",
                description: nil,
                providerId: "p1",
                providerName: "Camilo Castaño",
                providerUsername: "camilo",
                basePrice: "35000",
                priceType: "FIXED",
                isNegotiable: false,
                defaultEstimatedTime: nil,
                jobType: "PRESENCIAL",
                category: "Uñas"
            )
        )
    }
    .padding(20)
    .background(.brandSecondary)
}
