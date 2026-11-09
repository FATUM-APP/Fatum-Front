//
//  ServiceCardView.swift
//  Fatum
//

import SwiftUI

/// A bordered card for one service: its cover photo on the left and, on the
/// right, the title, rating, price and tags for category, job type and
/// estimated time. Styled like `AddressCardView`.
struct ServiceCardView: View {
    let service: FatumItem
    /// First photo of the service (`CatalogProvider.coverImageURLs`); a placeholder shows while it's `nil`.
    var imageURL: String? = nil
    /// Placeholder until services have real ratings.
    var rating: Double = 5

    @Environment(\.horizontalSizeClass) private var sizeClass

    private let imageSize: CGFloat = 110
    private let imageCornerRadius: CGFloat = 12
    private let tagCornerRadius: CGFloat = 12

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    /// Category, job type and estimated time, skipping the time when there is none.
    private var tags: [String] {
        [service.category, service.jobTypeDisplay, service.estimatedTimeDisplay]
            .compactMap { $0 }
    }

    var body: some View {
        HStack(alignment: .center, spacing: layout.internalSpacing) {
            coverImage

            VStack(alignment: .leading, spacing: layout.tiny) {
                Text(service.title)
                    .fatumStyle(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.text)
                    .lineLimit(2)

                Label(rating.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                    .fatumStyle(.footer)
                    .fontWeight(.bold)
                    .foregroundStyle(.text)
                    .accessibilityLabel("Calificación \(rating.formatted()) de 5")

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

                Spacer(minLength: 0)

                FlowLayout(spacing: layout.tiny) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .fatumStyle(.footer)
                            .foregroundStyle(.brandPrimary)
                            .lineLimit(1)
                            .padding(layout.smallPadding)
                            .background(Color.secondaryContainer, in: RoundedRectangle(cornerRadius: tagCornerRadius))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: imageSize, alignment: .topLeading)
        }
        // As tall as the photo (or the text, if longer), with the details line at the bottom.
        .fixedSize(horizontal: false, vertical: true)
        .padding(layout.internalPadding)
        .clipShape(RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
                .stroke(Color.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
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
                providerName: "Camilo Castaño",
                providerUsername: "camilo",
                basePrice: "28000",
                priceType: "HOURLY",
                isNegotiable: true,
                defaultEstimatedTime: 90,
                jobType: "PRESENCIAL",
                category: "Peluquería"
            )
        )

        ServiceCardView(
            service: FatumItem(
                id: "2",
                title: "Manicure",
                description: nil,
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
