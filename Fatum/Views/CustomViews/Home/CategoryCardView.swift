//
//  CategoryCardView.swift
//  Fatum
//

import SwiftUI

/// A compact card showing a filter's logo above its name, used in the
/// "Ver todas" grid. It fills the width of its grid column.
/// Every card looks the same; the selection is only shown on the Home chips.
struct CategoryCardView: View {
    let filter: CatalogProvider.ServiceFilter

    @Environment(\.horizontalSizeClass) private var sizeClass

    private let logoSize: CGFloat = 36

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        VStack(spacing: layout.spacingSmall) {
            CategoryLogoView(
                logoUrl: filter.logoUrl,
                placeholderIcon: filter.placeholderIcon,
                size: logoSize
            )

            Text(filter.title)
                .fatumStyle(.footer)
                .fontWeight(.bold)
                .foregroundStyle(.brandPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity)
        .padding(layout.tinyPadding * 2)
        .background(.primaryContainer)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// A category's remote logo, falling back to an SF Symbol while it loads or when there is none.
/// Shared by `CategoryCardView` and `CategoryChipView`.
struct CategoryLogoView: View {
    let logoUrl: String?
    let placeholderIcon: String
    let size: CGFloat
    /// Color of the fallback SF Symbol. Remote logos keep their own colors.
    var tint: Color = .brandPrimary

    var body: some View {
        if let logoUrl, let url = URL(string: logoUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Image(systemName: placeholderIcon)
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.6, height: size * 0.6)
            .frame(width: size, height: size)
            .foregroundStyle(tint)
    }
}

#Preview {
    HStack {
        CategoryCardView(filter: .all)
        CategoryCardView(
            filter: .category(FatumCategory(
                name: "Manicure y pedicure",
                slug: "manicure",
                parentSlug: "belleza",
                schedulingModel: "APPOINTMENT",
                isAble: true
            ))
        )
        CategoryCardView(
            filter: .category(FatumCategory(
                name: "Peluquería",
                slug: "peluqueria",
                parentSlug: "belleza",
                schedulingModel: "APPOINTMENT",
                isAble: true
            ))
        )
    }
    .padding(20)
    .background(.brandSecondary)
}
